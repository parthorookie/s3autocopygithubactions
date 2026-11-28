variable "aws_region" {
  description = "AWS Region containing both S3 buckets"
  type        = string
  default     = "ap-south-1"
}

variable "source_bucket" {
  description = "Existing source S3 bucket"
  type        = string
  default     = "partho1"
}

variable "destination_bucket" {
  description = "Existing destination S3 bucket"
  type        = string
  default     = "partho2"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "s3-auto-copy-lambda"
}
