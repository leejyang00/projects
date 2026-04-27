output "auto_mode_node_role_arn" {
  value = aws_iam_role.eks_auto_mode_node_role.arn
}

output "auto_mode_node_role_name" {
  value = aws_iam_role.eks_auto_mode_node_role.name
}

output "auto_mode_node_role_id" {
  value = aws_iam_role.eks_auto_mode_node_role.id
}

output "auto_mode_node_role_access_entry_id" {
  value = aws_eks_access_entry.auto_mode_node_access.id
}

output "auto_mode_node_role_access_policy_association_id" {
  value = aws_eks_access_policy_association.auto_mode_node_access_policy.id
}

output "auto_mode_node_role_access_policy_association_policy_arn" {
  value = aws_eks_access_policy_association.auto_mode_node_access_policy.policy_arn
}

# output "auto_mode_instance_profile_arn" {
#   value = aws_iam_instance_profile.eks_auto_mode_node.arn
# }