#!/bin/bash

# Function to print usage/help
usage() {
  echo "Usage: $0 <jump_host> <target_host> <ports>"
  echo ""
  echo "Arguments:"
  echo "  jump_host   The first SSH jump host (e.g., 'mn5-acc-4')."
  echo "  target_host The second SSH target machine (e.g., 'as05r1b08')."
  echo "  ports       Port(s) to forward. Can be:"
  echo "              - A single port (e.g., '8000')"
  echo "              - A list of ports (comma-separated, e.g., '8000,9000,10000')"
  echo "              - A range of ports (e.g., '8000-8005')"
  echo ""
  echo "Examples:"
  echo "  $0 mn5-acc-4 as05r1b08 8000"
  echo "  $0 mn5-acc-4 as05r1b08 8000,9000,10000"
  echo "  $0 mn5-acc-4 as05r1b08 8000-8005"
  exit 1
}

# Check if the user needs help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
fi

# Check if we have exactly 3 arguments
if [[ $# -ne 3 ]]; then
  echo "Error: Invalid number of arguments."
  usage
fi

JUMP_HOST="$1"
TARGET_HOST="$2"
PORT_ARG="$3"

# Function to parse port argument (supports single, list, and range)
parse_ports() {
  local input="$1"
  local ports=()

  # Split by comma
  IFS=',' read -ra ADDR <<<"$input"
  for part in "${ADDR[@]}"; do
    if [[ "$part" =~ ^[0-9]+-[0-9]+$ ]]; then
      # Handle port range (e.g., "8000-8005")
      IFS='-' read -r start end <<<"$part"
      for ((p = start; p <= end; p++)); do
        ports+=("$p")
      done
    elif [[ "$part" =~ ^[0-9]+$ ]]; then
      # Handle single port
      ports+=("$part")
    else
      echo "Error: Invalid port format '$part'"
      usage
    fi
  done

  echo "${ports[@]}"
}

# Parse ports
PORTS=($(parse_ports "$PORT_ARG"))

# Build SSH command with port forwarding
PORT_FORWARDING=""
for p in "${PORTS[@]}"; do
  PORT_FORWARDING+="-L ${p}:localhost:${p} "
done

SSH_CMD="ssh -4 -t -t $JUMP_HOST $PORT_FORWARDING ssh -4 $TARGET_HOST $PORT_FORWARDING"

# Print and execute the SSH command
echo "Executing: $SSH_CMD"
eval "$SSH_CMD"
