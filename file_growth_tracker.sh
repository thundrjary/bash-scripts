#!/bin/bash

target_size="${1}" # In kilobytes
file_path="${2}"

if ! [[ "${target_size}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Error: Target size (${target_size}) is not a valid number."
  exit 1
fi

if [[ ! -f "${file_path}" ]]; then
  echo "Error: File path (${file_path}) does not exist or is not a regular file."
  exit 1
fi

if [[ ! -r "${file_path}" ]]; then
  echo "Error: File path (${file_path}) is not readable."
  exit 1
fi

echo "Starting file growth monitor"
echo "Target size: ${target_size} KB"
echo "---"

# Convert target size to bytes (KB to bytes)
target_size_bytes=$(( target_size * 1024 ))
if [[ "${target_size_bytes}" -le 0 ]]; then
  echo "Error: Target size must be greater than zero."
  exit 1
fi

# Retrieve file size and handle errors
raw_size=$(wc -c < "${file_path}" 2>/dev/null)
if [[ $? -ne 0 || -z "${raw_size}" ]]; then
  echo "Error: Unable to retrieve file size for ${file_path}."
  exit 1
fi

current_size=$(echo "${raw_size}" | awk '{$1=$1; print}')
if [[ -z "${current_size}" || ! "${current_size}" =~ ^[0-9]+$ ]]; then
  echo "Error: Invalid file size retrieved (${current_size})."
  exit 1
fi

remaining_size=$(( target_size_bytes - current_size ))
if [[ "${remaining_size}" -le 0 ]]; then
  echo "Error: Unexpected remaining size calculation."
  exit 1
fi

start_time=$(date +%s)
start_size="${current_size}"

# Wait 1 second before starting the loop
sleep 1

while [[ "${current_size}" -lt "${target_size_bytes}" ]]; do
  sleep 5  # Adjusted for slow-growing files

  # Retrieve file size
  raw_size=$(wc -c < "${file_path}" 2>/dev/null)
  if [[ $? -ne 0 || -z "${raw_size}" ]]; then
    echo "Error: Unable to retrieve file size for ${file_path}."
    exit 1
  fi

  current_size=$(echo "${raw_size}" | awk '{$1=$1; print}')
  if [[ -z "${current_size}" || ! "${current_size}" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid file size retrieved (${current_size})."
    exit 1
  fi

  # Calculate remaining size
  remaining_size=$(( target_size_bytes - current_size ))
  if [[ "${remaining_size}" -le 0 ]]; then
    echo "Error: Unexpected remaining size calculation."
    exit 1
  fi

  # Get current time and calculate elapsed time
  current_time=$(date +%s)
  elapsed_time=$(( current_time - start_time ))
  if [[ "${elapsed_time}" -lt 1 ]]; then
    elapsed_time=1 # Prevent division by zero
  fi

  # Calculate growth rate
  growth_rate_bytes=$(( (current_size - start_size) / elapsed_time ))
  growth_rate_kb=$(( (growth_rate_bytes * 60) / 1024 )) # Convert to KB/minute

  if [[ "${growth_rate_kb}" -lt 0 ]]; then
    echo "Error: Growth rate calculation failed or became negative (${growth_rate_kb})."
    exit 1
  fi

  # Display progress in KB
  current_size_kb=$(( current_size / 1024 ))
  remaining_size_kb=$(( remaining_size / 1024 ))
  echo "Current file size: ${current_size_kb} KB"
  echo "Remaining size: ${remaining_size_kb} KB"
  echo "Growth rate: ${growth_rate_kb} KB/MINUTE"
done

