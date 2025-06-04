#!/bin/bash

set -e

# Step 1: Create /data directory if it doesn't exist
mkdir -p /data
cd /data

# Step 2: Download the latest FullNode.jar from TRON GitHub releases
echo "Downloading latest FullNode.jar..."
wget $(curl -s https://api.github.com/repos/tronprotocol/java-tron/releases/latest \
| grep browser_download_url \
| grep FullNode.jar \
| cut -d '"' -f 4)

# Step 3: Download nile-testnet configuration
echo "Downloading testnet config..."
wget -O testnet.conf https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/tron/nile-testnet.conf

#Snapshot dwonload

current_date=$(date -d "yesterday" +'%Y%m%d')

# Print the current date
echo "Current Date: $current_date"


wget --continue "https://nile-snapshots.s3-accelerate.amazonaws.com/backup$current_date/FullNode_output-directory.tgz"

# Unzip the downloaded file
log "Unzipping FullNode_output-directory.tgz..."
tar -xavf FullNode_output-directory.tgz -C /data

sleep 5
 rm -rf FullNode_output-directory.tgz

# Step 4: Create systemd service file
echo "Creating systemd service..."
echo "Creating systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/tron.service > /dev/null
[Unit]
Description=TRON FullNode Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/data
ExecStart=/usr/bin/java -Xmx24g -XX:+UseConcMarkSweepGC -jar /data/FullNode.jar -c /data/testnet.conf -d /data/output-directory
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Step 5: Reload systemd and start service
echo "Enabling and starting tron.service..."
sudo systemctl daemon-reload
sudo systemctl enable tron.service
sudo systemctl start tron.service

echo "✅ TRON Nile testnet node setup completed and running."
