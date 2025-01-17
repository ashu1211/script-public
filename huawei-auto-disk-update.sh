#!/bin/bash

# Variables
METADATA_URL="http://169.254.169.254/openstack/latest/meta_data.json"
DF_CMD="df -Th"
JQ_CMD="jq -r"
HCL_CMD="hcloud"
RESIZE_PERCENT=15
SLEEP_DURATION=10
DISK_USAGE_THRESHOLD=90  # Percentage threshold for disk usage

# Fetch instance metadata
PROJECTID=$(curl -s "$METADATA_URL" | $JQ_CMD '.project_id')
INSTANCEID=$(curl -s "$METADATA_URL" | $JQ_CMD '.uuid')
REGION=$(curl -s "$METADATA_URL" | $JQ_CMD '.region_id')

# Commands
DF_OUTPUT=$($DF_CMD)
ATTACHMENTS=$($HCL_CMD ECS ListServerVolumeAttachments --cli-region=$REGION --project_id=$PROJECTID --server_id=$INSTANCEID | $JQ_CMD '.volumeAttachments[] | "\(.device): \(.id)"')

# Outputs for debugging
echo "Project ID: $PROJECTID"
echo "Instance ID: $INSTANCEID"
echo "Region: $REGION"

# Loop through df output and check usage
echo "Checking volumes consuming more than $DISK_USAGE_THRESHOLD%:"
echo "$DF_OUTPUT" | awk 'NR>1' | while read -r line; do
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

  # Process only if FSUSE% > DISK_USAGE_THRESHOLD
  if [[ $use_percent -gt $DISK_USAGE_THRESHOLD ]]; then
    volume_id=$(echo "$ATTACHMENTS" | grep -oP "$base_device: \K[^\s]+")
    if [[ -n $volume_id ]]; then
      current_size=$size  # Size is already in GB
      new_size=$((current_size + (current_size * $RESIZE_PERCENT / 100)))  # Increase by RESIZE_PERCENT%

      echo "Volume: $device, Volume ID: $volume_id"
      echo "Used: $use_percent%, Current Size: $current_size GB, New Size: $new_size GB"

      # Resize the volume
      echo "Resizing volume $volume_id to $new_size GB..."
      $HCL_CMD EVS ResizeVolume --cli-region=$REGION --os-extend.new_size=$new_size --project_id=$PROJECTID --volume_id=$volume_id

      # Wait for the resize operation to complete (optional: implement a loop to poll for status)
      sleep $SLEEP_DURATION  # Adjust as needed

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
