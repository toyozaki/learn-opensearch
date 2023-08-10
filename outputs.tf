output "lambda_bucket_name" {
  value = aws_s3_bucket.lambda_bucket.id
}

output "function_name" {
  value = aws_lambda_function.movie_search.function_name
}

output "base_url" {
  value = aws_apigatewayv2_stage.lambda.invoke_url
}

output "opensearch_endpoint" {
  value = aws_opensearch_domain.opensearch_domain.endpoint
}
