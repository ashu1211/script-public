#!/bin/bash

set -euo pipefail

K8S_VERSION="v1.34"

echo "==========================================="
echo " Installing Kubernetes Components"
echo " Version: ${K8S_VERSION}"
echo "==========================================="

# Update packages
sudo apt-get update

# Install dependencies
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gpg

# Create keyrings directory
sudo mkdir -p /etc/apt/keyrings

# Download Kubernetes signing key
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key \
| sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

# Update package index
sudo apt-get update

# Install Kubernetes components
sudo apt-get install -y \
    kubelet \
    kubeadm \
    kubectl

# Prevent automatic upgrades
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service
sudo systemctl enable kubelet

echo
echo "==========================================="
echo " Installation Complete"
echo "==========================================="
echo
kubectl version --client
echo
kubeadm version
echo
kubelet --version
echo
echo "Installed packages:"
dpkg -l | grep -E 'kubeadm|kubectl|kubelet'
