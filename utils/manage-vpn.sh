#!/bin/bash
# Quick toggle script to bring WireGuard connections up or down using WG-Quick.
#
# Usage: manage-vpn.sh [interface-or-config]
#   interface-or-config  a name from /etc/wireguard (e.g. wg0) or a full path to a .conf file.
#                        Defaults to $WG_CONFIG, then to the only config in /etc/wireguard.

CONFIG="${1:-${WG_CONFIG:-}}"

# Pick the only config in /etc/wireguard if none was given
if [ -z "$CONFIG" ]; then
  mapfile -t configs < <(sudo find /etc/wireguard -maxdepth 1 -name '*.conf' -printf '%f\n' 2>/dev/null | sed 's/\.conf$//')
  if [ ${#configs[@]} -eq 1 ]; then
    CONFIG="${configs[0]}"
  else
    echo "Which WireGuard config? Pass a name or path, or set WG_CONFIG."
    [ ${#configs[@]} -gt 1 ] && echo "Found in /etc/wireguard: ${configs[*]}"
    exit 1
  fi
fi

# Interface name, for the status check
IFACE=$(basename "$CONFIG" .conf)

is_up() { ip link show "$IFACE" >/dev/null 2>&1; }

turn_on() {
  echo "Turning on WireGuard interface $IFACE..."
  if sudo wg-quick up "$CONFIG"; then
    echo "WireGuard interface $IFACE is now up."
  else
    echo "Failed to bring up the WireGuard interface $IFACE." >&2
    return 1
  fi
}

turn_off() {
  echo "Turning off WireGuard interface $IFACE..."
  if sudo wg-quick down "$CONFIG"; then
    echo "WireGuard interface $IFACE is now down."
  else
    echo "Failed to bring down the WireGuard interface $IFACE." >&2
    return 1
  fi
}

if is_up; then
  echo "WireGuard $IFACE is currently: UP"
else
  echo "WireGuard $IFACE is currently: DOWN"
fi
echo "1) Turn On"
echo "2) Turn Off"
read -rp "Please enter your choice (1 or 2): " choice

case "$choice" in
  1) turn_on ;;
  2) turn_off ;;
  *)
    echo "Invalid choice. Please enter 1 or 2."
    exit 1
    ;;
esac
