variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks that can reach the DB on port 5432. Defaults to the private (app) subnet range inside the 10.0.0.0/16 VPC. Tighten per-subnet if needed."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}
