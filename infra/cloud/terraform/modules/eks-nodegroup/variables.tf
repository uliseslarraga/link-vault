variable "env" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name this node group belongs to"
  type        = string
}

variable "node_group_name" {
  description = "Name for this managed node group"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for the worker nodes"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs where nodes are launched"
  type        = list(string)
}

variable "instance_types" {
  description = "List of EC2 instance types for the node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "disk_size_gb" {
  description = "Root EBS disk size in GB for each node"
  type        = number
  default     = 50
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
}

variable "desired_size" {
  description = "Initial desired number of nodes"
  type        = number
}

variable "max_size" {
  description = "Maximum number of nodes (used by Cluster Autoscaler)"
  type        = number
}

variable "labels" {
  description = "Kubernetes labels applied to every node in this group"
  type        = map(string)
  default     = {}
}

variable "taints" {
  description = "Kubernetes taints applied to every node in this group"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "tags" {
  description = "Additional tags merged onto all AWS resources"
  type        = map(string)
  default     = {}
}
