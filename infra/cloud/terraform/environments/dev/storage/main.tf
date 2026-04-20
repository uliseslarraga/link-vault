# ── S3 — Link Screenshots ─────────────────────────────────────────────────────

resource "aws_s3_bucket" "screenshots" {
  bucket = "link-vault-dev"
}

resource "aws_s3_bucket_versioning" "screenshots" {
  bucket = aws_s3_bucket.screenshots.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "screenshots" {
  bucket = aws_s3_bucket.screenshots.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "screenshots" {
  bucket                  = aws_s3_bucket.screenshots.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── IAM Policy — backend IRSA ─────────────────────────────────────────────────
# Attach this policy to the backend service account role so pods can read/write screenshots.

data "aws_iam_policy_document" "screenshots" {
  statement {
    sid    = "AllowScreenshotReadWrite"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.screenshots.arn,
      "${aws_s3_bucket.screenshots.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "screenshots" {
  name   = "link-vault-dev-screenshots"
  policy = data.aws_iam_policy_document.screenshots.json
}

# ── ECR Repositories ──────────────────────────────────────────────────────────

module "ecr" {
  source = "../../../modules/ecr"

  repositories         = ["link-vault/backend", "link-vault/frontend"]
  image_tag_mutability = "IMMUTABLE"
  untagged_expiry_days = 14
}

# ── GitHub Actions OIDC + ECR Push Role ───────────────────────────────────────

module "github_oidc" {
  source = "../../../modules/github-oidc"

  github_org  = "uliseslarraga"
  github_repo = "link-vault"

  # Only the main branch can push images — PRs can build but not push
  github_branches = ["main"]

  role_name           = "link-vault-github-actions"
  ecr_repository_arns = values(module.ecr.repository_arns)
}
