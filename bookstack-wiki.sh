#!/bin/bash
# Wiki.js Auto Install Script (with PostgreSQL)
# Tested on Ubuntu 20.04/22.04

set -e

# Variables
DB_NAME="wiki"
DB_USER="wiki"
DB_PASS=$(openssl rand -base64 16)   # generate random password
WIKI_DIR="/var/www/wiki"
DETAILS_FILE="$HOME/details.txt"

echo "=== Updating system ==="
sudo apt update -y && sudo apt upgrade -y

echo "=== Installing dependencies ==="
sudo apt install -y curl wget git unzip nodejs npm postgresql postgresql-contrib

# Ensure Node.js 18+
if ! node -v | grep -q "v18"; then
  echo "=== Installing Node.js 18.x ==="
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt install -y nodejs
fi

echo "=== Setting up PostgreSQL database ==="
sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS $DB_USER;
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
ALTER DATABASE $DB_NAME OWNER TO $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

echo "=== Downloading Wiki.js ==="
sudo mkdir -p $WIKI_DIR
sudo chown $USER:$USER $WIKI_DIR
cd $WIKI_DIR
curl -sSo- https://wiki.js.org/install.sh | bash

echo "=== Creating systemd service ==="
sudo tee /etc/systemd/system/wikijs.service > /dev/null <<EOL
[Unit]
Description=Wiki.js
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$WIKI_DIR
ExecStart=/usr/bin/node server
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable wikijs
sudo systemctl start wikijs

echo "=== Saving credentials to $DETAILS_FILE ==="
cat <<EOT > $DETAILS_FILE
Wiki.js Installation Completed ✅

Database Credentials:
---------------------
DB Host:     localhost
DB Name:     $DB_NAME
DB User:     $DB_USER
DB Password: $DB_PASS

Wiki.js Path: $WIKI_DIR
Access: http://<your-server-ip>:3000
EOT

echo "=== DONE ==="
echo "Your database credentials are saved in: $DETAILS_FILE"

