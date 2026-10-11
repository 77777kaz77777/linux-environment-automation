#!/bin/bash
# Hardening script to disable unnecessary services, apply sysctl network/kernel protections, and enforce strict file permissions on Linux Mint.
set -euo pipefail

# --- Color Output & Logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()    { echo -e "${GREEN}[+]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_err()     { echo -e "${RED}[X]${NC} $1"; }

# --- Root Check ---
if [[ ${EUID} -ne 0 ]]; then
    log_err "This script must be executed as root. Exiting."
    exit 1
fi

echo "=========================================="
echo "    Linux Mint System Hardening Script    "
echo "=========================================="

# ------------------------------------------------------------------------------
# 1. Disable & Mask Unnecessary Services
# ------------------------------------------------------------------------------
log_info "Disabling and masking unnecessary network/desktop services..."

DISABLE_SERVICES=(
    avahi-daemon.service
    blueman-mechanism.service
    bluetooth.service
    cups.service
    rpcbind.service
)

for service in "${DISABLE_SERVICES[@]}"; do
    if systemctl is-active --quiet "${service}" || systemctl is-enabled --quiet "${service}"; then
        log_info "Stopping and masking ${service}..."
        systemctl stop "${service}" 2>/dev/null || true
        systemctl disable "${service}" 2>/dev/null || true
        systemctl mask "${service}" 2>/dev/null || true
    else
        log_warn "${service} is already inactive/disabled or not installed."
    fi
done

# ------------------------------------------------------------------------------
# 2. Kernel & Network Hardening via sysctl
# ------------------------------------------------------------------------------
log_info "Applying kernel and network hardening parameters..."

SYSCTL_CONF="/etc/sysctl.d/99-lynis-hardening.conf"

cat <<'EOF' > "${SYSCTL_CONF}"
# ----------------------------------------------------
# Network Hardening (IP Routing, Redirects, Spoofing)
# ----------------------------------------------------
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Protect against SYN Flood attacks
net.ipv4.tcp_syncookies = 1

# Ignore ICMP Echo requests (broadcasts) to prevent Smurf attacks
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable Reverse Path Filtering to mitigate IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log packets with impossible addresses (spoofed addresses)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# ----------------------------------------------------
# Kernel Hardening & Memory Protection
# ----------------------------------------------------
# Hide kernel pointers from unprivileged users
kernel.kptr_restrict = 2

# Restrict dmesg output to root
kernel.dmesg_restrict = 1

# Disable unprivileged BPF execution
kernel.unprivileged_bpf_disabled = 1

# Restrict ptrace permissions (process memory access)
kernel.yama.ptrace_scope = 1

# Disable Magic SysRq key combinations
kernel.sysrq = 0

# Append PID to core dump filenames
kernel.core_uses_pid = 1

# Disable core dumps for setuid executables
fs.suid_dumpable = 0
EOF

log_info "Enforcing sysctl settings from ${SYSCTL_CONF}..."
sysctl --system >/dev/null

# ------------------------------------------------------------------------------
# 3. Default File Creation Permissions (umask 027)
# ------------------------------------------------------------------------------
log_info "Setting restrictive umask (027)..."

# Apply to /etc/login.defs for login shells
if grep -E -q "^UMASK" /etc/login.defs; then
    sed -i 's/^UMASK.*/UMASK           027/' /etc/login.defs
else
    echo "UMASK           027" >> /etc/login.defs
fi

# Apply to common profile scripts
PROFILE_FILES=(
    /etc/profile
    /etc/bash.bashrc
)

for file in "${PROFILE_FILES[@]}"; do
    if [[ -f "${file}" ]]; then
        if grep -q "umask" "${file}"; then
            sed -i -E 's/umask [0-9]{3,4}/umask 027/g' "${file}"
        else
            echo "umask 027" >> "${file}"
        fi
    fi
done

# Ensure umask module configuration in PAM (if pam_umask is available)
PAM_COMMON_SESSION="/etc/pam.d/common-session"
if [[ -f "${PAM_COMMON_SESSION}" ]] && ! grep -q "pam_umask.so" "${PAM_COMMON_SESSION}"; then
    echo "session optional pam_umask.so umask=027" >> "${PAM_COMMON_SESSION}"
fi

# ------------------------------------------------------------------------------
# 4. Systemd Maintenance
# ------------------------------------------------------------------------------
log_info "Reloading systemd daemon..."
systemctl daemon-reload

log_info "Hardening routine completed successfully."
log_warn "Reminders:"
log_warn " - Bluetooth or Printing functionality disabled. Run 'systemctl unmask <service>' to restore if needed."
log_warn " - Reboot the system to ensure all kernel/PAM configurations are fully applied."
