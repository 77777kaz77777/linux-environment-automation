#!/bin/bash
# Script to set a solid black background on the GDM login screen (Ubuntu's GDM).
#
# Note: the com/ubuntu/login-screen setting only exists in Ubuntu's patched GDM.
# On Fedora, Mint (LightDM/Slick Greeter) or KDE (SDDM) it has no effect, so the
# script checks for it first instead of silently doing nothing.

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

if ! command -v dconf >/dev/null 2>&1; then
  echo "dconf is not installed; this script only works with GDM (GNOME's login screen)."
  exit 1
fi

if ! gsettings list-schemas 2>/dev/null | grep -qx 'com.ubuntu.login-screen'; then
  echo "This login screen doesn't support com.ubuntu.login-screen (Ubuntu's GDM only)."
  echo "Nothing was changed."
  exit 1
fi

echo "Step 1: Creating GDM dconf profile..."
mkdir -p /etc/dconf/profile
cat <<EOF >/etc/dconf/profile/gdm
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

echo "Step 2: Creating black background configuration..."
mkdir -p /etc/dconf/db/gdm.d
cat <<EOF >/etc/dconf/db/gdm.d/10-black-bg
[com/ubuntu/login-screen]
background-color='#000000'
EOF

echo "Step 3: Updating dconf database..."
dconf update

echo "------------------------------------------------"
echo "Done! Please log out or restart to see changes."
echo "------------------------------------------------"
