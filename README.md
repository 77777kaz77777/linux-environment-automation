# 🐧 linux-environment-automation

This repository serves as a centralized operations toolkit for Linux environment provisioning, continuous maintenance, and security automation. It houses a collection of Bash and Python utilities designed to streamline system administration across multiple distributions, including Fedora, Arch Linux, and Debian-based systems. By automating routine package management, enforcing system hardening policies (AppArmor, firewall, sysctl), and orchestrating scheduled antivirus scans, these tools ensure a consistent, secure, and highly optimized workstation experience.

The repository also demonstrates practical implementations of infrastructure management and workflow automation. From custom networking scripts managing VPNs like WireGuard and Tailscale to Python utilities utilizing local LLMs for automated repository organization, this collection reflects a security-first, script-driven approach to modern Linux workstation engineering.

---

## 🌳 Repository Structure

<!-- START_SECTION:tree -->
### 📁 configs (Terminal & CLI tool dotfiles)

| File | Description |
|---|---|
| <a href="source-code-reference.md#alacrittytoml"><code>alacritty.toml</code></a> | Configuration file for the Alacritty terminal emulator. |
| <a href="source-code-reference.md#dnfconf"><code>dnf.conf</code></a> | Optimized Fedora DNF package manager config tweaked for max download speeds, parallel downloads, and clean dependency management. |
| <a href="source-code-reference.md#fastfetch-laptop1-configjsonc"><code>fastfetch-laptop1-config.jsonc</code></a> | Fastfetch system info configuration for the primary laptop (ASUS ROG Zephyrus G15). |
| <a href="source-code-reference.md#fastfetch-laptop2-configjsonc"><code>fastfetch-laptop2-config.jsonc</code></a> | Fastfetch system info configuration for the secondary laptop (Lenovo ThinkPad T470). |


### 📁 configs/setup-scripts (Dotfile Deployment Scripts)

| File | Description |
|---|---|
| <a href="source-code-reference.md#setup-alacrittysh"><code>setup-alacritty.sh</code></a> | Automates Alacritty installation, font setup, and configuration for Fedora |
| <a href="source-code-reference.md#setup-bashrcsh"><code>setup-bashrc.sh</code></a> | safely installs the custom .bashrc configuration and aliases. |


### 📁 desktop-tweaks (UI customization & desktop scripts)

| File | Description |
|---|---|
| <a href="source-code-reference.md#konsole-white-on-blacksh"><code>konsole-white-on-black.sh</code></a> | Script to force the Konsole terminal background to solid black (#000000) with pure white text. |
| <a href="source-code-reference.md#set-login-wallpapersh"><code>set-login-wallpaper.sh</code></a> | Script to change and apply the display manager wallpaper. |


### 📁 desktop-tweaks/docs

| File | Description |
|---|---|
| <a href="source-code-reference.md#gnome-layout-guidetxt"><code>gnome-layout-guide.txt</code></a> | GNOME / Desktop layout modification guide |


### 📁 provisioning (Workstation Bootstrap & Setup)

| File | Description |
|---|---|
| <a href="source-code-reference.md#fedora-rog-setupsh"><code>fedora-rog-setup.sh</code></a> | Optimization and Setup Script for ASUS ROG Zephyrus G15 on Fedora 44 KDE |
| <a href="source-code-reference.md#setupsh"><code>setup.sh</code></a> | Automated Linux workstation bootstrap, toolstack installer, repository deployment, and desktop setup. |


### 📁 repo-management (LLM Metadata & Repo Organization)

| File | Description |
|---|---|
| <a href="source-code-reference.md#apply-organizationpy"><code>apply-organization.py</code></a> | This script reads the generated JSON manifest, moves and renames the script files into sanitized category subdirectories, and automatically compiles a ⁠README.md⁠ index table documenting them all. |
| <a href="source-code-reference.md#organize-scriptspy"><code>organize-scripts.py</code></a> | This script scans a local directory of bash scripts, uses a local LLM via LM Studio to analyze and categorize each one, and compiles the metadata into a JSON manifest file. |


### 📁 security (Antivirus & system defense utilities)

| File | Description |
|---|---|
| <a href="source-code-reference.md#clamav-nightly-scansh"><code>clamav-nightly-scan.sh</code></a> | ClamAV scan script designed to run nightly. |
| <a href="source-code-reference.md#clamav-scanservice"><code>clamav-scan.service</code></a> | Systemd service unit responsible for executing the nightly ClamAV scan. |
| <a href="source-code-reference.md#clamav-scantimer"><code>clamav-scan.timer</code></a> | Systemd timer unit that schedules the ClamAV scans to run at 2:00 AM |
| <a href="source-code-reference.md#fedora-kde-hardeningsh"><code>fedora-kde-hardening.sh</code></a> | Automated security hardening, kernel parameter tuning, and session protection script designed for Fedora KDE. |
| <a href="source-code-reference.md#harden-cachyossh"><code>harden-cachyos.sh</code></a> | Hardening script to apply firewall, AppArmor, and sysctl security tweaks on CachyOS. |
| <a href="source-code-reference.md#linux-mint-hardening-scriptsh"><code>linux-mint-hardening-script.sh</code></a> | Hardening script to disable unnecessary services, apply sysctl network/kernel protections, and enforce strict file permissions on Linux Mint. |
| <a href="source-code-reference.md#osi-security-overviewsh"><code>osi-security-overview.sh</code></a> | Custom reference utility that provides a breakdown of security at each OSI layer. |
| <a href="source-code-reference.md#port-scannerpy"><code>port-scanner.py</code></a> | Educational multi-threaded TCP socket scanner (College Project) |
| <a href="source-code-reference.md#run-clamav-scansh"><code>run-clamav-scan.sh</code></a> | multithreaded ClamAV daemon scan for /home and system binaries. |
| <a href="source-code-reference.md#setup-clamav-fedorash"><code>setup-clamav-fedora.sh</code></a> | Automated script to install and set up ClamAV on Fedora. |
| <a href="source-code-reference.md#update-clamav-signaturessh"><code>update-clamav-signatures.sh</code></a> | Script to manually trigger Freshclam and update antivirus signatures. |


### 📁 updates (Distro maintenance & update scripts)

| File | Description |
|---|---|
| <a href="source-code-reference.md#clean-mintsh"><code>clean-mint.sh</code></a> | Cleanup routine for clearing out old APT packages and caches on Linux Mint. |
| <a href="source-code-reference.md#debloat-fedora-kdesh"><code>debloat-fedora-kde.sh</code></a> | Script to remove Akonadi/PIM bloat, unused media tools, office suites, and clear caches on Fedora KDE. |
| <a href="source-code-reference.md#system-cleanupsh"><code>system-cleanup.sh</code></a> | Safe cleanup script for wiping temporary files and old system logs |
| <a href="source-code-reference.md#update-archsh"><code>update-arch.sh</code></a> | Automated system maintenance and update script for Arch Linux and CachyOS. |
| <a href="source-code-reference.md#update-fedora-maintenancesh"><code>update-fedora-maintenance.sh</code></a> | Full-system cleanup routine for Fedora (Caches, Orphans, Logs, KDE, Trash). |
| <a href="source-code-reference.md#update-fedorash"><code>update-fedora.sh</code></a> | Automated system maintenance, backup, and upgrade script designed for Fedora KDE. |
| <a href="source-code-reference.md#update-mintsh"><code>update-mint.sh</code></a> | Automated system update script for Debian/Mint handling APT, Flatpaks, and cleanups. |
| <a href="source-code-reference.md#update-ubuntush"><code>update-ubuntu.sh</code></a> | Automated system update and maintenance script tailored for Ubuntu and Debian. |


### 📁 utils (General standalone helper scripts)

| File | Description |
|---|---|
| <a href="source-code-reference.md#create-script-templatesh"><code>create-script-template.sh</code></a> | Interactive generator that scaffolds a new, executable Bash script with standard headers and strict error handling flags. |
| <a href="source-code-reference.md#manage-vpnsh"><code>manage-vpn.sh</code></a> | Quick toggle script to bring WireGuard connections up or down using WG-Quick. |
| <a href="source-code-reference.md#pull-scriptsh"><code>pull-script.sh</code></a> | Interactively pulls and downloads an individual shell script from  a specified folder within the remote GitHub repository, then makes it executable. |
| <a href="source-code-reference.md#system-health-reportsh"><code>system-health-report.sh</code></a> | Diagnostic script that generates a quick report on system health, disk usage, and failed services. |
| <a href="source-code-reference.md#toggle-tailscalesh"><code>toggle-tailscale.sh</code></a> | Script to easily toggle Tailscale connections, including a prompt for selecting an exit node. |
| <a href="source-code-reference.md#virt-removersh"><code>virt-remover.sh</code></a> | Interactive script to uninstall virt-manager or completely purge the KVM/libvirt virtualization stack. |
<!-- END_SECTION:tree -->
