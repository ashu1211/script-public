#!/BIN/BASH
echo "for huawei-cloud"

echo "----------------------------------------------install initial package----------------------------------------------"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y logrotate
sudo DEBIAN_FRONTEND=noninteractive apt-get install jq -y
sudo DEBIAN_FRONTEND=noninteractive apt install postfix -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl unzip
sudo DEBIAN_FRONTEND=noninteractive apt-get install aria2c -y

# bash <(curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/to-run-auto-disk-update-via-bash.sh)

# bash <(curl -fsSL https://raw.githubusercontent.com/ashu1211/script-public/refs/heads/main/node-exporter/exporter.sh)

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
