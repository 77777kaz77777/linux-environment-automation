#!/bin/bash
# Script to remove Akonadi/PIM bloat, unused media tools, office suites, and clear caches on Fedora KDE.

# Exit immediately if a command fails, an unset variable is referenced, or a pipe breaks
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
LOGDIR="/var/log/packageupdateslogs"
LOGFILE="${LOGDIR}/debloat_fedora.log"

# Ensure the log directory exists with safe permissions
mkdir -p "$LOGDIR"
chmod 755 "$LOGDIR"

# Identify OS release dynamically
FEDORA_VERSION=$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}")

# Logger Function
log_message() {
  local TIMESTAMP
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$TIMESTAMP] $1" | tee -a "$LOGFILE"
}

# -----------------------------------------------------------------------------
# Privilege Check
# -----------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This cleanup script must be run as root or via sudo." >&2
  exit 1
fi

log_message "=== Starting Fedora $FEDORA_VERSION KDE Plasma Debloat & Cleanup ==="

# Remove only the packages that are actually installed. Asking dnf to remove a
# package that isn't installed can make it exit with an error, which would stop
# this script part-way (set -e). Patterns like 'openoffice*' are matched by rpm.
remove_installed() {
  local label="$1"
  shift
  local present=() pkg
  for pkg in "$@"; do
    while IFS= read -r name; do
      [[ -n "$name" ]] && present+=("$name")
    done < <(rpm -qa --qf '%{NAME}\n' "$pkg" 2>/dev/null | sort -u)
  done
  if [[ ${#present[@]} -eq 0 ]]; then
    log_message "${label}: nothing to remove."
    return 0
  fi
  log_message "${label}: removing ${present[*]}"
  dnf remove -y "${present[@]}" 2>&1 | tee -a "$LOGFILE"
}

# -----------------------------------------------------------------------------
# 1. Remove KDE PIM (Personal Information Management) & Akonadi
# -----------------------------------------------------------------------------
remove_installed "KDE PIM stack and Akonadi" \
  akonadi \
  akonadi-server \
  kmail \
  korganizer \
  kaddressbook \
  kontact \
  knotes \
  akregator \
  kdepim-runtime

# -----------------------------------------------------------------------------
# 2. Remove Redundant Utilities, Media Players, Games & Extra Apps
# -----------------------------------------------------------------------------
remove_installed "Extra desktop apps" \
  dragonplayer \
  elisa-player \
  kmahjongg \
  kmines \
  ksudoku \
  kpat \
  konversation \
  kmag \
  kmousetool \
  kwrite \
  krdc \
  krfb \
  mediawriter \
  ktorrent \
  falkon \
  konqueror \
  kamoso \
  skanlite \
  skanpage \
  neochat \
  tokodon \
  kget

# -----------------------------------------------------------------------------
# 3. Remove Office Suites (LibreOffice / OpenOffice)
# -----------------------------------------------------------------------------
remove_installed "Office suites" \
  'libreoffice*' \
  'openoffice*'

# -----------------------------------------------------------------------------
# 4. Clean DNF Packages, Orphans, and System Caches
# -----------------------------------------------------------------------------
log_message "Removing orphaned dependencies..."
dnf autoremove -y 2>&1 | tee -a "$LOGFILE"

log_message "Cleaning DNF metadata and package cache..."
dnf clean all 2>&1 | tee -a "$LOGFILE"

log_message "Trimming systemd journal logs (retaining last 7 days)..."
journalctl --vacuum-time=7d 2>&1 | tee -a "$LOGFILE"

# -----------------------------------------------------------------------------
# 5. Flatpak Cleanup
# -----------------------------------------------------------------------------
if command -v flatpak >/dev/null 2>&1; then
  log_message "Removing unused Flatpak runtimes and applications..."
  flatpak uninstall --unused -y 2>&1 | tee -a "$LOGFILE"

  log_message "Repairing Flatpak installations..."
  flatpak repair 2>&1 | tee -a "$LOGFILE" || log_message "flatpak repair reported problems; continuing."
else
  log_message "Flatpak not installed. Skipping Flatpak cleanup."
fi

# -----------------------------------------------------------------------------
# 6. User-Level Cache Cleanup (KDE Sycoca and Thumbnail Cache)
# -----------------------------------------------------------------------------
log_message "Cleaning KDE system configuration cache and thumbnails for all users..."

# Iterate through all regular user directories in /home
for user_dir in /home/*; do
  if [[ -d "$user_dir" ]]; then
    rm -rf "${user_dir}/.cache/ksycoca"* 2>/dev/null || true
    rm -rf "${user_dir}/.cache/thumbnails"* 2>/dev/null || true
  fi
done

# Clean root cache as well
rm -rf /root/.cache/ksycoca* 2>/dev/null || true
rm -rf /root/.cache/thumbnails* 2>/dev/null || true

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_message "=== Debloat and cleanup completed successfully at $(date)! ==="
echo -e "\n[DONE] System debloated successfully! Rebooting is recommended."
