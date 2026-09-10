#!/usr/bin/env bash
# Automated system update script for Debian/Mint handling APT, Flatpaks, and cleanups.

# Exit immediately if a command exits with a non-zero status
set -e
# Ensure pipeline failures are caught instead of masked by tee
set -o pipefail

# Require root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: This maintenance script must be run as root (use sudo)." >&2
  exit 1
fi

# Log configuration
LOGDIR="/var/log/packageupdateslogs"
LOGFILE="$LOGDIR/update_system.log"

# Identify non-root user for user-level Flatpak updates
TARGET_USER="${SUDO_USER:-$USER}"

# Ensure the log directory exists with safe permissions
mkdir -p "$LOGDIR"
chmod 755 "$LOGDIR"

# Function to log timestamped messages
log_message() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOGFILE"
}

log_message "=== Starting System Maintenance ==="

# 1. Update APT Package Index
log_message "Updating APT package index..."
# Removed invalid '-y' flag and added error fallback to prevent PPA timeouts from halting the script
apt-get update -q 2>&1 | tee -a "$LOGFILE" || { log_message "Warning: Repository update encountered non-fatal errors."; }

# 2. Upgrade APT Packages
log_message "Upgrading installed APT packages..."
DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -q 2>&1 | tee -a "$LOGFILE"

# 3. Remove Unnecessary APT Packages
log_message "Removing unnecessary orphaned dependencies..."
apt-get autoremove -y -q 2>&1 | tee -a "$LOGFILE"

# 4. Clean APT Package Cache
log_message "Cleaning local package cache..."
apt-get autoclean -q 2>&1 | tee -a "$LOGFILE"

# 5. Update System & User Flatpaks
if command -v flatpak &>/dev/null; then
  log_message "Updating system-wide Flatpak applications..."
  flatpak update --system -y 2>&1 | tee -a "$LOGFILE" || true

  log_message "Cleaning unused Flatpak runtimes..."
  flatpak uninstall --unused --system -y 2>&1 | tee -a "$LOGFILE" || true

  # Update user-level Flatpaks if executed via sudo
  if [ "$TARGET_USER" != "root" ]; then
    log_message "Updating user-level Flatpaks for $TARGET_USER..."
    TARGET_UID=$(id -u "$TARGET_USER")
    # Export required D-Bus and XDG environment variables for the target user session
    sudo -u "$TARGET_USER" env XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
         DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
         flatpak update --user -y 2>&1 | tee -a "$LOGFILE" || true
  fi
else
  log_message "Flatpak is not installed. Skipping Flatpak updates..."
fi

# Completion Message
log_message "All updates and cleanups completed successfully!"
echo "" >>"$LOGFILE"
