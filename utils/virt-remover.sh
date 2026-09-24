#!/usr/bin/env bash

# Interactive script to uninstall virt-manager or completely purge the KVM/libvirt virtualization stack.

set -euo pipefail

# Ensure script is executed as root
if [[ "${EUID}" -ne 0 ]]; then
  echo "[-] Error: This script must be run as root or with sudo." >&2
  exit 1
fi

# Detect available package manager
if command -v dnf &>/dev/null; then
  PKG_MANAGER="dnf"
elif command -v apt-get &>/dev/null; then
  PKG_MANAGER="apt"
else
  echo "[-] Error: Unsupported package manager. Only dnf and apt are supported." >&2
  exit 1
fi

# Resolve the home directory of the calling user (when run via sudo)
REAL_USER="${SUDO_USER:-$USER}"
REAL_USER_HOME=$(getent passwd "${REAL_USER}" | cut -d: -f6)

echo "=================================================="
echo "      Virt-Manager / KVM Stack Purge Utility      "
echo "=================================================="
echo "Package Manager Detected: ${PKG_MANAGER}"
echo "Target User Configuration: ${REAL_USER_HOME}/.config/virt-manager"
echo ""
echo "Select purge mode:"
echo "1) GUI Only   - Remove virt-manager (preserves VMs, libvirt, and QEMU)"
echo "2) Full Purge  - Remove virt-manager, libvirt, QEMU, VM disk images, and network bridges"
echo "3) Exit"
echo ""
read -rp "Enter option [1-3]: " CHOICE

case "${CHOICE}" in
  1)
    echo "[+] Removing virt-manager GUI package..."
    if [[ "${PKG_MANAGER}" == "dnf" ]]; then
      dnf remove -y virt-manager
    elif [[ "${PKG_MANAGER}" == "apt" ]]; then
      apt-get purge -y virt-manager
      apt-get autoremove --purge -y
    fi

    echo "[+] Removing user configuration files..."
    rm -rf "${REAL_USER_HOME}/.config/virt-manager"

    echo "[+] Virt-Manager GUI successfully removed."
    ;;

  2)
    echo ""
    echo "[!] WARNING: Full purge will permanently delete all virtual machine images inside /var/lib/libvirt,"
    echo "    configurations in /etc/libvirt, and virtual network interfaces."
    read -rp "Are you sure you want to proceed? [y/N]: " CONFIRM
    if [[ "${CONFIRM}" != [yY] && "${CONFIRM}" != [yY][eE][sS] ]]; then
      echo "[-] Operation cancelled."
      exit 0
    fi

    echo "[+] Stopping virtualization services..."
    systemctl stop libvirtd.service libvirtd.socket virtqemud.service virtqemud.socket virtnetworkd.service virtnetworkd.socket 2>/dev/null || true
    systemctl disable libvirtd.service libvirtd.socket virtqemud.service virtqemud.socket virtnetworkd.service virtnetworkd.socket 2>/dev/null || true

    echo "[+] Uninstalling packages..."
    if [[ "${PKG_MANAGER}" == "dnf" ]]; then
      dnf remove -y virt-manager "libvirt*" "qemu*"
    elif [[ "${PKG_MANAGER}" == "apt" ]]; then
      apt-get purge -y virt-manager "libvirt*" "qemu*" qemu-kvm
      apt-get autoremove --purge -y
    fi

    echo "[+] Removing system and user configuration directories..."
    rm -rf /etc/libvirt /var/lib/libvirt /var/log/libvirt /var/cache/libvirt
    rm -rf "${REAL_USER_HOME}/.config/virt-manager" "${REAL_USER_HOME}/.config/libvirt"

    echo "[+] Deleting virtual network bridge (virbr0) if active..."
    if ip link show virbr0 &>/dev/null; then
      ip link set dev virbr0 down 2>/dev/null || true
      ip link delete virbr0 2>/dev/null || true
    fi

    echo "[+] Reloading systemd manager configuration..."
    systemctl daemon-reload

    echo "[+] Complete virtualization stack purge finished."
    ;;

  3)
    echo "[-] Exiting script."
    exit 0
    ;;

  *)
    echo "[-] Invalid selection. Exiting."
    exit 1
    ;;
esac
