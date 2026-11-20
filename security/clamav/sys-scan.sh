#!/bin/bash
# Manual multi-threaded ClamAV daemon scan of /home and system binaries.
# Installed by setup-clamav-fedora.sh as /usr/local/bin/sys-scan.
CONF_ARGS=()
[ -f /etc/clamd.d/scan.conf ] && CONF_ARGS=(--config-file=/etc/clamd.d/scan.conf)

echo "========================================="
echo "    Starting Manual ClamAV System Scan   "
echo "========================================="
echo "Scanning: /home, /usr/bin, /usr/local/bin"
echo "Please wait..."
echo ""
clamdscan "${CONF_ARGS[@]}" --fdpass --multiscan /home /usr/bin /usr/local/bin
rc=$?
echo ""
echo "========================================="
case $rc in
  0) echo "        Scan complete: no threats        " ;;
  1) echo "   Scan complete: INFECTED FILES FOUND   " ;;
  *) echo "   Scan failed (is clamd@scan running?)  " ;;
esac
echo "========================================="
exit $rc
