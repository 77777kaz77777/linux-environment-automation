#!/bin/bash
# Automated script to install and set up ClamAV on Fedora.
#
# Installs ClamAV if needed, configures and starts the clamd@scan daemon and the
# freshclam signature updater, and adds:
#   sys-scan  - manual scan of /home, /usr/bin and /usr/local/bin
#   clamsig   - force a signature update
#   a nightly scan at 2:00 AM (clamav-nightly-scan.timer)
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "This setup script requires root privileges. Run with sudo."
  exit 1
fi

SCAN_CONF="/etc/clamd.d/scan.conf"
FRESHCLAM_CONF="/etc/freshclam.conf"
SOCKET="/run/clamd.scan/clamd.sock"

# -----------------------------------------------------------------------------
# 0. Install ClamAV if it is missing
# -----------------------------------------------------------------------------
echo "Checking for Fedora ClamAV packages..."
if ! command -v clamdscan >/dev/null 2>&1 || ! command -v freshclam >/dev/null 2>&1 || [ ! -f "$SCAN_CONF" ]; then
  echo "Installing clamav, clamav-freshclam and clamd..."
  dnf install -y clamav clamav-freshclam clamd
fi
echo "ClamAV is installed. Proceeding with Fedora configuration setup..."

# -----------------------------------------------------------------------------
# 1. Configure the scan daemon and the updater
# -----------------------------------------------------------------------------
# Fedora ships these files with an "Example" line that stops the programs from
# starting until it is commented out, and with the local socket disabled.
for conf in "$SCAN_CONF" "$FRESHCLAM_CONF"; do
  if [ -f "$conf" ] && grep -q '^Example' "$conf"; then
    sed -i 's/^Example/#Example/' "$conf"
    echo "Enabled $conf (commented out the 'Example' line)."
  fi
done

if grep -q "^LocalSocket " "$SCAN_CONF"; then
  echo "clamd local socket already configured."
elif grep -q "^#LocalSocket " "$SCAN_CONF"; then
  sed -i "s|^#LocalSocket .*|LocalSocket $SOCKET|" "$SCAN_CONF"
  echo "Enabled clamd local socket at $SOCKET."
else
  echo "LocalSocket $SOCKET" >>"$SCAN_CONF"
  echo "Added clamd local socket at $SOCKET."
fi

# Let ClamAV read system and home directories under SELinux
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" = "Enforcing" ]; then
  echo "SELinux is Enforcing. Enabling antivirus_can_scan_system boolean..."
  setsebool -P antivirus_can_scan_system 1
fi

# clamd will not start without a signature database, so fetch one first
if ! ls /var/lib/clamav/*.c[lv]d >/dev/null 2>&1; then
  echo "Downloading the first signature database (this can take a minute)..."
  freshclam
fi

echo "Enabling the signature updater and the scan daemon..."
systemctl enable --now clamav-freshclam.service
systemctl enable --now clamd@scan.service

# -----------------------------------------------------------------------------
# 2. Nightly scan script
# -----------------------------------------------------------------------------
echo "Creating nightly scan script at /usr/local/bin/clamav-nightly-scan.sh..."
cat <<'EOF' >/usr/local/bin/clamav-nightly-scan.sh
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
EOF
chmod 755 /usr/local/bin/clamav-nightly-scan.sh

# -----------------------------------------------------------------------------
# 3. systemd service + timer
# -----------------------------------------------------------------------------
echo "Creating systemd service at /etc/systemd/system/clamav-nightly-scan.service..."
cat <<'EOF' >/etc/systemd/system/clamav-nightly-scan.service
[Unit]
Description=Trigger multi-threaded ClamAV system scan
Wants=clamd@scan.service
After=clamd@scan.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/clamav-nightly-scan.sh
Nice=10
IOSchedulingClass=idle
EOF

echo "Creating systemd timer at /etc/systemd/system/clamav-nightly-scan.timer..."
cat <<'EOF' >/etc/systemd/system/clamav-nightly-scan.timer
[Unit]
Description=Run ClamAV Scan Automatically

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# -----------------------------------------------------------------------------
# 4. Manual scan command: sys-scan
# -----------------------------------------------------------------------------
echo "Creating manual scan script at /usr/local/bin/sys-scan..."
cat <<'EOF' >/usr/local/bin/sys-scan
#!/bin/bash
# Manual multi-threaded ClamAV daemon scan of /home and system binaries.
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
EOF
chmod 755 /usr/local/bin/sys-scan

# -----------------------------------------------------------------------------
# 5. Manual signature update command: clamsig
# -----------------------------------------------------------------------------
echo "Creating manual updater script at /usr/local/bin/clamsig..."
cat <<'EOF' >/usr/local/bin/clamsig
#!/bin/bash
# Force a ClamAV signature update.
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
EOF
chmod 755 /usr/local/bin/clamsig

# -----------------------------------------------------------------------------
# 6. Activate the timer
# -----------------------------------------------------------------------------
echo "Reloading systemd daemon to recognize new units..."
systemctl daemon-reload
echo "Enabling and starting clamav-nightly-scan.timer..."
systemctl enable --now clamav-nightly-scan.timer

echo "========================================="
echo "Fedora Setup complete! The following system-wide commands are available:"
echo "1. sys-scan (Run a manual scan)"
echo "2. clamsig (Force virus definitions update)"
echo "Note: The nightly scan will trigger automatically via systemd at 2:00 AM."
echo "Check status any time with: systemctl status clamd@scan clamav-nightly-scan.timer"
echo "========================================="
