// opensearch
resource "aws_opensearch_domain" "opensearch_domain" {
  domain_name    = var.service_name
  engine_version = "OpenSearch_2.7"

  cluster_config {
    instance_type = "t3.small.search"
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  tags = {
    Domain = var.service_name
  }
}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["es:*"]
    resources = ["${aws_opensearch_domain.opensearch_domain.arn}/*"]

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = ["<your ip>/32"]
    }
  }
}

resource "aws_opensearch_domain_policy" "main" {
  domain_name     = aws_opensearch_domain.opensearch_domain.domain_name
  access_policies = data.aws_iam_policy_document.main.json
}

// lambda
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "${var.service_name}-lambda"
}


data "archive_file" "movie_search" {
  type        = "zip"
  source_dir  = "${path.module}/my-opensearch-function/package"
  output_path = "${path.module}/my-opensearch-function/package/my-deployment-package.zip"
}

resource "aws_s3_object" "movie_search" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "my-deployment-package.zip"
  source = data.archive_file.movie_search.output_path

  etag = filemd5(data.archive_file.movie_search.output_path)
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

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
      }
    ]
  })
}

resource "aws_iam_policy" "os_policy_for_lambda" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["es:*"]
        Effect   = "Allow"
        Sid      = ""
        Resource = "${aws_opensearch_domain.opensearch_domain.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.os_policy_for_lambda.arn
}

resource "aws_lambda_function" "movie_search" {
  function_name = "MovieSearch"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.movie_search.key

  runtime = "python3.10"
  handler = "opensearch-lambda.lambda_handler"

  source_code_hash = data.archive_file.movie_search.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "movie_search" {
  name              = "/aws/lambda/${aws_lambda_function.movie_search.function_name}"
  retention_in_days = 7
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "movie-search-test"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 500
    throttling_rate_limit  = 1000
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_apigatewayv2_integration" "movie_search" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.movie_search.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "movie_search" {
  operation_name = "searchMovies"
  api_id         = aws_apigatewayv2_api.lambda.id

  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.movie_search.id}"

  request_parameter {
    request_parameter_key = "route.request.querystring.q"
    required              = true
  }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 7
}


resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.movie_search.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
