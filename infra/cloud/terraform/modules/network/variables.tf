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
  description = "When true, adds the kubernetes.io/role/elb and kubernetes.io/role/internal-elb tags required by the AWS Load Balancer Controller to discover subnets"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to merge onto all resources"
  type        = map(string)
  default     = {}
}
