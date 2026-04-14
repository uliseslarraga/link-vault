variable "env" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs where the cluster ENIs are placed"
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint (required when public is false)"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint. Set to false for fully-private clusters"
  type        = bool
  default     = false
}

variable "cluster_log_types" {
  description = "EKS control plane log types to send to CloudWatch"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "tags" {
  description = "Additional tags to merge onto all resources"
  type        = map(string)
  default     = {}
}
