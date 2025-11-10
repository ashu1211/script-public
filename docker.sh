#!/bin/bash

set -e

echo "Updating package index..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

echo "Installing dependencies..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo "Adding Docker’s official GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Updating package index again..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

echo "Installing Docker Engine..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

echo "Installing Docker Compose (standalone binary)..."
DOCKER_COMPOSE_VERSION="2.24.6"  # Replace with latest if needed
sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker-compose --version)"

DOCKER_CONFIG="/etc/docker/daemon.json"

# Create directory if not exist
sudo mkdir -p /etc/docker

# Write configuration to daemon.json
sudo bash -c 'cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "/data/docker"
}
EOF'

# Restart Docker to apply changes
sudo systemctl daemon-reload
sudo systemctl restart docker

# Verify
echo "✅ Docker daemon.json updated:"
cat /etc/docker/daemon.json


echo "✅ Docker and Docker Compose installation completed."
