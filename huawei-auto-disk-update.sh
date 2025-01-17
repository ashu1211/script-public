#!/bin/bash

# Variables
METADATA_URL="http://169.254.169.254/openstack/latest/meta_data.json"
DF_CMD="df -T"  # Using df -T to avoid human-readable sizes
JQ_CMD="jq -r"
HCL_CMD="hcloud"
RESIZE_PERCENT=15
SLEEP_DURATION=10
DISK_USAGE_THRESHOLD=90  # Percentage threshold for disk usage

# Function to resize disk
resize_disk() {
  local device=$1
  local fstype=$2
  local size_kb=$3  # Size in KB (after conversion)
  local use_percent=$4
  local mount_point=$5

  # Fetch metadata and attachments only if a disk exceeds the threshold
  PROJECTID=$(curl -s "$METADATA_URL" | $JQ_CMD '.project_id')
  INSTANCEID=$(curl -s "$METADATA_URL" | $JQ_CMD '.uuid')
  REGION=$(curl -s "$METADATA_URL" | $JQ_CMD '.region_id')

  echo "Project ID: $PROJECTID"
  echo "Instance ID: $INSTANCEID"
  echo "Region: $REGION"

  ATTACHMENTS=$($HCL_CMD ECS ListServerVolumeAttachments --cli-region=$REGION --project_id=$PROJECTID --server_id=$INSTANCEID | $JQ_CMD '.volumeAttachments[] | "\(.device): \(.id)"')

  # Remove trailing digit from the device name if it exists
  base_device=$(echo "$device" | sed 's/[0-9]$//')

  volume_id=$(echo "$ATTACHMENTS" | grep -oP "$base_device: \K[^\s]+")
  if [[ -n $volume_id ]]; then
    # Convert size from KB to GB
    current_size=$((size_kb / 1024 / 1024))  # Convert KB to GB
    new_size=$((current_size + (current_size * $RESIZE_PERCENT / 100)))  # Increase by RESIZE_PERCENT%

    echo "Volume: $device, Volume ID: $volume_id"
    echo "Used: $use_percent%, Current Size: $current_size GB, New Size: $new_size GB"

    # Resize the volume
    echo "Resizing volume $volume_id to $new_size GB..."
    $HCL_CMD EVS ResizeVolume --cli-region=$REGION --os-extend.new_size=$new_size --project_id=$PROJECTID --volume_id=$volume_id

    # Wait for the resize operation to complete
    sleep $SLEEP_DURATION

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
}

# Check volumes consuming more than the threshold
echo "Checking volumes consuming more than $DISK_USAGE_THRESHOLD%:"
df_output=$($DF_CMD)
echo "$df_output" | awk 'NR>1' | while read -r line; do
  device=$(echo "$line" | awk '{print $1}')
  fstype=$(echo "$line" | awk '{print $2}')
  size_kb=$(echo "$line" | awk '{print $3}')  # Size in raw blocks (likely KB)
  used=$(echo "$line" | awk '{print $4}' | tr -d 'G')  # Ensure the used value is in raw units
  avail=$(echo "$line" | awk '{print $5}' | tr -d 'G')  # Ensure available space is in raw units
  use_percent=$(echo "$line" | awk '{print $6}' | tr -d '%')
  mount_point=$(echo "$line" | awk '{print $7}')

  # Skip invalid or irrelevant entries
  if [[ -z "$use_percent" || ! "$use_percent" =~ ^[0-9]+$ ]]; then  
    echo "Invalid usage value for volume $device: $use_percent (skipping)"
    continue
  fi

  # Process only if FSUSE% > DISK_USAGE_THRESHOLD
  if [[ $use_percent -gt $DISK_USAGE_THRESHOLD ]]; then
    echo "Disk $device is using $use_percent% (threshold: $DISK_USAGE_THRESHOLD%)"
    resize_disk "$device" "$fstype" "$size_kb" "$use_percent" "$mount_point"
  fi
done

