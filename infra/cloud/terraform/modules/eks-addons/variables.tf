variable "env" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "ebs_csi_role_arn" {
  description = "IAM role ARN for the EBS CSI driver (IRSA)"
  type        = string
}

variable "system_node_taints" {
  description = "Tolerations to inject into addon Deployments that must run on tainted system nodes (coredns, ebs-csi controller). Each entry must have key, value, effect, and operator."
  type = list(object({
    key      = string
    value    = string
    effect   = string
    operator = string
  }))
  default = []
}

variable "tags" {
  description = "Additional tags to merge onto all resources"
  type        = map(string)
  default     = {}
}
