# Archivo reservado para futuros recursos de cómputo (EC2, ECS, Lambdas)

# ==========================================
# AWS EC2
# ==========================================

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

# ==========================================
# AWS ECS / ECR / ALB / API Gateway
# ==========================================

# Repositorio ECR donde está la imagen de la API.
# Se crea con el build_and_deploy.sh antes de correr terraform apply.
data "aws_ecr_repository" "api_repo" {
  name = "iot-api-repo"
}

# Cluster ECS que agrupa las tareas de la API.
resource "aws_ecs_cluster" "api_cluster" {
  name = "iot-api-cluster-${var.environment}"
}

# 2. Application Load Balancer
# Recibe el tráfico de internet y lo distribuye entre las tareas ECS de la API.
resource "aws_lb" "api_alb" {
  name               = "iot-api-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.subnet_ids
}

# 3. Target Group Load Balancer
# Define cómo el ALB verifica que las tareas estén sanas antes de enviarles tráfico.
resource "aws_lb_target_group" "api_tg" {
  name        = "iot-api-tg-${var.environment}"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
    path                = "/health"
    interval            = 30
  }
}

# 4. Listener del ALB
# Escucha en el puerto 80 y redirige el tráfico a las tareas ECS.
resource "aws_lb_listener" "api_listener" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

# 5. Task Definition
# Define el contenedor que corre la API en Fargate. 
# Inyecta el nombre de la tabla DynamoDB como variable de entorno.
resource "aws_ecs_task_definition" "api_task" {
  family                   = "iot-api-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.lab_role_arn
  task_role_arn            = var.lab_role_arn

  container_definitions = jsonencode([
    {
      name  = "iot-api-container"
      image = "${data.aws_ecr_repository.api_repo.repository_url}:latest"
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DYNAMODB_TABLE"
          value = "SensorData-${var.environment}"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/iot-api"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

# 6. ECS Service
# Mantiene corriendo el número deseado de tareas y las conecta al ALB automáticamente.
resource "aws_ecs_service" "api_service" {
  name            = "iot-api-service-${var.environment}"
  cluster         = aws_ecs_cluster.api_cluster.id
  task_definition = aws_ecs_task_definition.api_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.ecs_tasks_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_tg.arn
    container_name   = "iot-api-container"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.api_listener]
}

# 7. API Gateway
# API Gateway importado desde el Swagger generado por la API.
# Terraform inyecta el DNS del ALB en el JSON del Swagger.
resource "aws_api_gateway_rest_api" "api" {
  name = "iot-sensor-api-${var.environment}"
  body = templatefile("${path.root}/openapi_with_extensions.json", {
    alb_dns_name = aws_lb.api_alb.dns_name
  })
}

# Despliegue de la API Gateway.
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 8. Stage prod
# Entorno de producción de la API Gateway.
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"
}