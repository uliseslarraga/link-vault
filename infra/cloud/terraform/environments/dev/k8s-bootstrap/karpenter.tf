data "aws_caller_identity" "current" {}

locals {
  karpenter_oidc_issuer = trimprefix(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://")
}

# ── Node IAM Role ─────────────────────────────────────────────────────────────
# Instances provisioned by Karpenter assume this role. It is separate from
# the managed nodegroup role so Karpenter nodes can be managed independently.

resource "aws_iam_role" "karpenter_node" {
  name = "link-vault-dev-karpenter-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile wraps the node role so EC2 can assume it at launch time.
resource "aws_iam_instance_profile" "karpenter_node" {
  name = "link-vault-dev-karpenter-node"
  role = aws_iam_role.karpenter_node.name
}

# ── Controller IAM Role (IRSA) ────────────────────────────────────────────────

data "aws_iam_policy_document" "karpenter_controller_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.compute.outputs.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.karpenter_oidc_issuer}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.karpenter_oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "karpenter_controller" {
  # ── EC2 — instance provisioning ─────────────────────────────────────────────
  statement {
    sid     = "AllowScopedEC2InstanceActions"
    effect  = "Allow"
    actions = ["ec2:RunInstances", "ec2:CreateFleet"]
    resources = [
      "arn:aws:ec2:${var.region}::image/*",
      "arn:aws:ec2:${var.region}::snapshot/*",
      "arn:aws:ec2:${var.region}:*:spot-instances-request/*",
      "arn:aws:ec2:${var.region}:*:security-group/*",
      "arn:aws:ec2:${var.region}:*:subnet/*",
      "arn:aws:ec2:${var.region}:*:launch-template/*",
      "arn:aws:ec2:${var.region}:*:network-interface/*",
      "arn:aws:ec2:${var.region}:*:instance/*",
      "arn:aws:ec2:${var.region}:*:volume/*",
      "arn:aws:ec2:${var.region}:*:fleet/*",
    ]
  }

  statement {
    sid     = "AllowScopedEC2InstanceTagActions"
    effect  = "Allow"
    actions = ["ec2:CreateTags"]
    resources = [
      "arn:aws:ec2:${var.region}:*:fleet/*",
      "arn:aws:ec2:${var.region}:*:instance/*",
      "arn:aws:ec2:${var.region}:*:volume/*",
      "arn:aws:ec2:${var.region}:*:network-interface/*",
      "arn:aws:ec2:${var.region}:*:launch-template/*",
      "arn:aws:ec2:${var.region}:*:spot-instances-request/*",
    ]
  }

  statement {
    sid     = "AllowScopedEC2LaunchTemplateActions"
    effect  = "Allow"
    actions = ["ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate"]
    resources = ["arn:aws:ec2:${var.region}:*:launch-template/*"]
  }

  statement {
    sid     = "AllowScopedEC2TerminateActions"
    effect  = "Allow"
    actions = ["ec2:TerminateInstances"]
    resources = ["arn:aws:ec2:${var.region}:*:instance/*"]

    # Only terminate instances that Karpenter launched.
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid    = "AllowEC2ReadActions"
    effect = "Allow"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
    ]
    resources = ["*"]
  }

  # ── IAM — pass node role to instances ───────────────────────────────────────
  statement {
    sid       = "AllowPassNodeIAMRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.karpenter_node.arn]
  }

  statement {
    sid    = "AllowScopedInstanceProfileActions"
    effect = "Allow"
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"]
  }

  # ── SSM — EKS-optimised AMI lookup ──────────────────────────────────────────
  statement {
    sid       = "AllowSSMReadActions"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${var.region}::parameter/aws/service/*"]
  }

  # ── EKS — cluster discovery ──────────────────────────────────────────────────
  statement {
    sid     = "AllowEKSReadActions"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/*",
    ]
  }

  # ── SQS — Spot interruption handling ────────────────────────────────────────
  statement {
    sid    = "AllowInterruptionQueueActions"
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.karpenter_interruption.arn]
  }

  # ── Pricing — Spot price history ─────────────────────────────────────────────
  statement {
    sid       = "AllowPricingReadActions"
    effect    = "Allow"
    actions   = ["pricing:GetProducts"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "link-vault-dev-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_trust.json
}

resource "aws_iam_policy" "karpenter_controller" {
  name   = "link-vault-dev-karpenter-controller"
  policy = data.aws_iam_policy_document.karpenter_controller.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# ── Interruption Queue ────────────────────────────────────────────────────────
# Karpenter watches this queue to cordon and drain nodes before Spot
# interruptions, rebalance events, and scheduled maintenance windows.

resource "aws_sqs_queue" "karpenter_interruption" {
  name                    = "link-vault-dev-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled = true

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Project     = "link-vault"
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEC2InterruptionEvents"
      Effect = "Allow"
      Principal = {
        Service = ["events.amazonaws.com", "sqs.amazonaws.com"]
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# ── EventBridge Rules → SQS ───────────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "link-vault-dev-karpenter-spot-interruption"
  description = "Karpenter — EC2 Spot Instance Interruption Warning"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "link-vault-dev-karpenter-rebalance"
  description = "Karpenter — EC2 Instance Rebalance Recommendation"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule = aws_cloudwatch_event_rule.karpenter_rebalance.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_state_change" {
  name        = "link-vault-dev-karpenter-state-change"
  description = "Karpenter — EC2 Instance State-change Notification"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_state_change" {
  rule = aws_cloudwatch_event_rule.karpenter_state_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_scheduled_change" {
  name        = "link-vault-dev-karpenter-scheduled-change"
  description = "Karpenter — AWS Health Event (scheduled maintenance)"
  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_scheduled_change" {
  rule = aws_cloudwatch_event_rule.karpenter_scheduled_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

# ── Namespace & Service Account ───────────────────────────────────────────────
# Created before the Helm release so the role ARN annotation is present
# from the first pod start — avoids a token exchange race on cold installs.

resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_service_account" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = kubernetes_namespace.karpenter.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller.arn
    }

    labels = {
      "app.kubernetes.io/name"       = "karpenter"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ── Helm Release ──────────────────────────────────────────────────────────────

resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = kubernetes_namespace.karpenter.metadata[0].name
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      clusterEndpoint = data.aws_eks_cluster.this.endpoint

      serviceAccount = {
        create = false
        name   = kubernetes_service_account.karpenter.metadata[0].name
      }

      settings = {
        clusterName       = data.terraform_remote_state.compute.outputs.cluster_name
        interruptionQueue = aws_sqs_queue.karpenter_interruption.name
      }

      tolerations = [{
        key      = "dedicated"
        value    = "system"
        effect   = "NoSchedule"
        operator = "Equal"
      }]

      nodeSelector = {
        role = "system"
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.karpenter,
    aws_iam_role_policy_attachment.karpenter_controller,
  ]
}
