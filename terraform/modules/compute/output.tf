output "postgres_ip" {
  description = "IP pública del servidor PostgreSQL"
  value       = aws_instance.postgres.public_ip
}

output "api_gateway_url" {
  description = "URL de la API Gateway"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.us-east-1.amazonaws.com/prod"
}