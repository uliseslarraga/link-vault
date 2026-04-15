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
