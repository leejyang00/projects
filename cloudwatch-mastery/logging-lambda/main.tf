
# create IAM role for lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Project = "LGLM"
  }
}

data "aws_iam_policy" "lambda_basic_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# iam policy attachment
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = data.aws_iam_policy.lambda_basic_execution_policy.arn
}

# archive provider file to zip the lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/handler.zip"
}

# lambda function
resource "aws_lambda_function" "lambda_function" {
  function_name = "logging_lambda"
  role          = aws_iam_role.lambda_role.arn

  handler = "handler.lambda_handler"
  runtime = "python3.12"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  tags = {
    Project = "LGLM"
  }
}

# Optional: explicit log group so retention is managed by Terraform
resource "aws_cloudwatch_log_group" "logger" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function.function_name}"
  retention_in_days = 14
}
