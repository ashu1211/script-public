#!/bin/bash

echo  "map raid in fstab"

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

sudo DEBIAN_FRONTEND=noninteractive apt install mdadm -y

sudo mdadm --create --verbose /dev/md0 --level=0 --raid-devices=6 /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1 /dev/nvme5n1
 cat /proc/mdstat

 sudo mkfs.xfs /dev/md0
sudo mkdir -p  /data 
# Extract UUID for the RAID device (md0)
raid=$(sudo blkid | grep md0 | awk -F '"' '{print $2}')

# Check if UUID was successfully found
if [ -z "$raid" ]; then
    echo "Error: Unable to find UUID for /dev/md0."
    exit 1
fi

# Define the mount point and other parameters
mount_point="/data"
filesystem="xfs"
options="defaults"
dump=0
pass=0

# Formulate the line to be added to /etc/fstab
fstab_entry="UUID=$raid    $mount_point    $filesystem    $options    $dump    $pass"

# Append the line to /etc/fstab if it doesn't already exist
if ! grep -q "$fstab_entry" /etc/fstab; then
    echo "$fstab_entry" | sudo tee -a /etc/fstab
    echo "Entry added to /etc/fstab: $fstab_entry"
else
    echo "Entry already exists in /etc/fstab."
fi

# Test if the fstab entry works
echo "Testing the fstab configuration..."
sudo umount $mount_point 2>/dev/null
sudo mount -a

# Check if the mount was successful
if mountpoint -q $mount_point; then
    echo "Mount successful: $mount_point is now mounted."
else
    echo "Error: Failed to mount $mount_point. Please check your /etc/fstab."
fi








# Set up working directory
cd /data || exit
mkdir -p /root/.config/solana
mv /root/.config/solana /data
ln -s /data/solana /root/.config
cd ~

# Download and extract Solana release
wget https://github.com/anza-xyz/agave/releases/download/v2.0.22/solana-release-x86_64-unknown-linux-gnu.tar.bz2
tar -xavf solana-release-x86_64-unknown-linux-gnu.tar.bz2
cd solana-release/bin || exit

# Copy binaries to /usr/local/bin
cp agave-* /usr/local/bin/
cp solana* /usr/local/bin/

# Install Rust
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env
rustup update

# Configure Solana
sudo apt-get update -y
mkdir -p /data/solana
cd /data/solana || exit
solana config set --url https://api.mainnet-beta.solana.com
solana-keygen new --no-passphrase -o validator-keypair.json
solana-keygen new --no-passphrase -o vote-account-keypair.json
solana-keygen new --no-passphrase -o authorized-withdrawer-keypair.json
solana config set --keypair ./validator-keypair.json

# Configure system limits
sudo bash -c "cat > /etc/sysctl.d/21-agave-validator.conf <<EOF
# Increase UDP buffer sizes
net.core.rmem_default = 134217728
net.core.rmem_max = 134217728
net.core.wmem_default = 134217728
net.core.wmem_max = 134217728

# Increase memory mapped files limit
vm.max_map_count = 1000000

# Increase number of allowed open file descriptors
fs.nr_open = 1000000
EOF"
sudo sysctl -p /etc/sysctl.d/21-agave-validator.conf

# Set file descriptor limits
sudo bash -c "cat > /etc/security/limits.d/90-solana-nofiles.conf <<EOF
# Increase process file descriptor count limit
* - nofile 1000000
EOF"

# Reload system configuration
sudo systemctl daemon-reload
sudo systemctl restart systemd-sysctl.service


# Path to the validator.sh file
validator_file="/data/solana/validator.sh"

# Fetch new known-validator values dynamically
new_validators=$(solana validators | grep "2.0.22" | grep -v "⚠️" | awk '$4 == "100%" {print $2}')

# Start creating the new validator.sh file
cat > "$validator_file" <<EOF
#!/bin/bash
agave-validator \\
 --identity /data/solana/validator-keypair.json \\
 --vote-account /data/solana/vote-account-keypair.json \\
EOF

# Append the new known-validator lines
for validator in $new_validators; do
  echo " --known-validator $validator \\" >> "$validator_file"
done

# Append the rest of the file content
cat >> "$validator_file" <<EOF
 --ledger /data/solana/ledger \\
 --rpc-port 8899 \\
 --rpc-bind-address 0.0.0.0 \\
 --full-rpc-api \\
 --only-known-rpc \\
 --dynamic-port-range 8000-8020 \\
 --entrypoint entrypoint.mainnet-beta.solana.com:8001 \\
 --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \\
 --wal-recovery-mode skip_any_corrupted_record \\
 --log /data/agave-validator.log
EOF

# Make the script executable
chmod +x "$validator_file"

echo "Updated $validator_file with new known validators."


# Configure Solana service
sudo bash -c "cat > /etc/systemd/system/solana.service <<EOF
[Unit]
Description=Solana Validator
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
Group=root
LimitNOFILE=1000000
LogRateLimitIntervalSec=0
Environment=\"PATH=/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin\"
ExecStart=/data/solana/validator.sh

[Install]
WantedBy=multi-user.target
EOF"

# Reload systemd and enable Solana service
sudo systemctl daemon-reload
sudo systemctl enable solana.service
sudo systemctl start solana.service

# Verify Solana installation
solana --version

echo "Setup completed successfully!"
