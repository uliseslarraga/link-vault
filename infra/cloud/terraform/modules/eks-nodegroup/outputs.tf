output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.this.id
}

output "node_group_arn" {
  description = "ARN of the EKS node group"
  value       = aws_eks_node_group.this.arn
}

output "node_group_status" {
  description = "Current status of the node group"
  value       = aws_eks_node_group.this.status
}

output "node_group_resources" {
  description = "Auto Scaling Group names backing this node group"
  value       = aws_eks_node_group.this.resources
}
