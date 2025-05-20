#!/bin/bash

set -e  # Exit immediately on error

# Step 1: Create and enter the directory
mkdir -p polkadot_new_version
cd polkadot_new_version

# Step 2: Get latest Polkadot binary URL
BINARY_URL=$(curl -s https://api.github.com/repos/paritytech/polkadot-sdk/releases/latest \
	  | jq -r '.assets[].browser_download_url | select(test("/polkadot$"))')

echo "Downloading from: $BINARY_URL"

# Step 3: Download the binary
wget -q --show-progress "$BINARY_URL" -O polkadot

# Step 4: Make it executable
chmod +x polkadot

# Step 5: Stop the running Polkadot service
echo "Stopping polkadot.service..."
sudo systemctl stop polkadot.service

# Step 6: Move new binary to /usr/local/bin
echo "Updating binary..."
sudo mv polkadot /usr/local/bin/

# Step 7: Reload environment and restart service
source ~/.bashrc
echo "Starting polkadot.service..."
sudo systemctl start polkadot.service

echo "✅ Polkadot binary updated and service restarted."

