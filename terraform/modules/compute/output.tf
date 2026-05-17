output "postgres_ip" {
  description = "IP pública del servidor PostgreSQL"
  value       = aws_instance.postgres.public_ip
}