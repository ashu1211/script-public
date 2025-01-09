#!/bin/bash

# Update and install necessary packages
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl unzip

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
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y logrotate
sudo DEBIAN_FRONTEND=noninteractive apt-get install jq -y
sudo DEBIAN_FRONTEND=noninteractive apt install postfix -y




echo '----------------------------------------------Start hcloud----------------------------------------------'
mkdir /root/kooCli && cd /root/kooCli
curl -sSL https://ap-southeast-3-hwcloudcli.obs.ap-southeast-3.myhuaweicloud.com/cli/latest/hcloud_install.sh -o ./hcloud_install.sh && bash ./hcloud_install.sh -y
yes | hcloud -y
echo '----------------------------------------------Done with hcloud ----------------------------------------------'

# Download the file to /home/$USER

# curl -o /home/$USER/auto-disk-update.sh https://raw.githubusercontent.com/ashu1211/script/main/auto-disk-update.sh
echo "FOR HUAWEI_CLOUD"
cd /$USER
curl -o /$USER/huawei-auto-disk-update.sh https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/huawei-auto-disk-update.sh
rm -rf auto-disk-update.sh
# Give execute permissions to the script
mv huawei-auto-disk-update.sh auto-disk-update.sh
chmod +x /$USER/auto-disk-update.sh
./auto-disk-update.sh
crontab -r
# Create a cron job to run the script every day at 11 AM
(crontab -l 2>/dev/null; echo "0 11 * * * /$USER/auto-disk-update.sh") | crontab -

# Source ~/.bashrc to load any new environment variables or settings
source ~/.bashrc

echo "Setup completed."
