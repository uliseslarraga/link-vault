# ── Remote state — network layer ──────────────────────────────────────────────

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "link-vault-tf-backend"
    key    = "dev/network/terraform.tfstate"
    region = "us-east-1"
  }
}

# ── IAM Roles ─────────────────────────────────────────────────────────────────

module "iam_eks" {
  source = "../../../modules/iam-eks"

  env          = "dev"
  cluster_name = var.cluster_name
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────

module "eks" {
  source = "../../../modules/eks"

  env                = "dev"
  cluster_name       = var.cluster_name
  kubernetes_version = "1.35"
  cluster_role_arn   = module.iam_eks.cluster_role_arn

  # Place control plane ENIs in private subnets
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  endpoint_private_access = true
  endpoint_public_access  = true
}

# ── System Node Group ─────────────────────────────────────────────────────────
# Dedicated to cluster-level tooling: Cluster Autoscaler, ArgoCD,
# Prometheus, Grafana, etc.
# Taint: dedicated=system:NoSchedule — only pods with the matching
# toleration are scheduled here.

module "system_nodes" {
  source = "../../../modules/eks-nodegroup"

  env             = "dev"
  cluster_name    = module.eks.cluster_name
  node_group_name = "system"
  node_role_arn   = module.iam_eks.node_role_arn
  subnet_ids      = data.terraform_remote_state.network.outputs.private_subnet_ids

  instance_types = ["m7i-flex.large"]
  capacity_type  = "ON_DEMAND"
  disk_size_gb   = 30

  min_size     = 1
  desired_size = 2
  max_size     = 5

  labels = {
    role = "system"
  }

  taints = [{
    key    = "dedicated"
    value  = "system"
    effect = "NO_SCHEDULE"
  }]
}
