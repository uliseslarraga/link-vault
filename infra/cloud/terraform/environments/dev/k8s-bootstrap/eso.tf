locals {
  eso_oidc_issuer = trimprefix(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://")
}

# ── IRSA Trust Policy ─────────────────────────────────────────────────────────

data "aws_iam_policy_document" "eso_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.compute.outputs.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eso_oidc_issuer}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eso_oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── IAM Policy ────────────────────────────────────────────────────────────────
# Grants ESO read access to Secrets Manager and SSM Parameter Store.
# Write access is intentionally excluded — ESO only reads secrets.

data "aws_iam_policy_document" "eso" {
  statement {
    sid    = "AllowSecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    # Scope to secrets tagged for this project to follow least privilege.
    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:link-vault/*",
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:rds!db-685efd46-54aa-41ea-bbaa-2e625b15dca0-AMpHWT",
    ]
  }

  statement {
    sid    = "AllowSSMParameterRead"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/link-vault/*",
    ]
  }
}

# ── Role & Attachment ─────────────────────────────────────────────────────────

resource "aws_iam_role" "eso" {
  name               = "link-vault-dev-eso"
  assume_role_policy = data.aws_iam_policy_document.eso_trust.json
}

resource "aws_iam_policy" "eso" {
  name   = "link-vault-dev-eso"
  policy = data.aws_iam_policy_document.eso.json
}

resource "aws_iam_role_policy_attachment" "eso" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.eso.arn
}
