#!/bin/bash
## A bash script that hardens Linux Mint by disabling unnecessary services, hardening remaining risky services, applying sysctl kernel/network hardening, setting default file permissions, and reloading systemd.
# --------------------------------------------------
# Linux Mint Hardening Script - Based on Lynis Scan
# Run as root

echo "=== Linux Mint Hardening Script ==="

# -------------------------
# 1. Disable unnecessary services (safe defaults for desktop)
# -------------------------
DISABLE_SERVICES=(
    avahi-daemon.service
    blueman-mechanism.service
    bluetooth.service
    cups.service
    cups-browsed.service
    cups.socket
    ModemManager.service
    openvpn.service
    postfix.service
    zfs-import-cache.service
    zfs-load-module.service
    zfs-mount.service
    zfs-share.service
    zfs-volume-wait.service
    zfs-zed.service
    casper-md5check.service
    casper.service
    irqbalance.service
    touchegg.service
)

echo "[*] Disabling unnecessary services..."
for svc in "${DISABLE_SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^$svc"; then
        systemctl disable --now "$svc" 2>/dev/null
        echo "  - Disabled: $svc"
    fi
done

# -------------------------
# 2. Harden remaining risky services
# -------------------------
HARDEN_SERVICES=(
    avahi-daemon.service
    openvpn.service
    postfix.service
    cups.service
    bluetooth.service
)

echo "[*] Hardening key services..."
for svc in "${HARDEN_SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^$svc"; then
        mkdir -p "/etc/systemd/system/${svc}.d"
        cat <<EOF > "/etc/systemd/system/${svc}.d/hardening.conf"
[Service]
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelModules=true
ProtectControlGroups=true
ProtectClock=true
PrivateDevices=true
RestrictSUIDSGID=true
RestrictNamespaces=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
UMask=027
CapabilityBoundingSet=~
EOF
        echo "  - Hardened: $svc"
    fi
done

# -------------------------
# 3. Sysctl hardening
# -------------------------
echo "[*] Applying sysctl kernel/network hardening..."
cat <<EOF > /etc/sysctl.d/99-hardening.conf
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.tcp_syncookies=1
net.ipv6.conf.all.disable_ipv6=1
EOF
sysctl --system >/dev/null

# -------------------------
# 4. Default file permissions (umask)
# -------------------------
echo "[*] Setting default umask to 027..."
sed -i 's/^UMASK.*/UMASK 027/' /etc/login.defs

# -------------------------
# 5. Reload systemd and restart hardened services
# -------------------------
echo "[*] Reloading systemd..."
systemctl daemon-reexec
for svc in "${HARDEN_SERVICES[@]}"; do
    if systemctl is-enabled "$svc" >/dev/null 2>&1; then
        systemctl restart "$svc"
    fi
done

echo "=== Hardening Complete ==="
echo "Reboot recommended to ensure all changes take effect."
