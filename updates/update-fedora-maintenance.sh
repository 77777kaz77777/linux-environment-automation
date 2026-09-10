#!/usr/bin/env bash
# Full-system cleanup routine for Fedora (Caches, Orphans, Logs, KDE, Trash).
# Exit on error, treat unset variables as error
set -euo pipefail

# Visual formatting constants
BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
RESET="\033[0m"

# -----------------------------------------------------------------------------
# Root Privilege Check & Context Resolution
# -----------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo -e "${BOLD}\033[31m[ERROR] This script must be run as root or via sudo.${RESET}" >&2
  exit 1
fi

# Determine the actual non-root user who invoked sudo
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
FEDORA_VERSION=$(grep -oP '(?<=^VERSION_ID=).*' /etc/os-release | tr -d '"' 2>/dev/null || echo "Fedora")

echo -e "${BOLD}${CYAN}=== Starting Fedora $FEDORA_VERSION System Cleanup ===${RESET}\n"

# -----------------------------------------------------------------------------
# 1. Package Cleanup & Orphan Removal
# -----------------------------------------------------------------------------
echo -e "${GREEN}[1/4] Cleaning package manager caches and orphan packages...${RESET}"
dnf autoremove -y
dnf clean all

# -----------------------------------------------------------------------------
# 2. Clean Flatpak Unused Runtimes
# -----------------------------------------------------------------------------
if command -v flatpak &>/dev/null; then
  echo -e "\n${GREEN}[2/4] Removing unused Flatpak runtimes...${RESET}"
  flatpak uninstall --unused --system -y

  # Clean user-level runtimes
  if [[ "$TARGET_USER" != "root" ]]; then
    TARGET_UID=$(id -u "$TARGET_USER")
    sudo -u "$TARGET_USER" env XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
      flatpak uninstall --unused --user -y || true
  fi
fi

# -----------------------------------------------------------------------------
# 3. Clear Systemd Logs & User KDE Plasma Cache
# -----------------------------------------------------------------------------
echo -e "\n${GREEN}[3/4] Clearing old systemd logs and KDE Plasma cache...${RESET}"
journalctl --vacuum-time=7d

if [[ "$TARGET_USER" != "root" && -d "$TARGET_HOME" ]]; then
  echo "Cleaning user cache for $TARGET_USER..."
  # Executing file removals strictly as the target user to avoid modifying cache permissions
  sudo -u "$TARGET_USER" bash -c "
    rm -rf '${TARGET_HOME}/.cache/kiconcache'* 2>/dev/null || true
    rm -rf '${TARGET_HOME}/.cache/kioexec/' 2>/dev/null || true
    rm -rf '${TARGET_HOME}/.cache/ksycoca'* 2>/dev/null || true
    rm -rf '${TARGET_HOME}/.cache/plasma'* 2>/dev/null || true
  "
fi

# -----------------------------------------------------------------------------
# 4. Empty User Trash
# -----------------------------------------------------------------------------
echo -e "\n${GREEN}[4/4] Emptying Trash for $TARGET_USER...${RESET}"
if [[ "$TARGET_USER" != "root" && -d "${TARGET_HOME}/.local/share/Trash" ]]; then
  # Sudo execution prevents creating root-owned files in the user's trash directory during failures
  sudo -u "$TARGET_USER" bash -c "
    rm -rf '${TARGET_HOME}/.local/share/Trash/files/'* 2>/dev/null || true
    rm -rf '${TARGET_HOME}/.local/share/Trash/info/'* 2>/dev/null || true
  "
fi

echo -e "\n${BOLD}${GREEN}✔ System cleanup completed successfully!${RESET}"
