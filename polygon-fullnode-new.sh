#!/bin/bash

# #for instanode
# password="1UlChZTNJ8e5tOQ3r@3Gvfl7JoWY"

# # Use echo to pass the password to sudo
# echo "$password" | sudo -S echo "instanodeserver ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

#sudo apt-get update -y
#sudo apt-get install aria2  -y
#sudo apt-get install jq -y
#sudo apt install nload -y
#sudo apt install sysstat -y
#sudo apt-get install xfsprogs -y
bash <(curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/to-run-auto-disk-update-via-bash.sh)

bash <(curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/node-exporter/exporter.sh)

sudo mkdir /data #create directory
disk2=$(lsblk -nx size -o kname|tail  -1 |awk {'printf "/dev/"$1'}) # To find unmount partion
sudo mkfs -t xfs $disk2 # To make a filesystem on partion 
sleep 10
sudo cp /etc/fstab /etc/fstab-old # To backup file /etc/fstab-old
VUUID=$(sudo blkid -o value -s UUID $disk2)
sleep 10
sudo su -c "echo 'UUID=$VUUID  /data   xfs   defaults        0       0' >> /etc/fstab" # To entry permament mount
sudo mount -a
sudo chown -R $USER:$USER /data # change the ownership /data dir.
echo "Disk mount complete"
# Step 1
mkdir -p /data/heimdall-snapshot
mkdir -p /data/bor-snapshot
cd /data/heimdall-snapshot

wget https://snapshots.stakepool.dev.br/heimdall/heimdall-mainnet.txt && aria2c -j 22 -x 16 -s 32 --disk-cache=1024M --file-allocation=falloc --timeout=30 --retry-wait=5 --console-log-level=warn --auto-file-renaming=false --summary-interval=3600 -c -i heimdall-mainnet.txt

# Step 2
curl -L https://raw.githubusercontent.com/maticnetwork/install/main/heimdall.sh | bash -s -- v1.2.0 mainnet sentry
sleep 10

sudo sed -i 's/User=heimdall/User=root/g' /lib/systemd/system/heimdalld.service

sudo systemctl daemon-reload
sudo systemctl start heimdalld.service
sleep 20
sudo systemctl stop heimdalld.service
sleep 10
sudo mv /var/lib/heimdall/data /var/lib/heimdall/data-bk
sudo ln -s /data/heimdall-snapshot/data /var/lib/heimdall/data
sleep 10
sudo systemctl start heimdalld.service
echo "heimdall service complete"
# Step 3
cd /data/bor-snapshot
wget https://snapshots.stakepool.dev.br/bor-mainnet.txt &&  aria2c -j 22 -x 16 -s 32 --disk-cache=1024M --file-allocation=falloc --timeout=30 --retry-wait=5 --console-log-level=warn --auto-file-renaming=false --summary-interval=3600 -c -i bor-mainnet.txt

curl -L https://raw.githubusercontent.com/maticnetwork/install/main/bor.sh | bash -s -- v2.0.0 mainnet sentry
sudo systemctl daemon-reload

sudo sed -i 's/User=bor/User=root/g' /lib/systemd/system/bor.service
sudo sed -i '/ExecStart=/ s/$/ -metrics.prometheus-addr "0.0.0.0:7071"/' /lib/systemd/system/bor.service
sudo sed -i 's/host = "127.0.0.1"/host = "0.0.0.0"/g' /var/lib/bor/config.toml
sudo systemctl daemon-reload
sudo systemctl start bor.service
sleep 10
sudo systemctl stop bor.service

while true; do
catching_up=$(curl -s localhost:26657/status | jq -r '.result.sync_info.catching_up')
if [ "$catching_up" == "false" ]; then
break
fi
sleep 10
done

sudo mv /var/lib/bor/data/bor/chaindata /var/lib/bor/data/bor/chaindata-bk
sudo ln -s /data/bor-snapshot /var/lib/bor/data/bor/chaindata

sudo systemctl start bor.service
