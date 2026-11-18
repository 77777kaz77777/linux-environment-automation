#!/bin/bash
# ClamAV scan script designed to run nightly (via clamav-nightly-scan.timer).
LOGFILE="/var/log/clamav/daily_scan.log"
mkdir -p /var/log/clamav

# Fedora's clamd@scan uses /etc/clamd.d/scan.conf; other distros use the default config
CONF_ARGS=()
[ -f /etc/clamd.d/scan.conf ] && CONF_ARGS=(--config-file=/etc/clamd.d/scan.conf)

echo "=== Scan Started: $(date) ===" >>"$LOGFILE"
clamdscan "${CONF_ARGS[@]}" --fdpass --infected --multiscan --log="$LOGFILE" /home /usr/bin /usr/local/bin
rc=$?
echo "=== Scan Finished: $(date) (exit code $rc: 0 = clean, 1 = infected files found, 2 = error) ===" >>"$LOGFILE"
exit $rc
