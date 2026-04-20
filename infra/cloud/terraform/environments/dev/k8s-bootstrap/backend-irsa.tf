data "terraform_remote_state" "storage" {
  backend = "s3"
  config = {
    bucket = "link-vault-tf-backend"
    key    = "dev/storage/terraform.tfstate"
    region = "us-east-1"
  }
}

# ── IAM Role ──────────────────────────────────────────────────────────────────

resource "aws_iam_role" "backend" {
  name = "link-vault-dev-backend"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backend_screenshots" {
  role       = aws_iam_role.backend.name
  policy_arn = data.terraform_remote_state.storage.outputs.screenshots_policy_arn
}

# ── Pod Identity Association ───────────────────────────────────────────────────

resource "aws_eks_pod_identity_association" "backend" {
  cluster_name    = data.terraform_remote_state.compute.outputs.cluster_name
  namespace       = "backend"
  service_account = "backend"
  role_arn        = aws_iam_role.backend.arn
}
