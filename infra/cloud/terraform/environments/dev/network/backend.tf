terraform {
  backend "s3" {
    bucket = "link-vault-tf-backend"
    key    = "dev/network/terraform.tfstate"
    region = "us-east-1"
  }
}
