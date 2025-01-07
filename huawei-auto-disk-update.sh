#!/bin/bash
sudo apt-get install jq -y
# Get filesystem usage details
df_output=$(df -Th)

# Fetch instance metadata
PROJECTID=$(curl -s http://169.254.169.254/openstack/latest/meta_data.json | jq -r '.project_id')
echo "Project ID: $PROJECTID"

INSTANCEID=$(curl -s http://169.254.169.254/openstack/latest/meta_data.json | jq -r '.uuid')
echo "Instance ID: $INSTANCEID"

REGION=$(curl -s http://169.254.169.254/openstack/latest/meta_data.json | jq -r '.region_id')
echo "Region: $REGION"

# Get volume attachments
attachments=$(hcloud ECS ListServerVolumeAttachments --cli-region=$REGION --project_id=$PROJECTID --server_id=$INSTANCEID | jq -r '.volumeAttachments[] | "\(.device): \(.id)"')

# Loop through df output and check usage
echo "Checking volumes consuming more than 30%:"
echo "$df_output" | awk 'NR>1' | while read -r line; do
  device=$(echo "$line" | awk '{print $1}')
  fstype=$(echo "$line" | awk '{print $2}')
  size=$(echo "$line" | awk '{print $3}' | tr -d 'G')
  used=$(echo "$line" | awk '{print $4}' | tr -d 'G')
  avail=$(echo "$line" | awk '{print $5}' | tr -d 'G')
  use_percent=$(echo "$line" | awk '{print $6}' | tr -d '%')
  mount_point=$(echo "$line" | awk '{print $7}')

  # Remove trailing digit from the device name if it exists
  base_device=$(echo "$device" | sed 's/[0-9]$//')

  # Skip invalid or irrelevant entries
  if [[ -z "$use_percent" || ! "$use_percent" =~ ^[0-9]+$ ]]; then  
    echo "Invalid usage value for volume $device: $use_percent (skipping)"
    continue
  fi

  # Process only if FSUSE% > 90
  if [[ $use_percent -gt 90 ]]; then
    volume_id=$(echo "$attachments" | grep -oP "$base_device: \K[^\s]+")
    if [[ -n $volume_id ]]; then
      current_size=$size  # Size is already in GB
      new_size=$((current_size + (current_size * 15 / 100)))  # Increase by 15%

      echo "Volume: $device, Volume ID: $volume_id"
      echo "Used: $use_percent%, Current Size: $current_size GB, New Size: $new_size GB"

      # Resize the volume
      echo "Resizing volume $volume_id to $new_size GB..."
      hcloud EVS ResizeVolume --cli-region=$REGION --os-extend.new_size=$new_size --project_id=$PROJECTID --volume_id=$volume_id

      # Wait for the resize operation to complete (optional: implement a loop to poll for status)
      sleep 10  # Adjust as needed

      # Grow the partition and filesystem
      if [[ "$fstype" == "xfs" ]]; then
        echo "Growing XFS filesystem on $mount_point..."
        growpart "$base_device" 1
        xfs_growfs "$mount_point"
      elif [[ "$fstype" == "ext4" ]]; then
        echo "Growing ext4 filesystem on $device..."
        growpart "$base_device" 1
        resize2fs "$device"
      else
        echo "Unsupported filesystem type $fstype for $device. Skipping filesystem grow operation."
      fi

      echo "Volume $device resized successfully."
    else
      echo "Volume ID for $device not found in attachments."
    fi
  fi
done
