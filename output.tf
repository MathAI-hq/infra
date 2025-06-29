output "signup_api_url" {
  description = "Public endpoint for POST /signup"
  value       = module.signup_lambda.signup_api_url
}

