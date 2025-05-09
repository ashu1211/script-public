#!/bin/bash

set -e

cd /data || exit 1

echo "Stopping tron.service..."
sudo systemctl stop tron.service

echo "Backing up existing FullNode.jar..."
mv FullNode.jar FullNode.jar.bak





echo "Fetching latest FullNode.jar release URL..."
LATEST_URL=$(curl -s https://api.github.com/repos/tronprotocol/java-tron/releases/latest \
  | grep 'browser_download_url' \
  | grep 'FullNode.jar"' \
  | cut -d '"' -f 4)

if [[ -z "$LATEST_URL" ]]; then
  echo "Error: Could not find FullNode.jar in the latest release." >&2
  exit 1
fi

echo "Downloading FullNode.jar from $LATEST_URL..."
curl -L -o FullNode.jar "$LATEST_URL"


echo "Starting tron.service..."
sudo systemctl start tron.service

echo "Update complete."
