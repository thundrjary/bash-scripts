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

if [[ ! -r "${file_path}" ]]; then
  echo "Error: File path (${file_path}) is not readable."
  exit 1
fi

echo "Starting file growth monitor"
echo "Target size: ${target_size} GB"
echo "Initial size: $(( current_size / 1024 / 1024 / 1024 )) GB"
echo "---"

target_size_bytes=$(awk "BEGIN {print ${target_size} * 1024 * 1024 * 1024}")
bc_result=$(echo "${target_size_bytes} <= 0" | bc -l)
if (( bc_result )); then
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

# Ensure the size is numeric
if ! [[ "${current_size}" =~ ^[0-9]+$ ]]; then
  echo "Error: Invalid file size retrieved (${current_size})."
  exit 1
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
  # Wait for at least 1 second to ensure elapsed_time is non-zero
  sleep 1

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

  # Validate the retrieved size
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

  # Display progress
  echo "Current file size: $((current_size / 1024 / 1024 / 1024)) GB"
  echo "Growth rate: $((growth_rate / 1024)) MB/MINUTE"
  echo "Remaining time until target size: $((remaining_time / 1440)) days, $(((remaining_time % 1440) / 60)) hours and $((remaining_time % 60)) minutes"

  # Wait for a small delay before the next iteration
  sleep 6
done
