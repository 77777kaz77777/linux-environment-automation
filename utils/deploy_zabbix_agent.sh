#!/bin/bash
# File: deploy_zabbix_agent.sh
# Description: Universal bootstrap script to install and configure Zabbix Agent 2.

# --- CONFIGURATION ---
ZABBIX_SERVER_IP="192.168.X.X" # IMPORTANT: Replace with your Zabbix LXC IP
# ---------------------

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root."
  exit 1
fi

CURRENT_HOSTNAME=$(hostname)
echo "Deploying Zabbix Agent for host: $CURRENT_HOSTNAME"

if [ -f /etc/redhat-release ]; then
  echo "Detected RedHat/Rocky/Fedora OS..."
  rpm -Uvh https://repo.zabbix.com/zabbix/7.0/alma/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm 2>/dev/null
  dnf install -y zabbix-agent2 --nogpgcheck
  
  if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --add-port=10050/tcp --permanent
    firewall-cmd --reload
  fi
elif [ -f /etc/debian_version ]; then
  echo "Detected Debian/Ubuntu OS..."
  wget -q https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-2+debian12_all.deb
  dpkg -i zabbix-release_7.0-2+debian12_all.deb 2>/dev/null
  apt update
  apt install -y zabbix-agent2
else
  echo "Unsupported OS."
  exit 1
fi

echo "Configuring Agent..."
sed -i "s/^Server=127.0.0.1/Server=$ZABBIX_SERVER_IP/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^ServerActive=127.0.0.1/ServerActive=$ZABBIX_SERVER_IP/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^Hostname=Zabbix server/Hostname=$CURRENT_HOSTNAME/" /etc/zabbix/zabbix_agent2.conf

systemctl enable --now zabbix-agent2

echo "Deployment complete. Agent is running and will auto-register."
