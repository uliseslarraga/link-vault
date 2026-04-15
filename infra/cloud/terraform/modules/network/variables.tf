variable "env" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "subnets_per_region" {
  description = "Max number of subnets spread accross azs"
  type = number
  default = 3
}

variable "map_public_ip_on_launch" {
  description = "Auto-assign a public IP to instances launched in public subnets. Keep false unless you have a deliberate reason to expose instances directly."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "Retention period (days) for VPC Flow Logs in CloudWatch"
  type        = number
  default     = 90
}

variable "eks_enabled" {
  description = "When true, adds EKS subnet discovery tags"
  type        = bool
  default     = false
}

variable "eks_cluster_name" {
  description = "EKS cluster name. Required when eks_enabled = true. Used for the kubernetes.io/cluster/<name> tag that EKS needs to discover subnets for node ENI placement."
  type        = string
  default     = ""

  validation {
    condition     = !var.eks_enabled || var.eks_cluster_name != ""
    error_message = "eks_cluster_name must be set when eks_enabled is true."
  }
}

variable "single_nat_gateway" {
  description = "When true (default), deploy a single NAT Gateway in the first public subnet. Cost-effective for dev/staging. Set to false for prod to get one NAT Gateway per AZ (requires refactoring route tables to per-AZ)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to merge onto all resources"
  type        = map(string)
  default     = {}
}
