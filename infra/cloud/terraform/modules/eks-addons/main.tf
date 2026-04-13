locals {
  common_tags = merge(
    {
      Environment = var.env
      ManagedBy   = "terraform"
      Project     = "link-vault"
    },
    var.tags,
  )

  # Addons that require no IAM role — just cluster + version resolved at plan time
  basic_addons = toset([
    "vpc-cni",
    "coredns",
    "kube-proxy",
    "eks-pod-identity-agent",
  ])
}

data "aws_eks_addon_version" "this" {
  for_each = toset(concat(
    tolist(local.basic_addons),
    ["aws-ebs-csi-driver"],
  ))

  addon_name         = each.key
  kubernetes_version = data.aws_eks_cluster.this.version
  most_recent        = true
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# ── Basic addons ──────────────────────────────────────────────────────────────
# vpc-cni, coredns, kube-proxy, eks-pod-identity-agent
# resolve_conflicts_on_update = OVERWRITE lets AWS manage config drift

resource "aws_eks_addon" "basic" {
  for_each = local.basic_addons

  cluster_name                = var.cluster_name
  addon_name                  = each.key
  addon_version               = data.aws_eks_addon_version.this[each.key].version
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-addon-${each.key}" })
}

# ── EBS CSI driver ────────────────────────────────────────────────────────────
# Requires an IRSA role so the driver pods can call ec2:CreateVolume etc.

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.this["aws-ebs-csi-driver"].version
  service_account_role_arn    = var.ebs_csi_role_arn
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-addon-aws-ebs-csi-driver" })
}
