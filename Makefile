.PHONY: aws-up aws-down local-up local-down logs clean

# --- Comandos AWS (Terraform) ---

aws-up:
	@echo "Instalando dependencias de la Lambda S3 -> PostgreSQL..."
	pip install -r terraform/modules/iot/lambda_s3_to_postgres/requirements.txt \
		-t terraform/modules/iot/lambda_s3_to_postgres/ --quiet
	@echo "Desplegando infraestructura en AWS IoT Core, DynamoDB y S3..."
	mkdir -p edge_gateway/certs
	cd terraform && terraform init && terraform apply -auto-approve
	@echo "Infraestructura desplegada. Certificados y mosquitto.conf han sido generados."

aws-down:
	@echo "Destruyendo infraestructura en AWS..."
	cd terraform && terraform destroy -auto-approve
	@echo "Infraestructura de AWS destruida."

# --- Comandos Locales (Docker Compose) ---

local-up:
	@echo "Levantando Edge Gateway (Mosquitto) y Sensores locales..."
	docker compose up -d --build
	@echo "Contenedores iniciados. Usa 'make logs' para ver el flujo de datos."

local-down:
	@echo "Deteniendo contenedores locales..."
	docker compose down
	@echo "Contenedores detenidos."

logs:
	docker compose logs -f

clean: local-down aws-down
	@echo "Limpiando certificados locales..."
	rm -rf edge_gateway/certs/*
	rm -f edge_gateway/mosquitto.conf
	@echo "Entorno limpio."

# --- Comandos API (ECS) ---

deploy-api:
	chmod +x build_and_deploy.sh
	./build_and_deploy.sh

update-api:
	@echo "Obteniendo Account ID..."
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))
	$(eval REPO_URI := $(ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com/iot-api-repo)
	@echo "Construyendo y subiendo imagen actualizada..."
	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com
	docker build -t iot-api-repo ./api
	docker tag iot-api-repo:latest $(REPO_URI):latest
	docker push $(REPO_URI):latest
	@echo "Forzando reinicio de ECS..."
	aws ecs update-service --cluster iot-api-cluster --service iot-api-service --force-new-deployment
