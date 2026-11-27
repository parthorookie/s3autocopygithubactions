output "lambda_function_name" {
  description = "Deployed Lambda function name"
  value       = aws_lambda_function.s3_copy.function_name
}

output "source_bucket" {
  value = data.aws_s3_bucket.source.id
}

output "destination_bucket" {
  value = data.aws_s3_bucket.destination.id
}

output "lambda_arn" {
  value = aws_lambda_function.s3_copy.arn
}
