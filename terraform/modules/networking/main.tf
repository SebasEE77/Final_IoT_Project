# Archivo reservado para futuros recursos de red (VPC, Subnets, Security Groups)

# Obtenemos la VPC por defecto
data "aws_vpc" "default" {
  default = true
}

# Obtenemos las subnets de la VPC por defecto
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# =============================================
# Security Group para la EC2 de PostgreSQL.
# =============================================

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

# =============================================
# Security Group para el Load Balancer.
# =============================================

# Permite tráfico HTTP entrante desde internet.
resource "aws_security_group" "alb_sg" {
  name        = "iot-alb-sg-${var.environment}"
  description = "Permite trafico HTTP entrante al ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# =============================================
# Security Group para el ECS (Fargate).
# =============================================

# Solo permite tráfico entrante desde el ALB, no desde internet directamente.
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "iot-ecs-tasks-sg-${var.environment}"
  description = "Permite trafico entrante desde el ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    protocol        = "tcp"
    from_port       = 8000
    to_port         = 8000
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}