output "iot_endpoint" {
  description = "El endpoint de AWS IoT Core"
  value       = data.aws_iot_endpoint.iot_endpoint.endpoint_address
}

output "postgres_sg_id" {
  description = "ID del Security Group de PostgreSQL"
  value       = module.networking.postgres_sg_id
}

output "postgres_ip" {
  description = "IP pública del servidor PostgreSQL"
  value       = module.compute.postgres_ip
}

output "api_gateway_url" {
  description = "URL de la API Gateway"
  value       = module.compute.api_gateway_url
}