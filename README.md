# 🐧 Linux-environment-automation

Centralized operations toolkit for Linux workstation provisioning, security hardening, and maintenance automation across Fedora, Arch, and Debian-based systems.

---

## 🌳 Repository Structure

<!-- START_SECTION:tree -->
### 📁 configs (Terminal & CLI tool dotfiles)

| File | Description |
| --- | --- |
| <a href="configs/alacritty.toml"><code>alacritty.toml</code></a> | Configuration file for the Alacritty terminal emulator. |
| <a href="configs/dnf.conf"><code>dnf.conf</code></a> | Optimized Fedora DNF package manager config tweaked for max download speeds, parallel downloads, and clean dependency management. |
| <a href="configs/fastfetch-laptop1-config.jsonc"><code>fastfetch-laptop1-config.jsonc</code></a> | Fastfetch system info configuration for the primary laptop (ASUS ROG Zephyrus G15). |
| <a href="configs/fastfetch-laptop2-config.jsonc"><code>fastfetch-laptop2-config.jsonc</code></a> | Fastfetch system info configuration for the secondary laptop (Lenovo ThinkPad T470). |

### 📁 configs/setup-scripts (Dotfile Deployment Scripts)

| File | Description |
| --- | --- |
| <a href="configs/setup-scripts/setup-alacritty.sh"><code>setup-alacritty.sh</code></a> | Automates Alacritty installation, font setup, and configuration for Fedora |
| <a href="configs/setup-scripts/setup-bashrc.sh"><code>setup-bashrc.sh</code></a> | safely installs the custom .bashrc configuration and aliases. |

### 📁 desktop-tweaks (UI customization & desktop scripts)

| File | Description |
| --- | --- |
| <a href="desktop-tweaks/konsole-white-on-black.sh"><code>konsole-white-on-black.sh</code></a> | Script to force the Konsole terminal background to solid black (#000000) with pure white text. |
| <a href="desktop-tweaks/set-login-wallpaper.sh"><code>set-login-wallpaper.sh</code></a> | Script to set a solid black background on the GDM login screen (Ubuntu's GDM). |

### 📁 maintenance (Cleanup & debloat routines)

| File | Description |
| --- | --- |
| <a href="maintenance/clean-mint.sh"><code>clean-mint.sh</code></a> | Cleanup routine for clearing out old APT packages and caches on Linux Mint. |
| <a href="maintenance/debloat-fedora-kde.sh"><code>debloat-fedora-kde.sh</code></a> | Script to remove Akonadi/PIM bloat, unused media tools, office suites, and clear caches on Fedora KDE. |
| <a href="maintenance/fedora-cleanup.sh"><code>fedora-cleanup.sh</code></a> | Full-system cleanup routine for Fedora (Caches, Orphans, Logs, KDE, Trash). |
| <a href="maintenance/system-cleanup.sh"><code>system-cleanup.sh</code></a> | Safe cleanup script for wiping temporary files and old system logs |

### 📁 provisioning (Workstation Bootstrap & Setup)

| File | Description |
| --- | --- |
| <a href="provisioning/fedora-rog-setup.sh"><code>fedora-rog-setup.sh</code></a> | Optimization and Setup Script for ASUS ROG Zephyrus G15 on Fedora  KDE |
| <a href="provisioning/setup.sh"><code>setup.sh</code></a> | Automated Linux workstation bootstrap: toolstack, repositories, debloat, scripts, terminal and desktop setup. |

### 📁 security/clamav (ClamAV antivirus setup, scans & signatures)

| File | Description |
| --- | --- |
| <a href="security/clamav/clamav-nightly-scan.service"><code>clamav-nightly-scan.service</code></a> | systemd service that runs the nightly ClamAV scan (clamav-nightly-scan.sh). |
| <a href="security/clamav/clamav-nightly-scan.sh"><code>clamav-nightly-scan.sh</code></a> | Nightly ClamAV scan of /home and system binaries, run by clamav-nightly-scan.timer. |
| <a href="security/clamav/clamav-nightly-scan.timer"><code>clamav-nightly-scan.timer</code></a> | systemd timer that runs clamav-nightly-scan.service every day at 2:00 AM. |
| <a href="security/clamav/clamsig.sh"><code>clamsig.sh</code></a> | Force a ClamAV signature update with freshclam. |
| <a href="security/clamav/setup-clamav-fedora.sh"><code>setup-clamav-fedora.sh</code></a> | Automated script to install and set up ClamAV on Fedora. |
| <a href="security/clamav/sys-scan.sh"><code>sys-scan.sh</code></a> | Manual multi-threaded ClamAV daemon scan of /home and system binaries. |

### 📁 security/hardening (OS hardening scripts per distro)

| File | Description |
| --- | --- |
| <a href="security/hardening/cachyos-hardening.sh"><code>cachyos-hardening.sh</code></a> | Hardening script to apply firewall, AppArmor, and sysctl security tweaks on CachyOS. |
| <a href="security/hardening/fedora-kde-hardening.sh"><code>fedora-kde-hardening.sh</code></a> | Automated security hardening, kernel parameter tuning, and session protection script designed for Fedora KDE. |
| <a href="security/hardening/mint-hardening.sh"><code>mint-hardening.sh</code></a> | Hardening script to disable unnecessary services, apply sysctl network/kernel protections, and enforce strict file permissions on Linux Mint. |

### 📁 security/network-tools (Port scanner & OSI security reference)

| File | Description |
| --- | --- |
| <a href="security/network-tools/osi-security-overview.sh"><code>osi-security-overview.sh</code></a> | Custom reference utility that provides a breakdown of security at each OSI layer. |
| <a href="security/network-tools/port-scanner.py"><code>port-scanner.py</code></a> | Educational multi-threaded TCP socket scanner (College Project) |

### 📁 tools (Site generator & repository tooling)

| File | Description |
| --- | --- |
| <a href="tools/apply-organization.py"><code>apply-organization.py</code></a> | This script reads the generated JSON manifest, moves and renames the script files into sanitized category subdirectories, and automatically compiles a ⁠README.md⁠ index table documenting them all. |
| <a href="tools/generate_redirects.py"><code>generate_redirects.py</code></a> | |
| <a href="tools/generate_site_config.py"><code>generate_site_config.py</code></a> | |
| <a href="tools/organize-scripts.py"><code>organize-scripts.py</code></a> | This script scans a local directory of bash scripts, uses a local LLM via LM Studio to analyze and categorize each one, and compiles the metadata into a JSON manifest file. |
| <a href="tools/update_links.sh"><code>update_links.sh</code></a> | Base GitHub Blob URL for the linux-environment-automation repository |

### 📁 updates (Full-system update routines per distro)

| File | Description |
| --- | --- |
| <a href="updates/update-arch.sh"><code>update-arch.sh</code></a> | Automated system maintenance and update script for Arch Linux and CachyOS. |
| <a href="updates/update-fedora.sh"><code>update-fedora.sh</code></a> | Automated system maintenance, backup, and upgrade script designed for Fedora KDE. |
| <a href="updates/update-mint.sh"><code>update-mint.sh</code></a> | Automated system update script for Debian/Mint handling APT, Flatpaks, and cleanups. |
| <a href="updates/update-ubuntu.sh"><code>update-ubuntu.sh</code></a> | Automated system update and maintenance script tailored for Ubuntu and Debian. |

### 📁 utils (General standalone helper scripts)

| File | Description |
| --- | --- |
| <a href="utils/create-script-template.sh"><code>create-script-template.sh</code></a> | Interactive generator that scaffolds a new, executable Bash script with standard headers and strict error handling flags. |
| <a href="utils/manage-vpn.sh"><code>manage-vpn.sh</code></a> | Quick toggle script to bring WireGuard connections up or down using WG-Quick. |
| <a href="utils/pull-script.sh"><code>pull-script.sh</code></a> | Interactively pulls and downloads an individual shell script from  a specified folder within the remote GitHub repository, then makes it executable. |
| <a href="utils/system-health-report.sh"><code>system-health-report.sh</code></a> | Diagnostic script that generates a quick report on system health, disk usage, and failed services. |
| <a href="utils/toggle-tailscale.sh"><code>toggle-tailscale.sh</code></a> | Script to easily toggle Tailscale connections, including a prompt for selecting an exit node. |
| <a href="utils/virt-remover.sh"><code>virt-remover.sh</code></a> | Interactive script to uninstall virt-manager or completely purge the KVM/libvirt virtualization stack. |
<!-- END_SECTION:tree -->
