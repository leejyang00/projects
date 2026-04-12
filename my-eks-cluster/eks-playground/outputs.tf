output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_certificate_authority" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_group_role_arn" {
  value = aws_iam_role.eks_node_group_role.arn
}

output "eks_node_group_name" {
  value = aws_eks_node_group.eks_node_group.node_group_name
}

output "eks_node_group_instance_types" {
  value = aws_eks_node_group.eks_node_group.instance_types
}

output "eks_node_group_subnet_ids" {
  value = aws_eks_node_group.eks_node_group.subnet_ids
}

output "eks_node_group_disk_size" {
  value = aws_eks_node_group.eks_node_group.disk_size
}

output "eks_node_group_labels" {
  value = aws_eks_node_group.eks_node_group.labels
}

output "eks_node_group_tags" {
  value = aws_eks_node_group.eks_node_group.tags
}

output "eks_node_group_launch_template_id" {
  value = aws_eks_node_group.eks_node_group.launch_template[0].id
}

output "eks_node_group_launch_template_version" {
  value = aws_eks_node_group.eks_node_group.launch_template[0].version
}

output "eks_node_group_launch_template_name" {
  value = aws_eks_node_group.eks_node_group.launch_template[0].name
}
