variable "env" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the RDS instance will be placed"
  type        = string
}

variable "subnet_ids" {
  description = "List of data-tier subnet IDs for the DB subnet group (must span ≥ 2 AZs)"
  type        = list(string)
}

# ── Access control ─────────────────────────────────────────────────────────────

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the DB on port 5432 (typically the private/app subnets)"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to reach the DB on port 5432 (e.g. EKS node SG)"
  type        = list(string)
  default     = []
}

# ── Engine ─────────────────────────────────────────────────────────────────────

variable "engine_version" {
  description = "PostgreSQL major version. Matches local postgres:16-alpine. Pin to a full version string for reproducibility (e.g. '16.4')."
  type        = string
  default     = "16"
}

variable "db_name" {
  description = "Name of the initial database created inside the instance"
  type        = string
  default     = "linkvault"
}

variable "db_username" {
  description = "Master username for the DB instance"
  type        = string
  default     = "linkvault"
}

# ── Compute & storage ──────────────────────────────────────────────────────────

variable "instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial storage allocation in GiB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit for storage autoscaling in GiB. Set equal to allocated_storage to disable autoscaling."
  type        = number
  default     = 100
}

# ── Availability & backups ─────────────────────────────────────────────────────

variable "multi_az" {
  description = "Deploy a standby replica in a second AZ. Recommended for staging/prod, not needed for dev."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups. Must be ≥ 1 to enable blue/green deployments."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1
    error_message = "backup_retention_days must be at least 1 — required for blue/green deployments."
  }
}

variable "backup_window" {
  description = "Preferred UTC backup window (hh24:mi-hh24:mi)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred UTC maintenance window (ddd:hh24:mi-ddd:hh24:mi)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

# ── Safety ─────────────────────────────────────────────────────────────────────

variable "deletion_protection" {
  description = "Prevent accidental deletion of the DB instance via Terraform or AWS console"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when the instance is destroyed. Set to false in non-dev environments."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to merge onto all resources"
  type        = map(string)
  default     = {}
}
