# ── Storage — dev ─────────────────────────────────────────────────────────────
# Reads network outputs from remote state to place RDS/ElastiCache in data subnets.

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "link-vault-tf-backend"
    key    = "dev/network/terraform.tfstate"
    region = "us-east-1"
  }
}

# TODO: add storage resources (RDS, ElastiCache, S3, etc.)
# Available references:
#   data.terraform_remote_state.network.outputs.vpc_id
#   data.terraform_remote_state.network.outputs.data_subnet_ids
