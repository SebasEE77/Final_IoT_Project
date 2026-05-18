terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    # Ayuda a empaquetar el código de la Lambda en .zip automáticamente
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Módulo de Almacenamiento (S3)
module "storage" {
  source       = "./modules/storage"
  project_name = var.project_name
  environment  = var.environment
}

# Módulo de Base de Datos (DynamoDB)
module "database" {
  source       = "./modules/database"
  project_name = var.project_name
  environment  = var.environment
}

# Módulo de IoT Core
module "iot" {
  source             = "./modules/iot"
  project_name       = var.project_name
  environment        = var.environment
  
  # Variables inyectadas desde data sources globales
  lab_role_arn       = data.aws_iam_role.lab_role.arn
  account_id         = data.aws_caller_identity.current.account_id
  region             = data.aws_region.current.name
  
  # iot_endpoint: Es la URL única (Endpoint ATS) asignada por AWS a tu cuenta y región para IoT Core.
  # Es indispensable inyectarla a Mosquitto (en su archivo mosquitto.conf) para que el Bridge sepa 
  # exactamente a qué dirección de servidor de Amazon debe conectarse y enviar los mensajes MQTT.
  iot_endpoint       = data.aws_iot_endpoint.iot_endpoint.endpoint_address
  root_ca_pem        = data.http.root_ca.response_body
  
  # Variables inyectadas desde outputs de otros módulos
  sensor_bucket_name = module.storage.sensor_bucket_name
  sensor_table_name  = module.database.sensor_table_name
}

# Módulo de Red (Security Groups)
module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  environment  = var.environment
}

# Módulo de Cómputo (EC2 / ECS / ECR / ALB / API Gateway)
module "compute" {
  source          = "./modules/compute"
  project_name    = var.project_name
  environment     = var.environment
  ami_id          = var.ami_id
  key_name        = var.key_name
  subnet_id       = var.subnet_id
  subnet_ids      = module.networking.subnet_ids
  instance_type   = var.instance_type
  postgres_sg_id  = module.networking.postgres_sg_id
  alb_sg_id       = module.networking.alb_sg_id
  ecs_tasks_sg_id = module.networking.ecs_tasks_sg_id
  vpc_id          = module.networking.vpc_id
  lab_role_arn    = data.aws_iam_role.lab_role.arn
}