output "postgres_sg_id" {
  description = "ID del Security Group de PostgreSQL"
  value       = aws_security_group.postgres_sg.id
}