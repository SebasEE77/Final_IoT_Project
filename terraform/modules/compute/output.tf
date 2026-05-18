output "postgres_ip" {
  description = "IP pública del servidor PostgreSQL"
  value       = aws_instance.postgres.public_ip
}

output "alb_dns_name" {
  description = "DNS del Application Load Balancer para consumir la API"
  value       = aws_lb.api_alb.dns_name
}