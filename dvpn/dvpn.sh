#!/bin/bash
# download-and-execute-dvpn.sh
# Usage: ./download-and-execute-dvpn.sh <username>

TARGET_USER=$1

if [ -z "$TARGET_USER" ]; then
  echo "Error: No username provided."
  exit 1
fi

echo "Installing for user: $TARGET_USER"

# Ensure dependencies are installed (running as root via sudo)
apt-get update
apt-get install -y curl git sudo

# Define Installation Directory
INSTALL_DIR="/home/$TARGET_USER/dvpn-node-script"

echo "Cloning repository to $INSTALL_DIR..."

if [ -d "$INSTALL_DIR" ]; then
  echo "Directory $INSTALL_DIR already exists. Cleaning up..."
  rm -rf "$INSTALL_DIR"
fi

# Clone the repository
git clone https://github.com/Qubetics/dvpn-node-script "$INSTALL_DIR"

# Set Ownership to the target user
echo "Setting ownership to $TARGET_USER..."
chown -R "$TARGET_USER":"$TARGET_USER" "$INSTALL_DIR"

# Make scripts executable
chmod +x "$INSTALL_DIR"/*

# Execute installation scripts AS the target user to ensure Go/config paths are correct for them
echo "Running install-go.sh as $TARGET_USER..."
sudo -u "$TARGET_USER" sh "$INSTALL_DIR/install-go.sh"

echo "Running setup_wireguard.sh as $TARGET_USER..."
sudo  sh "$INSTALL_DIR/setup_wireguard.sh"
echo "Installation instructions completed."
