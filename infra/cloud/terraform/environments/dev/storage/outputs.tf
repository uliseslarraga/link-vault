output "screenshots_bucket_name" {
  description = "S3 bucket name for link screenshots"
  value       = aws_s3_bucket.screenshots.id
}

output "screenshots_bucket_arn" {
  description = "S3 bucket ARN for link screenshots — use in IRSA policies"
  value       = aws_s3_bucket.screenshots.arn
}

output "screenshots_policy_arn" {
  description = "IAM policy ARN granting read/write on the screenshots bucket — attach to the backend service account role"
  value       = aws_iam_policy.screenshots.arn
}

output "ecr_repository_urls" {
  description = "ECR URLs keyed by repository name — use these in docker push / Helm values"
  value       = module.ecr.repository_urls
}

output "github_actions_role_arn" {
  description = "IAM role ARN to set as AWS_ROLE_ARN secret in GitHub Actions"
  value       = module.github_oidc.role_arn
}
