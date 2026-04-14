data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── GitHub OIDC Provider ──────────────────────────────────────────────────────
# One provider per AWS account — use_existing lets multiple modules/envs
# share the same provider without conflict.

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # GitHub's OIDC thumbprint — stable, published by GitHub
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.tags, { Name = "github-actions-oidc" })
}

# ── IAM Role ──────────────────────────────────────────────────────────────────
# Trust policy restricts assumption to specific repo + branches via
# the token.actions.githubusercontent.com:sub claim.

locals {
  # Build one subject condition per allowed branch
  subject_conditions = [
    for branch in var.github_branches :
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${branch}"
  ]
}

resource "aws_iam_role" "github_actions" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = local.subject_conditions
        }
      }
    }]
  })

  tags = merge(var.tags, { Name = var.role_name })
}

# ── ECR Push Policy ───────────────────────────────────────────────────────────
# Scoped to the specific repos passed in — not account-wide ECR access.

resource "aws_iam_role_policy" "ecr_push" {
  name = "${var.role_name}-ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        # GetAuthorizationToken is account-level, cannot be scoped to a repo
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = var.ecr_repository_arns
      },
    ]
  })
}
