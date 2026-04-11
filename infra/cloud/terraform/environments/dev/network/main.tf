module "network" {
  source = "../../../modules/network"

  env    = "dev"
  region = var.region

  vpc_cidr    = "10.0.0.0/16"
  eks_enabled = true
}
