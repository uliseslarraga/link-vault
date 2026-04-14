output "db_instance_identifier" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance.this.identifier
}

output "db_instance_endpoint" {
  description = "Connection endpoint (host:port) for the RDS instance"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_address" {
  description = "Hostname of the RDS instance (without port)"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port the DB is listening on"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.this.db_name
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.this.username
}

output "db_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret that holds the master password. Grant this to the app's IAM role to retrieve the password at runtime."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "db_security_group_id" {
  description = "ID of the RDS security group — add this to ingress rules for app-tier SGs if needed"
  value       = aws_security_group.rds.id
}

output "db_parameter_group_name" {
  description = "Name of the custom parameter group attached to the instance"
  value       = aws_db_parameter_group.this.name
}
