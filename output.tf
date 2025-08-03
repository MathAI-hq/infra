output "signup_api_url" {
  description = "Public endpoint for POST /signup"
  value       = module.signup_lambda.signup_api_url
}

output "openai_api_url" {
  description = "Public endpoint for POST /openai"
  value       = module.openai_lambda.openai_api_url
}