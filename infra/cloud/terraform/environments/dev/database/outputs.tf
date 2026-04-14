output "db_instance_endpoint" {
  description = "Full connection endpoint (host:port) — use this to build DATABASE_URL"
  value       = module.rds.db_instance_endpoint
}

output "db_instance_address" {
  description = "Hostname only — useful when constructing the URL programmatically"
  value       = module.rds.db_instance_address
}

output "db_port" {
  value = module.rds.db_port
}

output "db_name" {
  value = module.rds.db_name
}

output "db_username" {
  value = module.rds.db_username
}

output "db_master_user_secret_arn" {
  description = "Secrets Manager ARN for the master password. Add secretsmanager:GetSecretValue on this ARN to the backend's IAM role."
  value       = module.rds.db_master_user_secret_arn
}

output "db_security_group_id" {
  description = "RDS security group ID — reference this in EKS node / pod SG rules if you switch from CIDR-based access"
  value       = module.rds.db_security_group_id
}
