output "argocd_namespace" {
  description = "Namespace where ArgoCD is deployed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_service" {
  description = "ArgoCD server service name — use this as the backend in your HTTPRoute"
  value       = "argocd-server"
}

output "argocd_chart_version" {
  description = "Deployed ArgoCD Helm chart version"
  value       = helm_release.argocd.version
}

output "lbc_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller — attach this to the SA annotation if recreating manually"
  value       = aws_iam_role.lbc.arn
}

output "lbc_chart_version" {
  description = "Deployed AWS Load Balancer Controller Helm chart version"
  value       = helm_release.aws_lbc.version
}
