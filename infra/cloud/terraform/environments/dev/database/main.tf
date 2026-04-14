# ── Remote state — network layer ───────────────────────────────────────────────
# Reads the data-tier subnet IDs and VPC ID created by the network layer.
# The data subnets are fully isolated (no NAT, no IGW route) — the correct
# placement for an RDS instance.

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "link-vault-tf-backend"
    key    = "dev/network/terraform.tfstate"
    region = "us-east-1"
  }
}

# ── RDS PostgreSQL ─────────────────────────────────────────────────────────────

module "rds" {
  source = "../../../modules/rds"

  env = "dev"

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.data_subnet_ids

  allowed_cidr_blocks = var.allowed_cidr_blocks

  # Engine — matches local postgres:16-alpine
  engine_version = "16"
  db_name        = "linkvault"
  db_username    = "linkvault"

  # Dev-sized instance — upgrade to db.r8g.large or similar for prod
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 100

  # Single-AZ is fine for dev; set to true for staging/prod
  multi_az = false

  # Must be ≥ 1 to enable blue/green deployments
  backup_retention_days = 1

  # Keep deletion protection on even in dev to avoid accidental drops
  deletion_protection = true
  skip_final_snapshot = false
}
