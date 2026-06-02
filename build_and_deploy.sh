#!/bin/bash

REGION="us-east-1"
REPO_NAME="iot-api-repo"

echo "=== 1. Preparando entorno virtual para generar Swagger ==="
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r api/requirements.txt -q

echo "=== 2. Generando el Swagger (openapi_with_extensions.json) ==="
cd api
python generate_swagger.py
if [ $? -ne 0 ]; then
    echo "Error generando Swagger"
    exit 1
fi
mv openapi_with_extensions.json ../terraform/
cd ..

echo "=== 3. Obteniendo Account ID ==="
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Error obteniendo Account ID. ¿Está configurado AWS CLI?"
    exit 1
fi

echo "=== 4. Verificando repositorio ECR ==="
aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creando repositorio ECR: $REPO_NAME..."
    aws ecr create-repository \
        --repository-name $REPO_NAME \
        --region $REGION \
        --image-scanning-configuration scanOnPush=true \
        --image-tag-mutability MUTABLE
fi

echo "=== 5. Construyendo y subiendo imagen Docker a ECR ==="
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
REPO_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"

docker build -t $REPO_NAME ./api
docker tag $REPO_NAME:latest $REPO_URI:latest
docker push $REPO_URI:latest

echo "=== 6. Instalando dependencias Lambda S3 -> PostgreSQL ==="

pip install -r terraform/modules/iot/lambda_s3_to_postgres/requirements.txt \
    -t terraform/modules/iot/lambda_s3_to_postgres/ --quiet

echo "=== 7. Desplegando infraestructura con Terraform ==="
cd terraform
terraform init
terraform plan -out=project.tfplan
terraform apply -auto-approve
cd ..

echo "=== Proceso Completado ==="