# Archivo reservado para futuros recursos de cómputo (EC2, ECS, Lambdas)

# 1. PostgreSQL EC2
resource "aws_instance" "postgres" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.postgres_sg_id]
  user_data              = file("${path.module}/install_postgres.sh")

  tags = {
    Name        = "Postgres-Server-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ==========================================
# AWS Systems Manager Parameter Store
# ==========================================

# Guarda la IP pública de la EC2 en SSM Parameter Store para que la Lambda pueda leerla
resource "aws_ssm_parameter" "postgres_ip" {
  name        = "/${var.project_name}/${var.environment}/postgres/public_ip"
  type        = "String"
  value       = aws_instance.postgres.public_ip
  description = "IP pública del servidor PostgreSQL"
}