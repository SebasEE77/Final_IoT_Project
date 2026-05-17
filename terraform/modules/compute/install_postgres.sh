#!/bin/bash
# Amazon Linux 2023 - Instalar Docker y correr la API

# 1. Actualizar e instalar Docker y git
sudo dnf update -y
sudo dnf install -y docker git

# 2. Instalar Docker Compose
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# 3. Instalar buildx
sudo curl -SL "https://github.com/docker/buildx/releases/download/v0.17.0/buildx-v0.17.0.linux-amd64" -o /usr/local/lib/docker/cli-plugins/docker-buildx
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# 4. Habilitar y arrancar Docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# 5. Clonar el proyecto de GitHub
cd /home/ec2-user
git clone https://github.com/SebasEE77/Workers_Project.git proyecto
cd proyecto

# 6. Correr la API
sudo docker compose -f docker-compose-postgres.yml up -d --build
