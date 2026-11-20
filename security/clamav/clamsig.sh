#!/bin/bash
# Force a ClamAV signature update with freshclam.
# Installed by setup-clamav-fedora.sh as /usr/local/bin/clamsig.
if [ "$EUID" -ne 0 ]; then
  echo "This script needs root privileges to stop/start systemd services."
  echo "Re-running script with sudo..."
  exec sudo "$0" "$@"
fi
echo "========================================="
echo "       Forcing ClamAV Signature Update   "
echo "========================================="
echo ""
echo "[1/3] Stopping clamav-freshclam service to release file locks..."
systemctl stop clamav-freshclam.service
# Always restart the background updater, even if the manual update fails
trap 'systemctl start clamav-freshclam.service' EXIT
echo "[2/3] Downloading latest malware definitions from Cisco Talos..."
echo "------------------------------------------------------------"
freshclam
echo "------------------------------------------------------------"
echo "[3/3] Restarting clamav-freshclam for automated background checks..."
echo ""
echo "========================================="
echo "       Update Sequence Complete!         "
echo "========================================="
