#!/bin/bash

# # Install AWS CLI
# curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
# unzip awscliv2.zip
# sudo ./aws/install
# source ~/.bashrc
# # Verify the installation
# aws --version
echo "for huawei-cloud"

echo "----------------------------------------------install initial package----------------------------------------------"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install logrotate -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install jq -y
sudo DEBIAN_FRONTEND=noninteractive apt install postfix -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install curl unzip -y

echo '----------------------------------------------Start hcloud----------------------------------------------'
mkdir /root/kooCli && cd /root/kooCli
curl -sSL https://ap-southeast-3-hwcloudcli.obs.ap-southeast-3.myhuaweicloud.com/cli/latest/hcloud_install.sh -o ./hcloud_install.sh && bash ./hcloud_install.sh -y
yes | hcloud -y
echo '----------------------------------------------Done with hcloud ----------------------------------------------'

# Download the file to $HOME
echo "FOR HUAWEI_CLOUD"
cd $HOME
curl -o $HOME/huawei-auto-disk-update.sh https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/huawei-auto-disk-update.sh
rm -rf auto-disk-update.sh
# Give execute permissions to the script
mv huawei-auto-disk-update.sh auto-disk-update.sh
chmod +x $HOME/auto-disk-update.sh
$HOME/auto-disk-update.sh

SCRIPT_PATH="$HOME/auto-disk-update.sh"

# Check if auto-disk-update.sh is in the crontab
if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
  # Check if the existing crontab entry is exactly set to run every 10 minutes
  if crontab -l 2>/dev/null | grep -q "*/10 \* \* \* \* $SCRIPT_PATH"; then
    echo "Crontab entry for $SCRIPT_PATH is already set to run every 10 minutes. No changes needed."
  else
    echo "Crontab entry for $SCRIPT_PATH exists but is not set to run every 10 minutes. Updating..."
    # Remove the incorrect entry
    crontab -l | grep -v "$SCRIPT_PATH" | crontab -
    # Add the correct entry
    (crontab -l 2>/dev/null; echo "*/10 * * * * $SCRIPT_PATH") | crontab -
    echo "Crontab entry updated successfully."
  fi
else
  echo "No crontab entry for $SCRIPT_PATH found. Adding..."
  # Add a new entry to run the script every 10 minutes
  (crontab -l 2>/dev/null; echo "*/10 * * * * $SCRIPT_PATH") | crontab -
  echo "Crontab entry added successfully."
fi

# Source ~/.bashrc to load any new environment variables or settings
source ~/.bashrc

echo "Setup completed."
