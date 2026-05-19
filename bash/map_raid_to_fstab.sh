#!/bin/bash
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

sudo DEBIAN_FRONTEND=noninteractive apt install mdadm -y

sudo mdadm --create --verbose /dev/md0 --level=0 --raid-devices=6 /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1 /dev/nvme5n1
 cat /proc/mdstat

 sudo mkfs.xfs /dev/md0

# Extract UUID for the RAID device (md0)
raid=$(sudo blkid | grep md0 | awk -F '"' '{print $2}')

# Check if UUID was successfully found
if [ -z "$raid" ]; then
    echo "Error: Unable to find UUID for /dev/md0."
    exit 1
fi

# Define the mount point and other parameters
mount_point="/data"
filesystem="xfs"
options="defaults"
dump=0
pass=0

# Formulate the line to be added to /etc/fstab
fstab_entry="UUID=$raid    $mount_point    $filesystem    $options    $dump    $pass"

# Append the line to /etc/fstab if it doesn't already exist
if ! grep -q "$fstab_entry" /etc/fstab; then
    echo "$fstab_entry" | sudo tee -a /etc/fstab
    echo "Entry added to /etc/fstab: $fstab_entry"
else
    echo "Entry already exists in /etc/fstab."
fi

# Test if the fstab entry works
echo "Testing the fstab configuration..."
sudo umount $mount_point 2>/dev/null
sudo mount -a

# Check if the mount was successful
if mountpoint -q $mount_point; then
    echo "Mount successful: $mount_point is now mounted."
else
    echo "Error: Failed to mount $mount_point. Please check your /etc/fstab."
fi
