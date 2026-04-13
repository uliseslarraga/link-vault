output "addon_ids" {
  description = "Map of all addon IDs keyed by addon name"
  value = merge(
    { for k, v in aws_eks_addon.basic : k => v.id },
    { "aws-ebs-csi-driver" = aws_eks_addon.ebs_csi.id },
  )
}
