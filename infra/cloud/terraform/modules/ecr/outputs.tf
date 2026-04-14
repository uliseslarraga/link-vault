output "repository_urls" {
  description = "Map of repository name to ECR URL"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of repository name to ECR ARN"
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}

output "registry_id" {
  description = "AWS account ID acting as the ECR registry"
  value       = values(aws_ecr_repository.this)[0].registry_id
}
