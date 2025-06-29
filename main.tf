terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # change if you need another region
}

# ───────────────────────────────────────────────
# DynamoDB table: mathai_users
#   • PK  : uid   (string)
#   • GSI : user_email_index  -> hash key user_email
# ───────────────────────────────────────────────
resource "aws_dynamodb_table" "users" {
  name         = "mathai_users"
  billing_mode = "PAY_PER_REQUEST"

  # Primary (partition) key
  hash_key = "uid"

  attribute {
    name = "uid"
    type = "S"
  }

  # Global Secondary Index to query by e-mail
  global_secondary_index {
    name            = "user_email_index"
    hash_key        = "user_email"
    projection_type = "ALL"
  }

  attribute {
    name = "user_email"
    type = "S"
  }
}

# ───────────────────────────────────────────────
# Lambda + HTTP API for POST /signup
# (module defined in infra/lambda)
# ───────────────────────────────────────────────
module "signup_lambda" {
  source = "./lambda"

  lambda_name        = "mathai_signup_handler"
  dynamodb_table     = aws_dynamodb_table.users.name
  dynamodb_table_arn = aws_dynamodb_table.users.arn
}

