# ── Remote state — network layer ──────────────────────────────────────────────

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "link-vault-tf-backend"
    key    = "dev/network/terraform.tfstate"
    region = "us-east-1"
  }
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────
# Created before iam_eks — OIDC outputs are needed for IRSA role trust policies.

module "eks" {
  source = "../../../modules/eks"

  env                = "dev"
  cluster_name       = var.cluster_name
  kubernetes_version = "1.35"
  cluster_role_arn   = module.iam_eks.cluster_role_arn

  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  endpoint_private_access = true
  endpoint_public_access  = true
}

# ── IAM Roles ─────────────────────────────────────────────────────────────────
# Depends on module.eks for OIDC values used to build the EBS CSI IRSA role.

module "iam_eks" {
  source = "../../../modules/iam-eks"

  env               = "dev"
  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url
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

# ── EKS Addons ────────────────────────────────────────────────────────────────
# depends_on module.system_nodes ensures at least one node is Ready before
# CoreDNS and kube-proxy are installed, preventing CrashLoopBackOff on startup.

module "addons" {
  source = "../../../modules/eks-addons"

  env              = "dev"
  cluster_name     = module.eks.cluster_name
  ebs_csi_role_arn = module.iam_eks.ebs_csi_role_arn

  # CoreDNS and EBS CSI controller are Deployments — they need this toleration
  # to schedule on the system node group (taint: dedicated=system:NoSchedule)
  system_node_taints = [{
    key      = "dedicated"
    value    = "system"
    effect   = "NoSchedule"
    operator = "Equal"
  }]

  depends_on = [module.system_nodes]
}
