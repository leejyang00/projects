output "lb_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}

output "lb_controller_policy_arn" {
  description = "ARN of the IAM policy for AWS Load Balancer Controller"
  value       = aws_iam_policy.lb_controller.arn
}

output "aws_load_balancer_controller_status" {
  description = "Status of the AWS Load Balancer Controller Helm release"
  value       = helm_release.aws_load_balancer_controller.status
}

output "aws_load_balancer_controller_version" {
  description = "Version of the AWS Load Balancer Controller Helm release"
  value       = helm_release.aws_load_balancer_controller.version
}

output "aws_load_balancer_controller_namespace" {
  description = "Namespace where AWS Load Balancer Controller is deployed"
  value       = helm_release.aws_load_balancer_controller.namespace
}

output "aws_load_balancer_controller_chart" {
  description = "Helm chart used for AWS Load Balancer Controller"
  value       = helm_release.aws_load_balancer_controller.chart
}

output "aws_load_balancer_controller_repository" {
  description = "Helm repository for AWS Load Balancer Controller"
  value       = helm_release.aws_load_balancer_controller.repository
}

output "aws_load_balancer_controller_release_name" {
  description = "Release name of the AWS Load Balancer Controller Helm release"
  value       = helm_release.aws_load_balancer_controller.name
}