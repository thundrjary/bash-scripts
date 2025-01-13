#!/bin/bash

target_size="${1}" # In gigabytes
file_path="${2}"

if ! [[ "${target_size}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Error: Target size (${target_size}) is not a valid number."
  exit 1
fi

if [[ ! -f "${file_path}" ]]; then
  echo "Error: File path (${file_path}) does not exist or is not a regular file."
  exit 1
fi

target_size_bytes=$(awk "BEGIN {print ${target_size} * 1024 * 1024 * 1024}")
bc_result=$(echo "${target_size_bytes} <= 0" | bc -l)
if (( bc_result )); then
  echo "Error: Target size must be greater than zero."
  exit 1
fi

current_size=$(stat -c "%s" "${file_path}")
if (( current_size >= target_size_bytes )); then
  echo "File is already at or above the target size."
  exit 0
fi

remaining_size=$(( target_size_bytes - current_size ))
if [[ "${remaining_size}" -le 0 ]]; then
  echo "Error: Unexpected remaining size calculation."
  exit 1
fi

start_time=$( date +%s )
start_size="${current_size}"

while [[ "${current_size}" -lt "${target_size_bytes}" ]]
do
  # Get the current file size
  current_size=$(stat -c "%s" "${file_path}" 2>/dev/null | awk '{print $1}')
  if [[ -z "$current_size" ]]; then
    echo "Error: File became inaccessible during monitoring."
    exit 1
  fi

  # Calculate remaining size
  remaining_size=$(( target_size_bytes - current_size ))
  if [[ $remaining_size -le 0 ]]; then
    echo "Error: Unexpected remaining size calculation."
    exit 1
  fi

  # Get current time
  current_time=$( date +%s )

  # Calculate elapsed time
  elapsed_time=$(( current_time - start_time ))
  if [[ "${elapsed_time}" -le 0 ]]; then
    echo "Error: Elapsed time is invalid (${elapsed_time})."
    exit 1
  fi

  # Calculate growth rate in bytes/minute
  growth_rate=$(( (current_size - start_size) / elapsed_time ))
  if [[ "${growth_rate}" -lt 0 ]]; then
    echo "Error: Growth rate calculation failed or became negative (${growth_rate})."
    exit 1
  fi

  # Calculate remaining time in minutes
  remaining_time=$(( remaining_size / growth_rate ))
  if [[ "${remaining_time}" -lt 0 ]]; then
    echo "Error: Remaining time calculation failed or became negative (${remaining_time})."
    exit 1
  fi

  # Calculate current size in GB for display
  current_size_gb=$(( current_size / 1024 / 1024 / 1024 ))
  if [[ "${current_size_gb}" -lt 0 ]]; then
    echo "Error: Current file size in GB is invalid (${current_size_gb})."
    exit 1
  fi

  # Calculate growth rate in MB/min for display
  growth_rate_mb=$(( growth_rate / 1024 ))
  if [[ "${growth_rate_mb}" -lt 0 ]]; then
    echo "Error: Growth rate in MB is invalid (${growth_rate_mb})."
    exit 1
  fi

  # Calculate remaining time in days, hours, and minutes
  remaining_days=$(( remaining_time / 1440 ))
  remaining_hours=$(( (remaining_time % 1440) / 60 ))
  remaining_minutes=$(( remaining_time % 60 ))
  if [[ "${remaining_days}" -lt 0 || "${remaining_hours}" -lt 0 || "${remaining_minutes}" -lt 0 ]]; then
    echo "Error: Remaining time in days, hours, or minutes is invalid."
    exit 1
  fi

  # Display progress
  echo "Current file size: ${current_size_gb} GB"
  echo "Growth rate: ${growth_rate_mb} MB/MINUTE"
  echo "Remaining time until target size: ${remaining_days} days, ${remaining_hours} hours and ${remaining_minutes} minutes"

  # Wait for a minute before the next iteration
  sleep 60
done
