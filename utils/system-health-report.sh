#!/usr/bin/env bash
# Diagnostic script that generates a quick report on system health, disk usage, and failed services.
# Enforce strict error handling
set -euo pipefail

# Safely resolve hostname for minimal environments
if command -v hostname >/dev/null 2>&1; then
  CURRENT_HOSTNAME=$(hostname)
elif [ -r /etc/hostname ]; then
  CURRENT_HOSTNAME=$(cat /etc/hostname)
else
  CURRENT_HOSTNAME="Unknown"
fi

echo "=================================================="
echo "           SYSTEM HEALTH REPORT                   "
echo "           Date: $(date "+%Y-%m-%d %H:%M:%S")     "
echo "           Hostname: ${CURRENT_HOSTNAME}          "
echo "=================================================="
echo ""

# 1. Check Uptime and CPU Load Average
echo "[+] Uptime & CPU Load Average:"
if command -v uptime >/dev/null 2>&1; then
  uptime
elif [ -r /proc/uptime ] && [ -r /proc/loadavg ]; then
  # Fallback for environments without the 'uptime' binary
  up_seconds=$(cut -d. -f1 /proc/uptime)
  up_days=$((up_seconds / 86400))
  up_hours=$(((up_seconds % 86400) / 3600))
  up_mins=$(((up_seconds % 3600) / 60))
  load_avg=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
  echo "up ${up_days} days, ${up_hours}:${up_mins},  load average: ${load_avg}"
else
  echo "    ⚠️ 'uptime' command not found and /proc metrics are unavailable."
fi
echo ""

# 2. Check Memory & Swap Usage
echo "[+] Memory Usage:"
if command -v free >/dev/null 2>&1; then
  free -h
elif [ -r /proc/meminfo ]; then
  # Fallback for environments without the 'free' binary (missing procps)
  grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree' /proc/meminfo
else
  echo "    ⚠️ 'free' command not found and /proc/meminfo is unavailable."
fi
echo ""

# 3. Check Disk Space
echo "[+] Real Disk Space Usage:"
if command -v df >/dev/null 2>&1; then
  df -h -T -x tmpfs -x devtmpfs -x squashfs -x efivarfs || true
  echo ""

  # 4. Check for Disk Space Warnings (>85% capacity)
  echo "[+] Disk Capacity Warnings:"
  warning_found=false
  # Parse df output, grab usage percentage and mount point, skipping the header line
  while read -r usage mount; do
    # Remove the % sign for integer comparison
    usage_val=${usage%\%}

    # Ensure the parsed value is a number before attempting an integer comparison.
    if [[ "$usage_val" =~ ^[0-9]+$ ]]; then
      if [ "$usage_val" -gt 85 ]; then
        echo "    ⚠️  WARNING: Partition '$mount' is at ${usage} capacity!"
        warning_found=true
      fi
    fi
  done < <(df -h -T -x tmpfs -x devtmpfs -x squashfs -x efivarfs 2>/dev/null | awk 'NR>1 {print $6, $7}')

  if [ "$warning_found" = false ]; then
    echo "    ✅ No partitions are above 85% capacity."
  fi
else
  echo "    ⚠️ 'df' command not found. Skipping disk checks."
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

# Fallback for SysVinit or environments with no init daemon (e.g., Docker containers)
else
  echo "    ⚠️  Init system not recognized as Systemd, OpenRC, or Runit."
  echo "    ℹ️  Skipping automated failed service detection."
fi

echo ""
echo "=================================================="
echo "                 REPORT COMPLETE                  "
echo "=================================================="
