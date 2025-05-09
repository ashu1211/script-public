#!/bin/bash

set -e

cd /data || exit 1

echo "Stopping tron.service..."
sudo systemctl stop tron.service

echo "Backing up existing FullNode.jar..."
if [[ -f FullNode.jar ]]; then
  TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
  BACKUP_NAME="FullNode.jar.$TIMESTAMP"
  echo "Backing up existing FullNode.jar to $BACKUP_NAME..."
  mv FullNode.jar "$BACKUP_NAME"
fi


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

echo "now the version is "
java -jar /data/FullNode.jar --version

echo "Update complete."

