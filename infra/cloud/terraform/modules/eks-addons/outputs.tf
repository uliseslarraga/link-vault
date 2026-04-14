output "addon_ids" {
  description = "Map of all addon IDs keyed by addon name"
  value = merge(
    { "vpc-cni" = aws_eks_addon.vpc_cni.id },
    { for k, v in aws_eks_addon.daemonset : k => v.id },
    { "coredns" = aws_eks_addon.coredns.id },
    { "aws-ebs-csi-driver" = aws_eks_addon.ebs_csi.id },
  )
}
