#!/bin/bash
#  Cleanup routine for clearing out old APT packages and caches on Linux Mint.

# Ensure we are running with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Purge only packages that are installed. If one name in an 'apt purge' list
# doesn't exist, apt aborts the whole list, so filter first.
purge_installed() {
  local present=() pkg
  for pkg in "$@"; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" && present+=("$pkg")
  done
  if [ ${#present[@]} -eq 0 ]; then
    echo "  (none installed)"
    return 0
  fi
  apt purge -y "${present[@]}"
}

MINT_VERSION=$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}")
echo "--- Starting Mint ${MINT_VERSION} Debloat (Safe Mode) ---"

# 1. Remove Legacy/Insecure Network Tools
echo "Removing legacy network tools (telnet, etc)..."
purge_installed telnet ftp rsh-client talk

# 2. Remove "Common" Pre-installed Bloat
# This targets apps most people replace or never use.
echo "Removing common bloat apps..."
purge_installed \
  hexchat \
  thunderbird \
  transmission-common \
  transmission-gtk \
  drawing \
  sticky \
  pix \
  hypnotix \
  thingy \
  warpinator \
  gnome-calendar \
  gnome-logs

# 3. Remove Default Games
echo "Removing pre-installed games..."
purge_installed gnome-chess five-or-more four-in-a-row gnome-klotski gnome-mahjongg gnome-mines gnome-nibbles gnome-robots gnome-sudoku gnome-taquin gnome-tetravex hitori iagno lightsoff quadrapassel tali swell-foop

# 4. Cleanup Unused Dependencies
echo "Cleaning up..."
apt autoremove -y
apt clean

echo "--- Debloat Complete! ---"
echo "Note: Printer (CUPS) and Bluetooth services were kept intact."
echo "      (security/hardening/mint-hardening.sh disables both, if you run that too.)"
