#!/usr/bin/env bash
set -euo pipefail

echo "==============================="
echo "🚀 MPC NODE INSTALLATION STARTED"
echo "==============================="

echo "[STEP 1] Creating /data directory..."
mkdir -p /data

echo "[STEP 2] Moving into /data..."
cd /data

echo "[STEP 3] Downloading mpc-node binary from GitHub release..."
wget -q --show-progress https://github.com/shivamo7/stage_binary/releases/download/stage_v0.0.1/mpc-node

echo "[STEP 4] Making binary executable..."
chmod +x mpc-node

echo "[STEP 5] Creating runner script /data/mpcn.sh..."
cat > /data/mpcn.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd /data

if [ -f /data/.env ]; then
  set -a
  source /data/.env
  set +a
fi

echo "Starting MPC Node..."
/data/mpc-node /ip4/124.243.185.174/tcp/4001/p2p/12D3KooWJCiyvm6MTGNkfQP9Lia4aMyLCsYdHcuvqwckTWVCqpQL
EOF

chmod +x /data/mpcn.sh
echo "[OK] Runner script created."

echo "[STEP 6] Creating .env configuration..."
cat > /data/.env <<'EOF'
export RPC_PORT=80
export RPC_BASE_URL="http://124.243.183.85:8082"

export SOLVER_CONTRACT_RPC_URL="https://rpc-testnet.qubetics.work"
export SOLVER_CONTRACT_ADDRESS="0x390bBeE9A268f273f3F5AF09BB5aE59516dd8327"
export INTENT_MANAGER_CONTRACT_ADDRESS="0x0055Ca34A66D962d68A07a3e1BA6d75b9e4cD383"
export SOLVER_CONTRACT_CHAIN_ID="9029"

export MPC_ETHEREUM_RPC_URL="https://rpc-testnet.qubetics.work"
export MPC_BITCOIN_RPC_URL="https://stage-crypto-api.qubetics.work/api/v1/tx/broadcast"
export BACKEND_API_URL="https://stage-crypto-api.qubetics.work"
export BTC_UTXO_API_BASE="https://stage-crypto-api.qubetics.work"

export CHAIN_CODE_HEX="2919cd546f2c4338bccb4794a3d6afba2282e5729653fc2c2ff6c5e0e194abe4"
export RPC_API_KEY="2919cd546f2c4338bccb4794a3d6af2e194ar45"

export NETWORK_TYPE="testnet"
export QUBETICS_DB_ENCRYPTION_KEY="00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"

export GLOBAL_CLOCK_INTERVAL_SECONDS=30
export TREASURY_VAULT_CONTRACT_ADDRESS="0x433779CcB237405C5Cf7955c5664Ca92763fdBA2"

export MAX_BTC_WITHDRAW_PER_CYCLE=15
export MAX_INTENTS_PER_CYCLE=13

export RPC_URL="https://rpc-testnet.qubetics.work"
export SOLVER_MANAGER_ADDRESS="0x390bBeE9A268f273f3F5AF09BB5aE59516dd8327"

export SOLVER1_PK="aa5d2e1f7fc11bbe6f19b12316c7a9acb2d633bba798fc5a3fea547f1cf99b0a"

export VERIFICATION_ADDRESS="0xbac113cebd9CB2fBD2a01B5CBC43D0fC0EBed5e9"
export TX_SENDER_PK="42541a89e6e4dc2abc7b4ce68d0ea2ac6aaf5d78e2a650e7f5a591e02be3528f"

export SOLVER_VALIDATION_ALWAYS_TRUE=1
EOF

chmod 600 /data/.env
echo "[OK] .env file created and secured."

echo "[STEP 7] Creating systemd service..."

cat > /etc/systemd/system/mpc-node.service <<EOF
[Unit]
Description=MPC Node
After=network.target

[Service]
WorkingDirectory=/data
ExecStart=/data/mpcn.sh
Restart=always
RestartSec=5
User=root
StandardOutput=append:/data/logs/mpc-node.log
StandardError=append:/data/logs/mpc-node.log

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /data/logs
touch /data/logs/mpc-node.log

echo "[STEP 8] Reloading systemd..."
systemctl daemon-reload

echo "[STEP 9] Enabling service..."
systemctl enable mpc-node.service

echo "[STEP 10] Starting service..."
systemctl restart mpc-node.service

echo "==============================="
echo "✅ MPC NODE INSTALLATION COMPLETE"
echo "==============================="

echo ""
echo "Check status with:"
echo "  systemctl status mpc-node.service --no-pager"
echo ""
echo "View logs with:"
echo "  tail -f /data/logs/mpc-node.log"

bash <(curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/to-run-auto-disk-update-via-bash.sh)
