# ── Compute — dev ─────────────────────────────────────────────────────────────
# Reads network outputs from remote state to reference VPC and subnet IDs.

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "link-vault-tf-backend"
    key    = "dev/network/terraform.tfstate"
    region = "us-east-1"
  }
}

# TODO: add compute resources (ECS cluster, EC2, EKS, etc.)
# Available references:
#   data.terraform_remote_state.network.outputs.vpc_id
#   data.terraform_remote_state.network.outputs.private_subnet_ids
#   data.terraform_remote_state.network.outputs.public_subnet_ids
