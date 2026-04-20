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

output "karpenter_controller_role_arn" {
  description = "IRSA role ARN for the Karpenter controller — set as serviceAccount.annotations.eks.amazonaws.com/role-arn in the Karpenter Helm chart"
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_node_role_arn" {
  description = "Node IAM role ARN for Karpenter-provisioned instances — reference this in your EC2NodeClass"
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_node_instance_profile_name" {
  description = "Instance profile name for Karpenter nodes — reference this in your EC2NodeClass"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "karpenter_interruption_queue_url" {
  description = "SQS queue URL for Karpenter interruption handling — set as settings.interruptionQueue in the Helm chart"
  value       = aws_sqs_queue.karpenter_interruption.url
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name — used as the interruptionQueue Helm value"
  value       = aws_sqs_queue.karpenter_interruption.name
}

output "eso_role_arn" {
  description = "IRSA role ARN for External Secrets Operator — annotate the ESO service account with this value"
  value       = aws_iam_role.eso.arn
}
