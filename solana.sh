#!/bin/bash

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

# Set up validator script
cat > /data/solana/validator.sh <<EOF
#!/bin/bash
agave-validator \\
 --identity /data/solana/validator-keypair.json \\
 --vote-account /data/solana/vote-account-keypair.json \\
 --known-validator 9jDvpZLfD62KKs38fdsFbZza1SgfGBW6KvbqsNRHexak \\
 --known-validator BtsmiEEvnSuUnKxqXj2PZRYpPJAc7C34mGz8gtJ1DAaH \\
 --known-validator FBKFWadXZJahGtFitAsBvbqh5968gLY7dMBBJUoUjeNi \\
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
chmod +x /data/solana/validator.sh

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
