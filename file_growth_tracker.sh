#!/bin/bash

# Functions
validate_inputs() {
  local target_size="${1}"
  local file_path="${2}"

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
}

calculate_growth_rate() {
  local start_size="${1}"
  local current_size="${2}"
  local elapsed_time="${3}"

  if [[ "${elapsed_time}" -lt 1 ]]; then
    elapsed_time=1 # Prevent division by zero
  fi

  local growth_rate_bytes=$(( (current_size - start_size) / elapsed_time ))
  local growth_rate_kb=$(( (growth_rate_bytes * 60) / 1024 ))

  echo "${growth_rate_kb}" # Return growth rate
}

main() {
  local target_size="${1}" # In kilobytes
  local file_path="${2}"

  # Validate inputs
  validate_inputs "${target_size}" "${file_path}"

  echo "Starting file growth monitor"
  echo "Target size: ${target_size} KB"
  echo "---"

  # Convert target size to bytes (KB to bytes)
  local target_size_bytes=$(( target_size * 1024 ))
  if [[ "${target_size_bytes}" -le 0 ]]; then
    echo "Error: Target size must be greater than zero."
    exit 1
  fi

  # Retrieve initial file size
  local raw_size
  raw_size=$(wc -c < "${file_path}" 2>/dev/null)
  if [[ $? -ne 0 || -z "${raw_size}" ]]; then
    echo "Error: Unable to retrieve file size for ${file_path}."
    exit 1
  fi

  local current_size
  current_size=$(echo "${raw_size}" | awk '{$1=$1; print}')
  if [[ -z "${current_size}" || ! "${current_size}" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid file size retrieved (${current_size})."
    exit 1
  fi

  local remaining_size=$(( target_size_bytes - current_size ))
  if [[ "${remaining_size}" -le 0 ]]; then
    echo "Error: Unexpected remaining size calculation."
    exit 1
  fi

  local start_time
  start_time=$(date +%s)
  local start_size="${current_size}"

  # Monitor file growth
  while [[ "${current_size}" -lt "${target_size_bytes}" ]]; do
    sleep 5  # Adjusted for slow-growing files

    # Retrieve current file size
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

    # Get elapsed time and calculate growth rate
    local current_time
    current_time=$(date +%s)
    local elapsed_time=$(( current_time - start_time ))
    local growth_rate_kb
    growth_rate_kb=$(calculate_growth_rate "${start_size}" "${current_size}" "${elapsed_time}")

    # Display progress in KB
    local current_size_kb=$(( current_size / 1024 ))
    local remaining_size_kb=$(( remaining_size / 1024 ))
    echo "Current file size: ${current_size_kb} KB"
    echo "Remaining size: ${remaining_size_kb} KB"
    echo "Growth rate: ${growth_rate_kb} KB/MINUTE"
  done
}

main "$@"
