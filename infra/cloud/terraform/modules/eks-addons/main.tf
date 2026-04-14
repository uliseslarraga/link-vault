locals {
  common_tags = merge(
    {
      Environment = var.env
      ManagedBy   = "terraform"
      Project     = "link-vault"
    },
    var.tags,
  )

  # Remaining DaemonSet addons — depend on vpc-cni being ready first
  daemonset_addons = toset([
    "kube-proxy",
    "eks-pod-identity-agent",
  ])
}

data "aws_eks_addon_version" "this" {
  for_each = toset([
    "vpc-cni",
    "coredns",
    "kube-proxy",
    "eks-pod-identity-agent",
    "aws-ebs-csi-driver",
  ])

  addon_name         = each.key
  kubernetes_version = data.aws_eks_cluster.this.version
  most_recent        = true
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# ── 1. vpc-cni — must be first ────────────────────────────────────────────────
# Provides pod networking. All other addon pods need it running to get IPs.

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = var.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = data.aws_eks_addon_version.this["vpc-cni"].version
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-addon-vpc-cni" })
}

# ── 2. DaemonSet addons — depend on vpc-cni ───────────────────────────────────
# kube-proxy, eks-pod-identity-agent: DaemonSets with broad tolerations.

resource "aws_eks_addon" "daemonset" {
  for_each = local.daemonset_addons

  cluster_name                = var.cluster_name
  addon_name                  = each.key
  addon_version               = data.aws_eks_addon_version.this[each.key].version
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-addon-${each.key}" })

  depends_on = [aws_eks_addon.vpc_cni]
}

# ── 3. CoreDNS — depends on vpc-cni ──────────────────────────────────────────
# Deployment — inject system node tolerations so pods schedule on tainted nodes.

resource "aws_eks_addon" "coredns" {
  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.this["coredns"].version
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = length(var.system_node_taints) > 0 ? jsonencode({
    tolerations = var.system_node_taints
  }) : null

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-addon-coredns" })

  depends_on = [aws_eks_addon.vpc_cni]
}

# ── 4. EBS CSI driver — depends on vpc-cni ───────────────────────────────────
# controller: Deployment — needs toleration for system node taint.
# node:       DaemonSet  — tolerates all taints by default, but explicit is better.

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.this["aws-ebs-csi-driver"].version
  service_account_role_arn    = var.ebs_csi_role_arn
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = length(var.system_node_taints) > 0 ? jsonencode({
    controller = { tolerations = var.system_node_taints }
    node       = { tolerations = var.system_node_taints }
  }) : null

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-addon-aws-ebs-csi-driver" })

  depends_on = [aws_eks_addon.vpc_cni]
}
