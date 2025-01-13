#!/bin/bash

# Get target size in gigabytes and file path
target_size="${1}"
file_path="${2}"

# Validate input: Target size must be a valid number
if ! [[ "${target_size}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Error: Target size (${target_size}) is not a valid number."
  exit 1
fi

# Validate file path: File must exist and be a regular file
if [[ ! -f "${file_path}" ]]; then
  echo "Error: File path (${file_path}) does not exist or is not a regular file."
  exit 1
fi

# Convert target size to bytes
target_size_bytes=$(awk "BEGIN {print ${target_size} * 1024 * 1024 * 1024}")
if (( $(echo "${target_size_bytes} <= 0" | bc -l) )); then
  echo "Error: Target size must be greater than zero."
  exit 1
fi

# Get current size of file in bytes
current_size=$(stat -c "%s" "${file_path}")
if (( current_size >= target_size_bytes )); then
  echo "File is already at or above the target size."
  exit 0
fi

# Calculate remaining size in bytes
remaining_size=$(( target_size_bytes - current_size ))

# Get the start time and start size
start_time=$( date +%s )
start_size="${current_size}"

# Continuously update countdown
while [[ "${current_size}" -lt "${target_size_bytes}" ]]
do
  current_size=$( du -b "${file_path}" | awk '{print $1}' )
  remaining_size=$(( target_size_bytes - current_size ))
  
  # Calculate the growth rate in bytes/minute
  current_time=$( date +%s )
  elapsed_time=$(( current_time - start_time ))
  if [[ "${elapsed_time}" -ne 0 ]]; then
    growth_rate=$(( (current_size - start_size) / elapsed_time ))

    # Calculate how much longer it will take to reach the target size
    remaining_time=$(( remaining_size / growth_rate ))
  else
    growth_rate=0
    remaining_time=0
  fi

  # Display current size in GB
  current_size_gb=$(( current_size / 1024 / 1024 / 1024 ))
  growth_rate_mb=$(( growth_rate / 1024 ))
  echo "Current file size: ${current_size_gb} GB"
  echo "Growth rate: ${growth_rate_mb} MB/MINUTE"

  # Display remaining time in days, hours and minutes
  remaining_days=$(( remaining_time / 1440 ))
  remaining_hours=$(( remaining_time % 1440 / 60 ))
  remaining_minutes=$(( remaining_time % 1440 % 60 ))
  echo "Remaining time until target size: ${remaining_days} days, ${remaining_hours} hours and ${remaining_minutes} minutes"
  sleep 60
done
