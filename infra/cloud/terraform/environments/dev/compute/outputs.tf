output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — needed to create IRSA roles for Cluster Autoscaler, LBC, etc."
  value       = module.eks.oidc_provider_arn
}

output "node_role_arn" {
  description = "Node IAM role ARN — needed for aws-auth ConfigMap or EKS access entries"
  value       = module.iam_eks.node_role_arn
}
