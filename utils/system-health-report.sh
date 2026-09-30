#!/usr/bin/env bash
# Diagnostic script that generates a quick report on system health, disk usage, and failed services.
# Enforce strict error handling
set -euo pipefail

echo "=================================================="
echo "           SYSTEM HEALTH REPORT                   "
echo "           Date: $(date "+%Y-%m-%d %H:%M:%S")     "
echo "           Hostname: $(hostname)                  "
echo "=================================================="
echo ""

# 1. Check Uptime and CPU Load Average
# The load averages represent 1, 5, and 15 minute intervals.
echo "[+] Uptime & CPU Load Average:"
uptime
echo ""

# 2. Check Memory & Swap Usage
# -h provides human-readable output (MB/GB).
echo "[+] Memory Usage:"
free -h
echo ""

# 3. Check Disk Space
# -h: Human readable
# -T: Print file system type
# -x: Exclude temporary and loop/snap/flatpak filesystems for a cleaner output
echo "[+] Real Disk Space Usage:"
df -h -T -x tmpfs -x devtmpfs -x squashfs -x efivarfs
echo ""

# 4. Check for Disk Space Warnings (>85% capacity)
echo "[+] Disk Capacity Warnings:"
warning_found=false
# Parse df output, grab usage percentage and mount point, skipping the header line
while read -r usage mount; do
  # Remove the % sign for integer comparison
  usage_val=${usage%\%}
  
  # Ensure the parsed value is a number before attempting an integer comparison.
  # This prevents syntax errors if a specific distro's df output misaligns the columns.
  if [[ "$usage_val" =~ ^[0-9]+$ ]]; then
    if [ "$usage_val" -gt 85 ]; then
      echo "    ⚠️  WARNING: Partition '$mount' is at ${usage} capacity!"
      warning_found=true
    fi
  fi
done < <(df -h -T -x tmpfs -x devtmpfs -x squashfs -x efivarfs | awk 'NR>1 {print $6, $7}')

if [ "$warning_found" = false ]; then
  echo "    ✅ No partitions are above 85% capacity."
fi
echo ""

# 5. Check for Failed Services (Distro-Agnostic Init System Detection)
echo "[+] Failed Services:"

# Check for Systemd (Ubuntu, Debian, Fedora, Arch, openSUSE)
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  failed_services=$(systemctl --failed --no-legend --plain)
  if [ -z "$failed_services" ]; then
    echo "    ✅ No failed systemd services. System is running cleanly."
  else
    echo "    ❌ WARNING: The following systemd services have failed:"
    echo "$failed_services"
  fi

# Check for OpenRC (Alpine Linux, Gentoo, Artix)
elif command -v rc-status >/dev/null 2>&1; then
  # rc-status --crashed specifically outputs services that have crashed
  failed_services=$(rc-status --crashed --nocolor | grep -v 'crashed')
  if [ -z "$failed_services" ] || [[ "$failed_services" == *"(empty)"* ]]; then
    echo "    ✅ No crashed OpenRC services. System is running cleanly."
  else
    echo "    ❌ WARNING: The following OpenRC services have crashed:"
    rc-status --crashed --nocolor
  fi

# Check for Runit (Void Linux, Artix Runit variant)
elif command -v sv >/dev/null 2>&1 && [ -d /var/service ]; then
  echo "    ℹ️  System uses Runit. Showing current service states (check for unexpected 'down' states):"
  sv status /var/service/*

# Fallback for SysVinit or other unhandled systems (Devuan, Slackware, etc.)
else
  echo "    ⚠️  Init system not recognized as Systemd, OpenRC, or Runit."
  echo "    ℹ️  Skipping automated failed service detection."
fi

echo ""
echo "=================================================="
echo "                 REPORT COMPLETE                  "
echo "=================================================="
