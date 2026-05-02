
### 
# IAM Role and Instance Profile for EC2 instances to 
# allow them to send metrics and logs to CloudWatch
###
resource "aws_iam_instance_profile" "example_instance" {
  name = "test-instance-profile"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
    name = "test-instance-role"

    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
          Action = "sts:AssumeRole"
        }
      ] 
     })
}

data "aws_iam_policy" "cloudwatch_agent_server_policy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# iam policy attachment
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy_attachment" {
  role       = aws_iam_role.role.name
  policy_arn = data.aws_iam_policy.cloudwatch_agent_server_policy.arn
}
