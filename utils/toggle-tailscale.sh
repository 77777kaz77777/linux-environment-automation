#!/usr/bin/env bash
# Script to easily toggle Tailscale connections, including a prompt for selecting an exit node.
#
# Set TS_EXIT_NODE (an exit node's name or Tailscale IP) to skip typing it each time,
# e.g. in ~/.bashrc:  export TS_EXIT_NODE="my-exit-node"
EXIT_NODE="${TS_EXIT_NODE:-}"

if ! command -v tailscale >/dev/null 2>&1; then
  echo "Tailscale is not installed."
  exit 1
fi

# 'tailscale status' exits non-zero when stopped or logged out
if tailscale status >/dev/null 2>&1; then
  echo "Tailscale is currently: ON"
  echo "---------------------------"
  read -rp "Do you want to turn Tailscale OFF? (y/N): " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Stopping Tailscale..."
    if sudo tailscale down; then
      echo "Tailscale is now OFF."
    else
      echo "Failed to stop Tailscale." >&2
      exit 1
    fi
  else
    echo "Leaving Tailscale ON."
  fi
  exit 0
fi

echo "Tailscale is currently: OFF"
echo "---------------------------"
read -rp "Do you want to turn Tailscale ON? (y/N): " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
  echo "Tailscale remains OFF."
  exit 0
fi

up_args=()
read -rp "Do you want to use an exit node? (y/N): " use_exit
if [[ "$use_exit" =~ ^[Yy]$ ]]; then
  if [ -z "$EXIT_NODE" ]; then
    echo "Available exit nodes:"
    tailscale exit-node list 2>/dev/null || echo "  (start Tailscale once without an exit node to list them)"
    read -rp "Exit node name or IP: " EXIT_NODE
  fi
  if [ -n "$EXIT_NODE" ]; then
    up_args=(--exit-node="$EXIT_NODE" --exit-node-allow-lan-access)
    echo "Starting Tailscale with exit node '$EXIT_NODE'..."
  fi
fi
[ ${#up_args[@]} -eq 0 ] && echo "Starting Tailscale without exit node..."

if sudo tailscale up "${up_args[@]}"; then
  echo "Tailscale is now ON."
else
  echo "Failed to start Tailscale." >&2
  exit 1
fi
