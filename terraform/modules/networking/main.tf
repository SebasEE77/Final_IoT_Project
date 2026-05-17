# Archivo reservado para futuros recursos de red (VPC, Subnets, Security Groups)

# Security Group para la EC2 de PostgreSQL.
# Permite PostgreSQL para que la Lambda pueda conectarse y SSH para administración.
resource "aws_security_group" "postgres_sg" {
  name        = "postgres-sg-${var.environment}"
  description = "Permite acceso a PostgreSQL y SSH"

  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}