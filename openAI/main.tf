############################################
# OpenAI Lambda + /openai HTTP API Route
# 
# This module creates a serverless AI integration that:
# 1. Authenticates users via DynamoDB
# 2. Calls OpenAI API for math tutoring
# 3. Exposes a REST endpoint for AI interactions
# 4. Handles security, logging, and error management
############################################

########################
# SECTION 1: IAM ROLE & POLICY
# 
# Creates the security foundation for the Lambda function.
# The IAM role allows Lambda to assume permissions and
# the policy grants specific permissions needed for operation.
########################

# Create IAM role that Lambda can assume
# This is the "identity" that the Lambda function will use
resource "aws_iam_role" "lambda_role" {
  name               = "${var.lambda_name}_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },  # Only Lambda can assume this role
      Action = "sts:AssumeRole"                         # Permission to assume this role
    }]
  })
}

# Attach permissions to the IAM role
# This policy grants the Lambda function specific permissions it needs
resource "aws_iam_role_policy" "lambda_policy" {
  name = "AllowQueryLogsSecrets"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Permission 1: DynamoDB Access
      # Allows Lambda to query users for authentication
      {
        Effect   = "Allow",
        Action   = ["dynamodb:Query", "dynamodb:GetItem"],  # Can query and get items
        Resource = [
          var.dynamodb_table_arn,                           # Main table
          "${var.dynamodb_table_arn}/index/*"               # All indexes (GSI for email lookup)
        ]
      },
      # Permission 2: CloudWatch Logging
      # Allows Lambda to write logs for monitoring and debugging
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"  # All CloudWatch log resources
      },
      # Permission 3: Secrets Manager Access
      # Allows Lambda to retrieve OpenAI API key securely
      {
        Effect   = "Allow",
        Action   = [
          "secretsmanager:GetSecretValue"  # Can read secrets
        ],
        Resource = "arn:aws:secretsmanager:*:*:secret:openai-api-key-*"  # Only OpenAI API key secrets
      }
    ]
  })
}

########################
# SECTION 2: LAMBDA FUNCTION CREATION
# 
# Creates the actual Lambda function that will handle
# the OpenAI API integration and user authentication.
########################

# Package the Lambda code into a ZIP file
# This takes all files in the ./zip directory and creates a deployment package
data "archive_file" "zip" {
  type        = "zip"                                    # Create a ZIP archive
  source_dir  = "${path.module}/zip"                     # Source: ./zip directory
  output_path = "${path.module}/openai_lambda.zip"       # Output: openai_lambda.zip
}

# Create the Lambda function
# This is the actual serverless function that will run your code
resource "aws_lambda_function" "openai_handler" {
  function_name    = var.lambda_name                     # Name from variable
  role             = aws_iam_role.lambda_role.arn        # Use the IAM role we created
  runtime          = "python3.12"                        # Python 3.12 runtime
  handler          = "handler.handler"                    # Entry point: handler.py -> handler function

  # Deployment package configuration
  filename         = data.archive_file.zip.output_path    # Use the ZIP file we created
  source_code_hash = data.archive_file.zip.output_base64sha256  # Hash for change detection

  # Performance configuration
  timeout      = 30   # 30 seconds (longer for OpenAI API calls)
  memory_size  = 512  # 512 MB (more memory for AI processing)

  # Environment variables passed to the Lambda function
  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table  # DynamoDB table name for user lookup
    }
  }
}

########################
# SECTION 3: API GATEWAY INTEGRATION
# 
# Connects the Lambda function to the internet via
# API Gateway, creating a REST endpoint.
########################

# Create API Gateway integration
# This tells API Gateway how to call the Lambda function
resource "aws_apigatewayv2_integration" "openai_integration" {
  api_id                = var.http_api_id                # Use existing API Gateway
  integration_type      = "AWS_PROXY"                    # Direct Lambda invocation
  integration_uri       = aws_lambda_function.openai_handler.invoke_arn  # Lambda ARN
  payload_format_version = "2.0"                         # API Gateway v2 format
}

# Create the API route
# This defines the HTTP endpoint that users will call
resource "aws_apigatewayv2_route" "openai_route" {
  api_id    = var.http_api_id                           # Use existing API Gateway
  route_key = "POST /openai"                            # HTTP method and path
  target    = "integrations/${aws_apigatewayv2_integration.openai_integration.id}"  # Link to integration
}

########################
# SECTION 4: LAMBDA PERMISSIONS
# 
# Grants API Gateway permission to invoke the Lambda function.
# This is a security requirement - Lambda won't accept calls
# from unauthorized sources.
########################

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "allow_api" {
  statement_id  = "APIGatewayInvokeOpenAI"              # Unique identifier
  action        = "lambda:InvokeFunction"                # Permission to invoke
  function_name = aws_lambda_function.openai_handler.function_name  # Which function
  principal     = "apigateway.amazonaws.com"             # Who can invoke (API Gateway)
  source_arn    = "${var.http_api_execution_arn}/*/*"    # Which API Gateway (with wildcards)
}

########################
# SECTION 5: OUTPUTS
# 
# Exports values that other modules or users might need,
# such as the public URL for the API endpoint.
########################

# Export the public API URL
# This is the URL that clients will use to call the OpenAI endpoint
output "openai_api_url" {
  description = "Public endpoint for POST /openai"
  value       = "${var.base_invoke_url}/openai"         # Full URL to the endpoint
}
