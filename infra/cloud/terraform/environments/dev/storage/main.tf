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
