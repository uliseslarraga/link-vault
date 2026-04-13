output "ecr_repository_urls" {
  description = "ECR URLs keyed by repository name — use these in docker push / Helm values"
  value       = module.ecr.repository_urls
}

output "github_actions_role_arn" {
  description = "IAM role ARN to set as AWS_ROLE_ARN secret in GitHub Actions"
  value       = module.github_oidc.role_arn
}
