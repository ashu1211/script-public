#!/bin/bash

SWAP_DISK="/dev/vdb"
FSTAB_FILE="/etc/fstab"
SYSCTL_CONF="/etc/sysctl.conf"

# Check if /dev/vdb exists
if ! lsblk | grep -q "vdb"; then
    echo "Error: $SWAP_DISK not found. Please check your disk name."
    exit 1
fi

# Disable swap if already enabled
sudo swapoff -a

# Create swap space
echo "Creating swap space on $SWAP_DISK..."
sudo mkswap $SWAP_DISK

# Enable swap
echo "Enabling swap on $SWAP_DISK..."
sudo swapon $SWAP_DISK

# Verify swap activation
swapon --show

# Add to /etc/fstab for persistence
if ! grep -q "$SWAP_DISK" "$FSTAB_FILE"; then
    echo "Adding $SWAP_DISK to $FSTAB_FILE..."
    echo "$SWAP_DISK none swap sw 0 0" | sudo tee -a "$FSTAB_FILE"
else
    echo "$SWAP_DISK already exists in $FSTAB_FILE"
fi

# Optimize swappiness (reduce aggressive swapping)
echo "Setting swappiness to 10..."
sudo sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee -a "$SYSCTL_CONF"

# Reduce cache pressure
echo "Setting vfs_cache_pressure to 50..."
sudo sysctl vm.vfs_cache_pressure=50
echo 'vm.vfs_cache_pressure=50' | sudo tee -a "$SYSCTL_CONF"

# Show swap info
echo "Swap setup complete!"
swapon --show
free -h
