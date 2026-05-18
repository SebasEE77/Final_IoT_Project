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

output "alb_dns_name" {
  description = "URL de la API (DNS del Load Balancer)"
  value       = "http://${module.compute.alb_dns_name}"
}