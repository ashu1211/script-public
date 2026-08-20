#!/bin/bash
#
# autheo-configure.sh
# Provisions an Autheo mainnet node on Ubuntu 22.04 LTS. Run as root.
#
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y logrotate
sudo DEBIAN_FRONTEND=noninteractive apt-get install jq -y
sudo DEBIAN_FRONTEND=noninteractive apt install postfix -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl unzip
sudo DEBIAN_FRONTEND=noninteractive apt-get install aria2c -y


set -euo pipefail
trap 'echo "FAILED at line $LINENO: $BASH_COMMAND" >&2' ERR

#############################################
# Variables
#############################################
#bash <(curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/to-run-auto-disk-update-via-bash.sh)
#bash <(curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/auto-mount.sh)



DATA_DISK="/data"
CHAIN_DATA_DIR="${DATA_DISK}/.autheo"

AUTHEO_USER="autheo"
AUTHEO_HOME="/home/${AUTHEO_USER}"

CHAIN_REPO_URL="https://github.com/autheo-blockchain/autheo-chain-core.git"
CHAIN_REPO_DIR="${HOME}/autheo-chain-core"

NETWORKS_REPO_URL="https://github.com/autheo-blockchain/networks.git"
NETWORKS_DIR="${HOME}/networks"
MAINNET_DIR="${NETWORKS_DIR}/mainnet"

MONIKER="autheo-node"
CHAIN_ID="autheo_785-1"

ROOT_CHAIN_SYMLINK="${HOME}/.autheo"
SERVICE_CHAIN_SYMLINK="${AUTHEO_HOME}/.autheo"
CONFIG_DIR="${ROOT_CHAIN_SYMLINK}/config"

#############################################
# 1. System packages
#############################################

echo "==> Updating apt cache"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

echo "==> Installing build prerequisites"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git make gcc curl wget jq tar ca-certificates build-essential

#############################################
# 2. Service account: autheo (nologin)
#############################################

if id -u "$AUTHEO_USER" >/dev/null 2>&1; then
    echo "==> User '${AUTHEO_USER}' already exists, skipping useradd"
else
    echo "==> Creating system user '${AUTHEO_USER}' (nologin)"
    useradd --system --create-home --home-dir "$AUTHEO_HOME" \
        --shell /usr/sbin/nologin "$AUTHEO_USER"
fi

#############################################
# 3. Go (latest upstream release)
#############################################

echo "==> Installing latest Go toolchain"

GO_LATEST=$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)

case "$(dpkg --print-architecture)" in
    amd64) GOARCH=amd64 ;;
    arm64) GOARCH=arm64 ;;
    *) echo "Unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;;
esac

GO_TARBALL="${GO_LATEST}.linux-${GOARCH}.tar.gz"
curl -fsSL -o "/tmp/${GO_TARBALL}" "https://go.dev/dl/${GO_TARBALL}"

rm -rf /usr/local/go
tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"
rm -f "/tmp/${GO_TARBALL}"

grep -qxF 'export PATH=$PATH:/usr/local/go/bin' "${HOME}/.bashrc" \
    || echo 'export PATH=$PATH:/usr/local/go/bin' >> "${HOME}/.bashrc"

# .bashrc returns early for non-interactive shells, so sourcing it here
# won't actually apply PATH; export it directly too so the build below works.
source ~/.bashrc || true
export PATH="${PATH}:/usr/local/go/bin"

go version

#############################################
# 4. Clone + build autheod, install binary
#############################################

echo "==> Cloning autheo-chain-core"
rm -rf "$CHAIN_REPO_DIR"
git clone "$CHAIN_REPO_URL" "$CHAIN_REPO_DIR"

echo "==> Building autheod"
( cd "$CHAIN_REPO_DIR" && make build )

mv "${CHAIN_REPO_DIR}/build/autheod" /usr/local/bin/autheod
chmod 0755 /usr/local/bin/autheod

source ~/.bashrc || true

autheod version

#############################################
# 5. Clone network configuration
#############################################

echo "==> Cloning networks repo"
rm -rf "$NETWORKS_DIR"
git clone "$NETWORKS_REPO_URL" "$NETWORKS_DIR"

#############################################
# 6. Data disk + home symlinks
#############################################

echo "==> Preparing ${CHAIN_DATA_DIR} on ${DATA_DISK}"
mkdir -p "$CHAIN_DATA_DIR"

# ~/.autheo -> /data/.autheo for root (init + config edits run as root below)
if [ -L "$ROOT_CHAIN_SYMLINK" ] || [ -e "$ROOT_CHAIN_SYMLINK" ]; then
    rm -rf "$ROOT_CHAIN_SYMLINK"
fi
ln -s "$CHAIN_DATA_DIR" "$ROOT_CHAIN_SYMLINK"

# autheod.service runs as User=autheo with no --home flag, so it resolves
# ~/.autheo from autheo's own $HOME. Point that at the same data dir.
if [ -L "$SERVICE_CHAIN_SYMLINK" ] || [ -e "$SERVICE_CHAIN_SYMLINK" ]; then
    rm -rf "$SERVICE_CHAIN_SYMLINK"
fi
ln -s "$CHAIN_DATA_DIR" "$SERVICE_CHAIN_SYMLINK"

#############################################
# 7. Initialize node
#############################################

echo "==> Running autheod init"
autheod init "$MONIKER" --chain-id="$CHAIN_ID"

#############################################
# 8. Apply persistent_peers / seeds
#############################################

extract_csv() {
    grep -v '^[[:space:]]*#' "$1" \
        | grep -v '^[[:space:]]*$' \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        | paste -sd, -
}

echo "==> Setting persistent_peers and seeds in config.toml"
PERSISTENT_PEERS=$(extract_csv "${MAINNET_DIR}/persistent_peers.txt")
SEEDS=$(extract_csv "${MAINNET_DIR}/seeds.txt")

sed -i "s|^persistent_peers *=.*|persistent_peers = \"${PERSISTENT_PEERS}\"|" "${CONFIG_DIR}/config.toml"
sed -i "s|^seeds *=.*|seeds = \"${SEEDS}\"|" "${CONFIG_DIR}/config.toml"

#############################################
# 9. Expose RPC / EVM JSON-RPC externally
#############################################

echo "==> Binding RPC and EVM JSON-RPC to 0.0.0.0"
sed -i 's|^laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' "${CONFIG_DIR}/config.toml"
sed -i 's|^address = "127.0.0.1:8545"|address = "0.0.0.0:8545"|' "${CONFIG_DIR}/app.toml"

#############################################
# 10. Install mainnet genesis.json
#############################################

echo "==> Installing genesis.json"
cp "${MAINNET_DIR}/genesis.json" "${CONFIG_DIR}/genesis.json"

#############################################
# 11. Fix ownership for the service account
#############################################

chown -R "${AUTHEO_USER}:${AUTHEO_USER}" "$CHAIN_DATA_DIR"

#############################################
# 12. systemd unit
#############################################

echo "==> Writing systemd unit"
cat > /etc/systemd/system/autheod.service << 'EOF'
# /etc/systemd/system/autheod.service
[Unit]
Description=Autheo Node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=autheo
Group=autheo
ExecStart=/usr/local/bin/autheod start --pruning=default --log_level info --minimum-gas-prices=0aauth --json-rpc.api=eth,net,web3
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

#############################################
# 13. Enable + start
#############################################

echo "==> Starting autheod service"
systemctl daemon-reload
systemctl enable autheod
systemctl start autheod
systemctl --no-pager status autheod

echo "==> Done. Follow logs with: journalctl -u autheod -f"
