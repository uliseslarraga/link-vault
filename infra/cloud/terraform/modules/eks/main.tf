locals {
  common_tags = merge(
    {
      Environment = var.env
      ManagedBy   = "terraform"
      Project     = "link-vault"
    },
    var.tags,
  )
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
  }

  enabled_cluster_log_types = var.cluster_log_types

  tags = merge(local.common_tags, { Name = var.cluster_name })
}

# ── OIDC Provider — required for IRSA ────────────────────────────────────────
# Allows Kubernetes service accounts to assume IAM roles directly
# (used by Cluster Autoscaler, AWS Load Balancer Controller, etc.)

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-oidc" })
}
