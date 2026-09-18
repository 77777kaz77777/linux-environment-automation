#!/usr/bin/env bash
# Automated security hardening, kernel parameter tuning, and session protection script designed for Fedora KDE.

set -euo pipefail

# Ensure script is executed with superuser privileges
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root (or via sudo)." >&2
    exit 1
fi

LOG_FILE="/var/log/fedora44-hardening.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "================================================================="
echo " Starting Fedora 44 KDE Hardening Script"
echo " Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "================================================================="

# ------------------------------------------------------------------------------
# 1. Kernel & Sysctl Parameter Hardening
# ------------------------------------------------------------------------------
echo "[1/3] Applying kernel & network stack sysctl hardening rules..."

cat << 'EOF' > /etc/sysctl.d/99-security-hardening.conf
# Restrict kernel pointer access in /proc (Fedora defaults to 1, 2 is stricter)
kernel.kptr_restrict = 2

# Disable unprivileged eBPF loading
kernel.unprivileged_bpf_disabled = 1

# Disable core dumps for SUID binaries (Overrides systemd default of 2)
fs.suid_dumpable = 0

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore and do not send ICMP redirects (Mitigates routing spoofing)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF

sysctl --system > /dev/null

# ------------------------------------------------------------------------------
# 2. Core Dump & System Limit Hardening
# ------------------------------------------------------------------------------
echo "[2/3] Disabling system core dumps..."

mkdir -p /etc/systemd/coredump.conf.d
cat << 'EOF' > /etc/systemd/coredump.conf.d/disable-coredump.conf
[Coredump]
Storage=none
ProcessSizeMax=0
EOF

mkdir -p /etc/security/limits.d
cat << 'EOF' > /etc/security/limits.d/99-disable-coredumps.conf
* hard core 0
* soft core 0
EOF

systemctl daemon-reload

# ------------------------------------------------------------------------------
# 3. KDE Plasma Security Environment Defaults (KDE Connect Safe)
# ------------------------------------------------------------------------------
echo "[3/3] Setting secure system-wide KDE Plasma defaults..."

KDE_GLOBAL_CONFIG_DIR="/etc/xdg"

# Force screen lock activation on system sleep/suspend
mkdir -p "${KDE_GLOBAL_CONFIG_DIR}"
cat << 'EOF' > "${KDE_GLOBAL_CONFIG_DIR}/kscreenlockerrc"
[Daemon]
Autolock=true
Timeout=10
LockOnResume=true
EOF

# Disable automatic mounting of unknown storage devices while preserving KDE Connect SFTP mounts
cat << 'EOF' > "${KDE_GLOBAL_CONFIG_DIR}/kded_device_automounterrc"
[GlobalSettings]
automountEnabled=false
automountOnLogin=false
automountOnPlugin=false

[Automounting]
# Explicitly keep KDE Connect remote filesystem integration operational
automountKdeConnect=true
EOF

echo "================================================================="
echo " Hardening Complete! Log saved to ${LOG_FILE}"
echo " A system reboot is recommended to ensure all sysctl settings take full effect."
echo "================================================================="