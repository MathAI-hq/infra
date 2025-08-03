variable "lambda_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "dynamodb_table" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}

variable "http_api_id" {
  description = "HTTP API Gateway ID"
  type        = string
}

variable "http_api_execution_arn" {
  description = "HTTP API Gateway execution ARN"
  type        = string
}

variable "base_invoke_url" {
  description = "Base invoke URL for the API Gateway"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API key for authentication"
  type        = string
  sensitive   = true
}
