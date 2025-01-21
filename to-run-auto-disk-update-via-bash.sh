#!/bin/bash

# Echo message for Huawei Cloud
echo "for huawei-cloud"

# Install AWS CLI (commented out but left for reference)
# echo "----------------------------------------------Install AWS CLI----------------------------------------------"
# curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
# unzip awscliv2.zip
# sudo ./aws/install
# source ~/.bashrc
# aws --version

# Update and install initial packages
echo "----------------------------------------------Install Initial Packages----------------------------------------------"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y logrotate jq postfix curl unzip

# Install hcloud CLI
echo "----------------------------------------------Install hcloud CLI----------------------------------------------"
mkdir -p /root/kooCli && cd /root/kooCli
curl -sSL https://ap-southeast-3-hwcloudcli.obs.ap-southeast-3.myhuaweicloud.com/cli/latest/hcloud_install.sh -o ./hcloud_install.sh
bash ./hcloud_install.sh -y
yes | hcloud -y
echo "----------------------------------------------Done with hcloud CLI----------------------------------------------"

# Setup Huawei Cloud auto disk update script
echo "----------------------------------------------Setup Huawei Cloud Auto Disk Update Script----------------------------------------------"
cd /$USER
curl -o /$USER/huawei-auto-disk-update.sh https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/huawei-auto-disk-update.sh
rm -rf auto-disk-update.sh
mv huawei-auto-disk-update.sh auto-disk-update.sh
chmod +x /$USER/auto-disk-update.sh
./auto-disk-update.sh

# Add or update cron job for auto disk update script
SCRIPT_PATH="/$USER/auto-disk-update.sh"
if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
  echo "Found $SCRIPT_PATH in crontab. Deleting..."
  crontab -l | grep -v "$SCRIPT_PATH" | crontab -
  echo "Entry removed successfully."
else
  echo "$SCRIPT_PATH not found in crontab. Adding..."
  (crontab -l 2>/dev/null; echo "*/10 * * * * $SCRIPT_PATH") | crontab -
  echo "Entry added successfully."
fi

# Source ~/.bashrc to load environment variables
echo "----------------------------------------------Source .bashrc----------------------------------------------"
source ~/.bashrc

# Completion message
echo "Setup completed."
