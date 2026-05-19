#!/bin/bash
echo "Installed geth version:"
geth version

# Check if the Ethereum PPA is already added
if ! grep -q "^deb .*\bethereum/ubuntu\b" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    echo "Adding Ethereum PPA..."
    sudo add-apt-repository -y ppa:ethereum/ethereum
else
    echo "Ethereum PPA already exists. Skipping add-apt-repository."
fi

# Update package list
sudo apt update -y

# Install Ethereum
sudo apt-get install -y ethereum

# Print geth version
echo "Installed geth version:"
geth version
