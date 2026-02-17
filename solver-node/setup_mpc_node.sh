#!/usr/bin/env bash
set -euo pipefail

# Creates:
#   /data/data   (your code/binary lives here)
#   /data/logs   (logs live here)
# Installs:
#   /etc/systemd/system/mpc-node.service
#   /etc/logrotate.d/mpc-node
# Schedules:
#   logrotate for this config twice a day via cron (00:00 and 12:00)
#
# Assumes your runner script will be: /data/mpcn.sh
# Service will append logs to: /data/logs/mpc-node.log

SERVICE_NAME="mpc-node"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
LOGROTATE_FILE="/etc/logrotate.d/${SERVICE_NAME}"

BASE_DIR="/data"
CODE_DIR="/data/data"
LOG_DIR="/data/logs"
LOG_FILE="/data/logs/mpc-node.log"
RUNNER="/data/mpcn.sh"

CRON_FILE="/etc/cron.d/mpc-node-logrotate"
CRON_CMD="/usr/sbin/logrotate ${LOGROTATE_FILE}"

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root: sudo $0"
    exit 1
  fi
}

ensure_dirs() {
  mkdir -p "${BASE_DIR}"
  mkdir -p "${CODE_DIR}"
  mkdir -p "${LOG_DIR}"
  touch "${LOG_FILE}"
  chmod 0644 "${LOG_FILE}" || true
}

install_service() {
  cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=MPC Node (runs mpcn.sh)
After=network.target

[Service]
# Run from /data so relative paths in the script work
WorkingDirectory=/data

# Always run the shell script, not the binary directly
ExecStart=/data/mpcn.sh

# Restart on crash/exit
Restart=always
RestartSec=5

# Run as root (change if you later want a non-root user)
User=root

# Log to file
StandardOutput=append:/data/logs/mpc-node.log
StandardError=append:/data/logs/mpc-node.log

[Install]
WantedBy=multi-user.target
EOF
}

install_logrotate() {
  cat > "${LOGROTATE_FILE}" <<EOF
${LOG_FILE} {
    daily
    rotate 14
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    dateext
    dateformat -%Y-%m-%d
    create 0644 root root
}
EOF
}

maybe_create_runner_template() {
  if [[ -f "${RUNNER}" ]]; then
    echo "[OK] ${RUNNER} already exists (not overwriting)."
    chmod +x "${RUNNER}" || true
    return
  fi

  echo "[INFO] ${RUNNER} not found. Creating a template runner that cd's into /data/data."
  cat > "${RUNNER}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd /data/data

if [ -f /data/data/.env ]; then
  set -a
  source /data/data/.env
  set +a
fi

echo "ERROR: /data/mpcn.sh is a template. Edit it to start your MPC node." >&2
exit 1
EOF
  chmod +x "${RUNNER}"
}

install_cron_twice_daily() {
  # Runs at 00:00 and 12:00 every day
  cat > "${CRON_FILE}" <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

0 0,12 * * * root ${CRON_CMD} >/dev/null 2>&1
EOF
  chmod 0644 "${CRON_FILE}"
}

main() {
  need_root

  echo "[1/7] Creating /data, /data/data, /data/logs + log file..."
  ensure_dirs

  echo "[2/7] Ensuring runner exists at ${RUNNER} ..."
  maybe_create_runner_template

  echo "[3/7] Writing systemd service: ${SERVICE_FILE}"
  install_service

  echo "[4/7] Writing logrotate config: ${LOGROTATE_FILE}"
  install_logrotate

  echo "[5/7] Scheduling logrotate twice a day via cron: ${CRON_FILE}"
  install_cron_twice_daily

  echo "[6/7] Reloading systemd + enabling service..."
  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}.service" || true

  echo "[7/7] Done."
  echo ""
  echo "Installed:"
  echo "  - ${SERVICE_FILE}"
  echo "  - ${LOGROTATE_FILE}"
  echo "  - ${CRON_FILE}  (runs logrotate at 00:00 and 12:00)"
  echo ""
  echo "Next:"
  echo "  sudo nano ${RUNNER}   # put the real start command"
  echo "  sudo systemctl restart ${SERVICE_NAME}.service"
  echo ""
  echo "Verify:"
  echo "  systemctl status ${SERVICE_NAME}.service --no-pager"
  echo "  tail -n 200 ${LOG_FILE}"
  echo ""
  echo "Test rotation now:"
  echo "  sudo logrotate -f ${LOGROTATE_FILE}"
  echo "  ls -lh ${LOG_DIR}/mpc-node.log*"
}

main "$@"

