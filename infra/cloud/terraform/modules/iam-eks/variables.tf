variable "env" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used to scope IAM role names"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster OIDC provider — required to build IRSA trust policies"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the cluster (without https://) — used in IRSA condition keys"
  type        = string
}

variable "tags" {
  description = "Additional tags to merge onto all resources"
  type        = map(string)
  default     = {}
}
