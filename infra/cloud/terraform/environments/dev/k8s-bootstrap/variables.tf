variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version. Pin this to avoid unexpected upgrades. See https://github.com/argoproj/argo-helm/releases"
  type        = string
  default     = "7.8.23"
}

variable "lbc_version" {
  description = "AWS Load Balancer Controller version (e.g. v2.8.3). Used to fetch the matching IAM policy from the official GitHub repo."
  type        = string
  default     = "v3.2.0"
}

variable "lbc_chart_version" {
  description = "AWS Load Balancer Controller Helm chart version. Must align with lbc_version. See https://github.com/aws/eks-charts/releases"
  type        = string
  default     = "3.2.0"
}
