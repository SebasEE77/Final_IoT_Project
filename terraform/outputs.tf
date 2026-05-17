output "iot_endpoint" {
  description = "El endpoint de AWS IoT Core"
  value       = data.aws_iot_endpoint.iot_endpoint.endpoint_address
}

output "postgres_sg_id" {
  description = "ID del Security Group de PostgreSQL"
  value       = module.networking.postgres_sg_id
}