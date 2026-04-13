variable "github_org" {
  description = "GitHub organisation or user name (e.g. 'my-org')"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name without the org prefix (e.g. 'link-vault')"
  type        = string
}

variable "github_branches" {
  description = "Branches allowed to assume the role. Use '*' to allow all branches."
  type        = list(string)
  default     = ["main"]
}

variable "role_name" {
  description = "Name for the IAM role GitHub Actions will assume"
  type        = string
  default     = "github-actions-ecr"
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs the role is allowed to push to"
  type        = list(string)
}

variable "tags" {
  description = "Additional tags to merge onto all resources"
  type        = map(string)
  default     = {}
}
