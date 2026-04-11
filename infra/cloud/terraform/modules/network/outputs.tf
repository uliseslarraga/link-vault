output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (app tier)"
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "IDs of the data subnets (DB tier)"
  value       = aws_subnet.data[*].id
}

output "availability_zones" {
  description = "AZs used by the subnets"
  value       = local.azs
}

output "vpc_endpoint_s3_id" {
  description = "ID of the S3 Gateway VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "vpc_endpoint_interface_ids" {
  description = "Map of Interface VPC endpoint IDs keyed by service name"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = aws_flow_log.this.id
}

output "flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}
