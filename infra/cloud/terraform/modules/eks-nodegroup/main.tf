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

resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = var.instance_types
  capacity_type  = var.capacity_type
  disk_size      = var.disk_size_gb

  scaling_config {
    min_size     = var.min_size
    desired_size = var.desired_size
    max_size     = var.max_size
  }

  # Required for Cluster Autoscaler to detect and act on this node group
  update_config {
    max_unavailable = 1
  }

  labels = var.labels

  dynamic "taint" {
    for_each = var.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Cluster Autoscaler discovers min/max via these tags
  tags = merge(
    local.common_tags,
    {
      Name                                        = "${var.cluster_name}-${var.node_group_name}"
      "k8s.io/cluster-autoscaler/enabled"         = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    },
  )

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
