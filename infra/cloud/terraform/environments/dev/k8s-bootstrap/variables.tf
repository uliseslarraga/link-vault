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
