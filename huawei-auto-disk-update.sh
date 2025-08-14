#!/bin/bash
sudo DEBIAN_FRONTEND=noninteractive apt install postfix -y
sleep 10
# Variables
METADATA_URL="http://169.254.169.254/openstack/latest/meta_data.json"
DF_CMD="df -T"  # Using df -T to avoid human-readable sizes
JQ_CMD="jq -r"
HCL_CMD="hcloud"
RESIZE_PERCENT=5
SLEEP_DURATION=10
DISK_USAGE_THRESHOLD=95  # Percentage threshold for disk usage

# Function to get ID_SERIAL for a given device
get_id_serial() {
  local device=$1
  local base_device="${device##*/}"

  # Find the ID_SERIAL by following symbolic links in /dev/disk/by-id/
  local id_serial=$(find /dev/disk/by-id/ -type l -lname "*$base_device" -exec readlink -f {} \; | xargs -I{} basename $(dirname {})/$(basename {}))

  id_serial=$(echo "$id_serial" | head -n 1)

  if [[ -z "$id_serial" || "$id_serial" == "$base_device" ]]; then
    id_serial=$(find /dev/disk/by-id/ -type l -lname "*$base_device" -exec basename {} \; | grep -v "$base_device" | head -n 1)
  fi

  # Handle specific patterns if necessary
  if [[ "$id_serial" =~ ^virtio-(.{20})-part[0-9]+$ ]]; then
    id_serial="${BASH_REMATCH[1]}"
  elif [[ "$id_serial" =~ ^virtio-(.{20}) ]]; then
    id_serial="${BASH_REMATCH[1]}"
  else
    id_serial=""
  fi

  echo "Extracted ID_SERIAL for $device is: $id_serial"
  echo "$id_serial"
}

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

  # Print ATTACHMENTS for debugging
  echo "Attachments:"
  echo "$ATTACHMENTS"

  # Remove trailing digit from the device name if it exists
  base_device=$(echo "$device" | sed 's/[0-9]$//')

  # Get ID_SERIAL for the device
  id_serial=$(get_id_serial "$device")
  echo "ID_SERIAL for $device is: $id_serial"

  # Match volume_id using ID_SERIAL prefix or base_device
  potential_volume_ids=$(echo "$ATTACHMENTS" | grep "${id_serial}" | cut -d' ' -f2)
  volume_id=$(echo "$potential_volume_ids" | head -n 1)  # Take the first match if multiple matches are found

  echo "Potential volume IDs based on ID_SERIAL: $potential_volume_ids"
  echo "Selected volume_id: $volume_id"

  # Check if volume_id is empty and terminate the script if it is
  if [[ -z "$volume_id" ]]; then
    echo "No match found with ID_SERIAL. Attempting alternative matching."
    exit 1  # terminate script execution
  fi

  # Convert size from KB to GB
  current_size=$((size_kb / 1024 / 1024))  # Convert KB to GB
  new_size=$((current_size + (current_size * $RESIZE_PERCENT / 100)))  # Increase by RESIZE_PERCENT%

  echo "Current Size (KB): $size_kb"
  echo "Current Size (GB): $current_size"
  echo "New Size (GB): $new_size"

  # Query current volume details
  volume_details=$($HCL_CMD EVS ShowVolume --cli-region=$REGION --project_id=$PROJECTID --volume_id=$volume_id)
  current_volume_size_gb=$(echo "$volume_details" | $JQ_CMD '.volume.size')

  echo "Current Volume Size (from API): $current_volume_size_gb GB"

  # Double check if new size is still greater than current size
  if (( new_size <= current_volume_size_gb )); then
    echo "New size ($new_size GB) must be greater than current volume size ($current_volume_size_gb GB). Skipping resize."
    return
  fi

  # Resize the volume
  echo "Resizing volume $volume_id to $new_size GB..."
  response=$($HCL_CMD EVS ResizeVolume --cli-region=$REGION --os-extend.new_size=$new_size --project_id=$PROJECTID --volume_id=$volume_id)
  # Check if the resize operation was successful
  if [[ "$response" =~ "error" ]]; then
    echo "Error resizing volume: $response"
    return
  fi

  # Wait for the resize operation to complete
  sleep $SLEEP_DURATION

  # Sync filesystem size with partition size
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
  if (( use_percent > DISK_USAGE_THRESHOLD )); then
    echo "Disk $device is using $use_percent% (threshold: $DISK_USAGE_THRESHOLD%)"
    resize_disk "$device" "$fstype" "$size_kb" "$use_percent" "$mount_point"
  fi
done
