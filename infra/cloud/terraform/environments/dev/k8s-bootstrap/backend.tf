terraform {
  backend "s3" {
    bucket = "link-vault-tf-backend"
    key    = "dev/k8s-bootstrap/terraform.tfstate"
    region = "us-east-1"
  }
}
