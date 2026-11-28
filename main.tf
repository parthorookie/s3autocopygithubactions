terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }

  # Configure a dedicated, pre-existing S3 bucket for Terraform state in GitHub Actions.
  # The workflow supplies the bucket, key, and region at terraform init time.
  
}

provider "aws" {
  region = var.aws_region
}

 # AWS provider configuration


# Existing source S3 bucket
data "aws_s3_bucket" "source" {
  bucket = var.source_bucket
}

# Existing destination S3 bucket
data "aws_s3_bucket" "destination" {
  bucket = var.destination_bucket
}

# Current AWS account information
data "aws_caller_identity" "current" {}

# Package Python Lambda code into a ZIP file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda execution IAM role
resource "aws_iam_role" "lambda_role" {
  name = "${var.lambda_function_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM permissions for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.lambda_function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "WriteLambdaLogs"
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },

      {
        Sid    = "ReadSourceObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = "${data.aws_s3_bucket.source.arn}/*"
      },

      {
        Sid    = "WriteDestinationObjects"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = "${data.aws_s3_bucket.destination.arn}/*"
      }
    ]
  })
}

# Deploy Python Lambda function
resource "aws_lambda_function" "s3_copy" {
  function_name = var.lambda_function_name

  role    = aws_iam_role.lambda_role.arn
  runtime = "python3.12"
  handler = "lambda_function.lambda_handler"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 60
  memory_size = 128

  environment {
    variables = {
      DESTINATION_BUCKET = var.destination_bucket
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy
  ]
}

# Allow the source S3 bucket to invoke Lambda
resource "aws_lambda_permission" "allow_source_bucket" {
  statement_id  = "AllowInvokeFromSourceS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_copy.function_name
  principal     = "s3.amazonaws.com"

  source_arn     = data.aws_s3_bucket.source.arn
  source_account = data.aws_caller_identity.current.account_id
}

# Trigger Lambda when an MP4 file is uploaded
resource "aws_s3_bucket_notification" "source_notification" {
  bucket = data.aws_s3_bucket.source.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_copy.arn

    events = [
      "s3:ObjectCreated:*"
    ]

    filter_suffix = ".mp4"
  }

  depends_on = [
    aws_lambda_permission.allow_source_bucket
  ]
}