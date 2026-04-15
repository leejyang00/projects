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