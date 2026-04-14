locals {
  name = "link-vault-${var.env}"

  common_tags = merge(
    {
      Environment = var.env
      ManagedBy   = "terraform"
      Project     = "link-vault"
    },
    var.tags,
  )
}

# ── DB Subnet Group ────────────────────────────────────────────────────────────
# Scoped to the isolated data subnets — no route to the internet or the app tier.

resource "aws_db_subnet_group" "this" {
  name        = "${local.name}-rds"
  description = "Data-tier subnets for ${local.name} RDS"
  subnet_ids  = var.subnet_ids

  tags = merge(local.common_tags, { Name = "${local.name}-rds-subnet-group" })
}

# ── Security Group ─────────────────────────────────────────────────────────────
# Only accepts PostgreSQL traffic from explicitly allowed sources.
# Egress is locked down — RDS does not need to initiate outbound connections.

resource "aws_security_group" "rds" {
  name        = "${local.name}-sg-rds"
  description = "Allow PostgreSQL inbound from app tier only"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name}-sg-rds" })
}

resource "aws_vpc_security_group_ingress_rule" "from_cidr" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.rds.id
  description       = "PostgreSQL from ${each.value}"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "from_sg" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from security group ${each.value}"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_egress_rule" "deny_all" {
  security_group_id = aws_security_group.rds.id
  description       = "Deny all outbound (RDS initiates no outbound connections)"
  ip_protocol       = "-1"
  cidr_ipv4         = "127.0.0.1/32" # effectively blocks all real egress
}

# ── Parameter Group ────────────────────────────────────────────────────────────
# A custom parameter group is required for blue/green deployments — AWS cannot
# switch the default parameter group during a switchover.
# Family must match the major version of the engine.

resource "aws_db_parameter_group" "this" {
  name        = "${local.name}-postgres16"
  family      = "postgres16"
  description = "Custom parameter group for ${local.name} PostgreSQL 16"

  # Enable logical replication — required for blue/green switchover on PostgreSQL.
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = merge(local.common_tags, { Name = "${local.name}-pg-postgres16" })

  lifecycle {
    # Prevent in-place replacement when adding parameters — create new, then swap.
    create_before_destroy = true
  }
}

# ── RDS Instance ───────────────────────────────────────────────────────────────

resource "aws_db_instance" "this" {
  identifier = "${local.name}-postgres"

  # ── Engine ──────────────────────────────────────────────────────────────────
  engine         = "postgres"
  engine_version = var.engine_version

  # ── Credentials ─────────────────────────────────────────────────────────────
  # manage_master_user_password rotates and stores the password in Secrets Manager.
  # The plaintext password never appears in Terraform state.
  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true

  # ── Networking ──────────────────────────────────────────────────────────────
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # ── Compute & storage ───────────────────────────────────────────────────────
  instance_class        = var.instance_class
  storage_type          = "gp3"
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # enables storage autoscaling
  storage_encrypted     = true

  # ── Parameters ──────────────────────────────────────────────────────────────
  parameter_group_name = aws_db_parameter_group.this.name

  # ── Availability & upgrades ─────────────────────────────────────────────────
  multi_az                  = var.multi_az
  auto_minor_version_upgrade = true
  # allow_major_version_upgrade is required so that a blue/green deployment can
  # target a higher major version (e.g. 16 → 17) without Terraform blocking it.
  allow_major_version_upgrade = true

  # ── Blue/Green deployments ──────────────────────────────────────────────────
  # Enables AWS RDS Blue/Green Deployments for this instance.
  # The green environment is created with the new config; traffic is cut over
  # atomically once replication lag is < 1 second, minimising downtime.
  # Requires: backup_retention_period ≥ 1 and a custom parameter group.
  blue_green_update {
    enabled = true
  }

  # ── Backups ──────────────────────────────────────────────────────────────────
  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  # ── Safety ──────────────────────────────────────────────────────────────────
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name}-postgres-final"

  # ── Observability ────────────────────────────────────────────────────────────
  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # free tier: 7 days
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  tags = merge(local.common_tags, { Name = "${local.name}-postgres" })
}
