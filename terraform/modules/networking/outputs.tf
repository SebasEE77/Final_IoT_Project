output "postgres_sg_id" {
  description = "ID del Security Group de PostgreSQL"
  value       = aws_security_group.postgres_sg.id
}

output "alb_sg_id" {
  description = "ID del Security Group del ALB"
  value       = aws_security_group.alb_sg.id
}

output "ecs_tasks_sg_id" {
  description = "ID del Security Group de las tareas ECS"
  value       = aws_security_group.ecs_tasks_sg.id
}

output "vpc_id" {
  description = "ID de la VPC por defecto"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "IDs de las subnets de la VPC por defecto"
  value       = data.aws_subnets.default.ids
}