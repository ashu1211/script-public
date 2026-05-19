#!/bin/bash

# Script to install Ethereum Mainnet with Geth and Prysm on Ubuntu

# # Step 0: Run auto-mount script only if it hasn't run before
# MARKER_FILE="/var/local/auto-mount-installed"

# if [ ! -f "$MARKER_FILE" ]; then
#     echo "Running auto-mount script for the first time..."
#     curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/auto-mount.sh | bash

#     sudo mkdir -p "$(dirname "$MARKER_FILE")"
#     sudo touch "$MARKER_FILE"
# else
#     echo "Auto-mount script has already been run. Skipping."
# fi

# Step 0b: Run Huawei disk update script if not already run
DISK_UPDATE_MARKER="/var/local/huawei-disk-update-installed"
if [ ! -f "$DISK_UPDATE_MARKER" ]; then
    echo "Running Huawei auto-disk-update script for the first time..."
    curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/huawei-auto-disk-update.sh | bash
    sudo mkdir -p "$(dirname "$DISK_UPDATE_MARKER")"
    sudo touch "$DISK_UPDATE_MARKER"
else
    echo "Huawei disk update script already executed. Skipping."
fi

# Step 0b: Run Huawei node exporter script if not already run
DISK_UPDATE_MARKER="/var/local/huawei-node-exporter-installed"
if [ ! -f "$DISK_UPDATE_MARKER" ]; then
    echo "Running huawei node-exporter script for the first time..."
    curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/node-exporter/exporter.sh | bash
    sudo mkdir -p "$(dirname "$DISK_UPDATE_MARKER")"
    sudo touch "$DISK_UPDATE_MARKER"
else
    echo "Huawei disk update script already executed. Skipping."
fi



# Set working directory
WORK_DIR="/data"
mkdir -p /data/.eth2
ln -s /data/.eth2 $HOME
# Step 1: Install Geth binary
# Check if the Ethereum PPA is already added
if ! grep -q "^deb .*\bethereum/ubuntu\b" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    echo "Adding Ethereum PPA..."
    sudo add-apt-repository -y ppa:ethereum/ethereum
else
    echo "Ethereum PPA already exists. Skipping add-apt-repository."
fi
sudo apt update -y

# Install Ethereum
sudo apt-get install -y ethereum

# Print geth version
echo "Installed geth version:"
geth version

# Step 2: Download Prysm script
cd /data
curl https://raw.githubusercontent.com/OffchainLabs/prysm/master/prysm.sh --output prysm.sh && chmod +x prysm.sh

# Step 3: Generate auth file (JWT file)
echo "Generating auth file..."
$WORK_DIR/prysm.sh beacon-chain generate-auth-secret --data-dir=$WORK_DIR

# Step 4: Create systemd service files
echo "Creating systemd service files..."
mkdir -p $WORK_DIR/ethereum

# Prysm service
cat <<EOF >/etc/systemd/system/prysm.service
[Unit]
Description=Ethereum 2.0 Prysm Beacon Chain
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/prysm.sh beacon-chain --execution-endpoint=http://localhost:8551 --jwt-secret=$WORK_DIR/jwt.hex --accept-terms-of-use --checkpoint-sync-url=https://mainnet-checkpoint-sync.stakely.io --genesis-beacon-api-url=https://mainnet-checkpoint-sync.stakely.io
StandardOutput=append:$WORK_DIR/prysm.log
StandardError=append:$WORK_DIR/prysm.log
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

# Geth service
cat <<EOF >/etc/systemd/system/eth.service
[Unit]
Description=Ethereum Geth Mainnet Node
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=/usr/bin/geth --mainnet --http --http.api eth,net,engine,admin,personal,web3 --http.rpcprefix=/ --http.corsdomain= --http.addr 0.0.0.0 --ws --ipcdisable --datadir=$WORK_DIR/ethereum --ws.addr 0.0.0.0 --ws.origins= --authrpc.jwtsecret=$WORK_DIR/jwt.hex --authrpc.port 8551 --authrpc.vhosts="" --http.vhosts=""
StandardOutput=append:$WORK_DIR/geth.log
StandardError=append:$WORK_DIR/geth.log
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

# Step 5: Reload systemd and create Ethereum data directory
echo "Reloading systemd and creating Ethereum data directory..."
systemctl daemon-reload

# Step 6: Start services
echo "Starting Prysm and Geth services..."
systemctl start prysm.service
systemctl start eth.service

# Enable services to start on boot
systemctl enable prysm.service
systemctl enable eth.service

echo "Ethereum mainnet setup completed successfully!"
root@ecs-f0ff-dbdf:~# ls^C
root@ecs-f0ff-dbdf:~# cat eth.sh 
#!/bin/bash

# Script to install Ethereum Mainnet with Geth and Prysm on Ubuntu

# Step 0: Run auto-mount script only if it hasn't run before
MARKER_FILE="/var/local/auto-mount-installed"

if [ ! -f "$MARKER_FILE" ]; then
    echo "Running auto-mount script for the first time..."
    curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/auto-mount.sh | bash

    sudo mkdir -p "$(dirname "$MARKER_FILE")"
    sudo touch "$MARKER_FILE"
else
    echo "Auto-mount script has already been run. Skipping."
fi

# Step 0b: Run Huawei disk update script if not already run
DISK_UPDATE_MARKER="/var/local/huawei-disk-update-installed"
if [ ! -f "$DISK_UPDATE_MARKER" ]; then
    echo "Running Huawei auto-disk-update script for the first time..."
    curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/huawei-auto-disk-update.sh | bash
    sudo mkdir -p "$(dirname "$DISK_UPDATE_MARKER")"
    sudo touch "$DISK_UPDATE_MARKER"
else
    echo "Huawei disk update script already executed. Skipping."
fi

# Step 0b: Run Huawei node exporter script if not already run
DISK_UPDATE_MARKER="/var/local/huawei-node-exporter-installed"
if [ ! -f "$DISK_UPDATE_MARKER" ]; then
    echo "Running huawei node-exporter script for the first time..."
    curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/node-exporter/exporter.sh | bash
    sudo mkdir -p "$(dirname "$DISK_UPDATE_MARKER")"
    sudo touch "$DISK_UPDATE_MARKER"
else
    echo "Huawei disk update script already executed. Skipping."
fi



# Set working directory
WORK_DIR="/data"
mkdir -p /data/.eth2
ln -s /data/.eth2 $HOME
# Step 1: Install Geth binary
# Check if the Ethereum PPA is already added
if ! grep -q "^deb .*\bethereum/ubuntu\b" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    echo "Adding Ethereum PPA..."
    sudo add-apt-repository -y ppa:ethereum/ethereum
else
    echo "Ethereum PPA already exists. Skipping add-apt-repository."
fi
sudo apt update -y

# Install Ethereum
sudo apt-get install -y ethereum

# Print geth version
echo "Installed geth version:"
geth version

# Step 2: Download Prysm script
cd /data
curl https://raw.githubusercontent.com/OffchainLabs/prysm/master/prysm.sh --output prysm.sh && chmod +x prysm.sh

# Step 3: Generate auth file (JWT file)
echo "Generating auth file..."
$WORK_DIR/prysm.sh beacon-chain generate-auth-secret --data-dir=$WORK_DIR

# Step 4: Create systemd service files
echo "Creating systemd service files..."
mkdir -p $WORK_DIR/ethereum

# Prysm service
cat <<EOF >/etc/systemd/system/prysm.service
[Unit]
Description=Ethereum 2.0 Prysm Beacon Chain
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/prysm.sh beacon-chain --execution-endpoint=http://localhost:8551 --jwt-secret=$WORK_DIR/jwt.hex --accept-terms-of-use --checkpoint-sync-url=https://mainnet-checkpoint-sync.stakely.io --genesis-beacon-api-url=https://mainnet-checkpoint-sync.stakely.io
StandardOutput=append:$WORK_DIR/prysm.log
StandardError=append:$WORK_DIR/prysm.log
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

# Geth service
cat <<EOF >/etc/systemd/system/eth.service
[Unit]
Description=Ethereum Geth Mainnet Node
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=/usr/bin/geth --mainnet --http --http.api eth,net,engine,admin,personal,web3 --http.rpcprefix=/ --http.corsdomain= --http.addr 0.0.0.0 --ws --ipcdisable --datadir=$WORK_DIR/ethereum --ws.addr 0.0.0.0 --ws.origins= --authrpc.jwtsecret=$WORK_DIR/jwt.hex --authrpc.port 8551 --authrpc.vhosts="" --http.vhosts=""
StandardOutput=append:$WORK_DIR/geth.log
StandardError=append:$WORK_DIR/geth.log
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

# Step 5: Reload systemd and create Ethereum data directory
echo "Reloading systemd and creating Ethereum data directory..."
systemctl daemon-reload

# Step 6: Start services
echo "Starting Prysm and Geth services..."
systemctl start prysm.service
systemctl start eth.service

# Enable services to start on boot
systemctl enable prysm.service
systemctl enable eth.service

echo "Ethereum mainnet setup completed successfully!"
