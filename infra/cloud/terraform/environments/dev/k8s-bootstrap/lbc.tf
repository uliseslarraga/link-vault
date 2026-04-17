locals {
  # Strip "https://" — the OIDC condition keys use the bare issuer hostname.
  lbc_oidc_issuer = trimprefix(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://")
}

# ── IAM Policy ────────────────────────────────────────────────────────────────
# Fetches the official policy document pinned to the controller version.
# See: https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/

data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${var.lbc_version}/docs/install/iam_policy.json"

  request_headers = {
    Accept = "application/json"
  }
}

resource "aws_iam_policy" "lbc" {
  name        = "link-vault-dev-lbc"
  description = "IAM policy for the AWS Load Balancer Controller ${var.lbc_version}"
  policy      = data.http.lbc_iam_policy.response_body
}

# ── IRSA Role ─────────────────────────────────────────────────────────────────
# Trusts the EKS OIDC provider and scopes the assumption to the LBC
# service account in kube-system.

data "aws_iam_policy_document" "lbc_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.compute.outputs.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.lbc_oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.lbc_oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name               = "link-vault-dev-lbc"
  assume_role_policy = data.aws_iam_policy_document.lbc_trust.json
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# ── Service Account ───────────────────────────────────────────────────────────
# Created by Terraform so the role ARN annotation is present before the
# Helm chart starts — avoids a race condition on first install.

resource "kubernetes_service_account" "lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lbc.arn
    }

    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ── Helm Release ──────────────────────────────────────────────────────────────

resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lbc_chart_version

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      clusterName = data.terraform_remote_state.compute.outputs.cluster_name
      region      = var.region
      vpcId       = data.terraform_remote_state.network.outputs.vpc_id

      serviceAccount = {
        # SA is managed by Terraform above — do not let Helm recreate it.
        create = false
        name   = kubernetes_service_account.lbc.metadata[0].name
      }

      # Enable ALB Gateway API support via feature gate.
      controllerConfig = {
        featureGates = {
          ALBGatewayAPI = true
        }
      }

      # Run 2 replicas for availability on the system node group.
      replicaCount = 2

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
    kubernetes_service_account.lbc,
    aws_iam_role_policy_attachment.lbc,
  ]
}
