output "cluster_role_arn" {
  description = "ARN of the IAM role for the EKS control plane"
  value       = aws_iam_role.cluster.arn
}

output "cluster_role_name" {
  description = "Name of the IAM role for the EKS control plane"
  value       = aws_iam_role.cluster.name
}

output "node_role_arn" {
  description = "ARN of the IAM role for worker nodes"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Name of the IAM role for worker nodes"
  value       = aws_iam_role.node.name
}

output "ebs_csi_role_arn" {
  description = "ARN of the IRSA role for the EBS CSI driver"
  value       = aws_iam_role.ebs_csi.arn
}
