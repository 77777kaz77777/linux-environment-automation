#!/bin/bash
#  Automated Linux workstation bootstrap, toolstack installer, repository deployment, and desktop setup.

set -o pipefail

LOG_FILE="workstation_install.log"

if [[ "$EUID" -ne 0 ]]; then
  echo "Privilege Error: This script must be run as root (sudo). Please relaunch with elevated privileges."
  exit 1
fi

echo "=== Bash Workstation Installation Log ===" >"$LOG_FILE"

log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# --- System Manager (OS, DE, Package Manager Detection) ---
DISTRO="unknown"
OS_VERSION="9"
OS_CODENAME="bullseye"

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  DISTRO="${ID:-unknown}"
  OS_VERSION="${VERSION_ID%%.*}"
  OS_CODENAME="${VERSION_CODENAME:-unknown}"
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# Detect Desktop Environment
DE="generic"
if pgrep -i plasmashell >/dev/null || pgrep -i kwin_wayland >/dev/null || pgrep -i kwin_x11 >/dev/null; then
  DE="kde"
elif pgrep -i gnome-shell >/dev/null; then
  DE="gnome"
elif pgrep -i cinnamon >/dev/null; then
  DE="cinnamon"
elif pgrep -i cosmic-comp >/dev/null || pgrep -i cosmic-session >/dev/null; then
  DE="cosmic"
else
  COMBINED="${XDG_CURRENT_DESKTOP,,} ${DESKTOP_SESSION,,}"
  if [[ "$COMBINED" == *"kde"* || "$COMBINED" == *"plasma"* ]]; then
    DE="kde"
  elif [[ "$COMBINED" == *"gnome"* ]]; then
    DE="gnome"
  elif [[ "$COMBINED" == *"cinnamon"* ]]; then
    DE="cinnamon"
  elif [[ "$COMBINED" == *"cosmic"* ]]; then
    DE="cosmic"
  fi
fi

# Detect Package Manager
if command -v dnf5 &>/dev/null; then
  PKG_MGR="dnf5"
  INSTALL_CMD="dnf5 install -y"
  REMOVE_CMD="dnf5 remove -y"
  UPDATE_CMD="dnf5 update -y"
elif command -v dnf &>/dev/null; then
  PKG_MGR="dnf4"
  INSTALL_CMD="dnf install -y"
  REMOVE_CMD="dnf remove -y"
  UPDATE_CMD="dnf update -y"
elif command -v apt-get &>/dev/null; then
  PKG_MGR="apt"
  INSTALL_CMD="DEBIAN_FRONTEND=noninteractive apt-get install -y"
  REMOVE_CMD="DEBIAN_FRONTEND=noninteractive apt-get remove -y"
  UPDATE_CMD="apt-get update -y"
elif command -v pacman &>/dev/null; then
  PKG_MGR="pacman"
  INSTALL_CMD="pacman -S --needed --noconfirm"
  REMOVE_CMD="pacman -Rns --noconfirm"
  UPDATE_CMD="pacman -Sy"
elif command -v zypper &>/dev/null; then
  PKG_MGR="zypper"
  INSTALL_CMD="zypper in -y"
  REMOVE_CMD="zypper rm -y"
  UPDATE_CMD="zypper ref"
else
  log "[✘] Error: Unsupported package manager."
  exit 1
fi

# Ensure whiptail is installed for the TUI
if ! command -v whiptail &>/dev/null; then
  log "[+] Installing newt/whiptail for interactive UI..."
  $INSTALL_CMD newt || $INSTALL_CMD whiptail || true
fi

# --- TUI Selection Menu ---
CHOICES=$(whiptail --title "Linux Workstation Bootstrap Installer" \
  --backtitle "Distro: ${DISTRO^^} | Desktop: ${DE^^} | User: $REAL_USER | PM: $PKG_MGR" \
  --checklist "Select Installation Options:" 22 85 7 \
  "PREREQS" "Install Prerequisites & Repositories" ON \
  "CORE" "Install Core Toolstack (Brave, Sublime, Podman, Dolphin, etc.)" ON \
  "DEBLOAT" "Execute Distro/DE Debloat Routine" ON \
  "FLATPAKS" "Install Flatpaks (LM Studio, Podman Desktop, Zenmap)" ON \
  "GITHUB" "Clone & Install GitHub Maintenance Scripts" ON \
  "TERM" "Configure Shell Aliases & Terminal Theme" ON \
  "DESKTOP" "Configure KDE Wallpaper (from Repo)" ON \
  3>&1 1>&2 2>&3)

if [[ -z "$CHOICES" ]]; then
  log "Installation cancelled by user."
  exit 0
fi

log "--- Starting Installation Sequence ---"

# --- 1. Prerequisites & Repositories ---
if [[ "$CHOICES" == *"PREREQS"* ]]; then
  log "[+] Installing system prerequisites..."
  if [[ "$PKG_MGR" == "pacman" ]]; then
    $INSTALL_CMD curl flatpak go git wget unzip || log "[!] Warning: Some prerequisites failed to install."
  else
    $INSTALL_CMD curl flatpak golang git wget unzip || log "[!] Warning: Some prerequisites failed to install."
  fi

  if [[ "$PKG_MGR" == "dnf4" || "$PKG_MGR" == "dnf5" ]]; then
    cat <<EOF >/etc/dnf/dnf.conf
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=true
best=False
skip_if_unavailable=True
max_parallel_downloads=10
fastestmirror=True
EOF
    log "[✔] Applied optimized DNF configuration."

    if [[ "$DISTRO" == "centos" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
      TS_REPO="https://pkgs.tailscale.com/stable/centos/$OS_VERSION/tailscale.repo"
    elif [[ "$DISTRO" == "rhel" ]]; then
      TS_REPO="https://pkgs.tailscale.com/stable/rhel/$OS_VERSION/tailscale.repo"
    else
      TS_REPO="https://pkgs.tailscale.com/stable/fedora/tailscale.repo"
    fi

    if [[ "$PKG_MGR" == "dnf5" ]]; then
      [[ ! -f /etc/yum.repos.d/brave-browser.repo ]] && dnf5 config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo && rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc || true
      [[ ! -f /etc/yum.repos.d/sublime-text.repo ]] && rpm --import https://download.sublimetext.com/sublimehq-pub.gpg && dnf5 config-manager addrepo --from-repofile=https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo || true
      [[ ! -f /etc/yum.repos.d/tailscale.repo ]] && dnf5 config-manager addrepo --from-repofile="$TS_REPO" || true
      log "[✔] Configured DNF5 repositories."
    else
      $INSTALL_CMD dnf-plugins-core || true
      [[ ! -f /etc/yum.repos.d/brave-browser.repo ]] && dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo && rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc || true
      [[ ! -f /etc/yum.repos.d/sublime-text.repo ]] && rpm --import https://download.sublimetext.com/sublimehq-pub.gpg && dnf config-manager --add-repo https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo || true
      [[ ! -f /etc/yum.repos.d/tailscale.repo ]] && dnf config-manager --add-repo "$TS_REPO" || true
      log "[✔] Configured DNF4 repositories."
    fi

  elif [[ "$PKG_MGR" == "apt" ]]; then
    log "Configuring APT repositories..."
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg || true
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" >/etc/apt/sources.list.d/brave-browser-release.list

    wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor -o /usr/share/keyrings/sublimehq-archive-keyring.gpg || true
    echo "deb [signed-by=/usr/share/keyrings/sublimehq-archive-keyring.gpg] https://download.sublimetext.com/ apt/stable/" >/etc/apt/sources.list.d/sublime-text.list

    [[ "$DISTRO" == *"ubuntu"* ]] && OS_ID="ubuntu" || OS_ID="debian"
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/bullseye.noarmor.gpg" | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null || true
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/$OS_ID $OS_CODENAME main" >/etc/apt/sources.list.d/tailscale.list
    $UPDATE_CMD || log "[!] Warning: APT update encountered errors."
  fi
fi

# --- 2. Core Toolstack ---
if [[ "$CHOICES" == *"CORE"* ]]; then
  log "[+] Installing core toolstack..."
  if [[ "$PKG_MGR" == "apt" ]]; then
    BRAVE_PKG="brave-browser"
  else
    BRAVE_PKG="brave-origin"
  fi

  CORE_PKGS=("$BRAVE_PKG" "firefox" "sublime-text" "podman" "virt-manager" "btop" "vlc" "nmap" "fastfetch" "tailscale" "alacritty" "dolphin")
  if [[ "$DE" == "kde" ]]; then
    [[ "$PKG_MGR" != "apt" ]] && CORE_PKGS+=("spectacle") || CORE_PKGS+=("kde-spectacle")
  fi

  for pkg in "${CORE_PKGS[@]}"; do
    $INSTALL_CMD "$pkg" && log "[✔] Installed: $pkg" || log "[✘] Failed to install: $pkg"
  done
fi

# --- 3. Debloat Routine ---
if [[ "$CHOICES" == *"DEBLOAT"* ]]; then
  log "[+] Executing tailored debloat for ${DE^^} on $DISTRO..."
  BLOAT=("thunderbird" "libreoffice-core" "libreoffice-writer" "libreoffice-calc" "libreoffice-impress")

  [[ "$DE" == "kde" ]] && BLOAT+=("akonadi" "kmail" "kontact" "korganizer" "kaddressbook" "akregator" "pim-data-exporter" "kfind" "kleopatra" "kmouth" "ktnef" "dragon" "dragonplayer" "elisa-player" "kamoso" "kmahjongg" "kmines" "kpat" "krdc" "krfb" "fedora-media-writer" "kdepim-addons" "kmail-account-wizard" "neochat" "kwrite" "pim-sieve-editor" "kdepim-runtime")
  [[ "$DE" == "gnome" ]] && BLOAT+=("gnome-tour" "epiphany-browser" "gnome-weather" "gnome-clocks" "gnome-maps" "totem" "cheese")
  [[ "$DE" == "cosmic" ]] && BLOAT+=("totem" "evince" "gnome-calendar" "cheese")
  [[ "$DE" == "cinnamon" ]] && BLOAT+=("rhythmbox" "totem" "hexchat")
  [[ "$PKG_MGR" == "apt" ]] && BLOAT+=("snapd" "gnome-software-plugin-snap")

  VALID_REMOVE=()
  for pkg in "${BLOAT[@]}"; do
    if [[ "$PKG_MGR" =~ ^(dnf4|dnf5|zypper)$ ]] && rpm -q "$pkg" &>/dev/null; then
      VALID_REMOVE+=("$pkg")
    elif [[ "$PKG_MGR" == "apt" ]] && dpkg -l "$pkg" &>/dev/null; then
      VALID_REMOVE+=("$pkg")
    elif [[ "$PKG_MGR" == "pacman" ]] && pacman -Qq "$pkg" &>/dev/null; then
      VALID_REMOVE+=("$pkg")
    fi
  done

  if [[ ${#VALID_REMOVE[@]} -gt 0 ]]; then
    log "[*] Removing (${#VALID_REMOVE[@]}) confirmed installed packages: ${VALID_REMOVE[*]}"
    $REMOVE_CMD "${VALID_REMOVE[@]}" || log "[!] Warning: Debloat removal encountered errors."
  else
    log "[=] No matching bloatware packages found."
  fi

  [[ "$PKG_MGR" == "dnf5" ]] && (dnf5 autoremove -y && dnf5 clean all || true)
  [[ "$PKG_MGR" == "dnf4" ]] && (dnf autoremove -y && dnf clean all || true)
  [[ "$PKG_MGR" == "apt" ]] && (apt-get autoremove -y && apt-get clean || true)
  [[ "$PKG_MGR" == "pacman" ]] && (pacman -Sc --noconfirm || true)
fi

# --- 4. Flatpaks & Trayscale ---
if [[ "$CHOICES" == *"FLATPAKS"* ]]; then
  log "[+] Installing Flatpaks & Trayscale..."
  if command -v flatpak &>/dev/null; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

    declare -A FLATS=(["LM Studio"]="ai.lmstudio.lm-studio" ["Podman Desktop"]="io.podman_desktop.PodmanDesktop" ["Zenmap"]="org.nmap.Zenmap")
    for name in "${!FLATS[@]}"; do
      if ! flatpak list | grep -qi "${FLATS[$name]}"; then
        flatpak install -y flathub "${FLATS[$name]}" && log "[✔] $name installed" || log "[✘] Failed to install Flatpak: $name"
      else
        log "[=] $name already installed."
      fi
    done

    if ! command -v trayscale &>/dev/null && ! flatpak list | grep -qi "dev.deedles.Trayscale"; then
      if ! flatpak install -y flathub dev.deedles.Trayscale; then
        if command -v go &>/dev/null; then
          su - "$REAL_USER" -c 'go install deedles.dev/trayscale/cmd/trayscale@latest' || true
          if [[ -f "$REAL_HOME/go/bin/trayscale" ]]; then
            cp "$REAL_HOME/go/bin/trayscale" /usr/local/bin/trayscale && chmod +x /usr/local/bin/trayscale
            log "[✔] Trayscale (Go Build) installed"
          fi
        fi
      fi
    fi
  fi
fi

# --- 5. GitHub Scripts ---
if [[ "$CHOICES" == *"GITHUB"* ]]; then
  log "[+] Deploying GitHub maintenance scripts..."
  if command -v git &>/dev/null; then
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT
    if git clone --depth 1 "https://github.com/77777kaz77777/linux-environment-automation.git" "$TMP_DIR"; then

      if [[ -d "$TMP_DIR/updates" ]]; then
        SCRIPTS=()
        for f in "$TMP_DIR/updates"/*; do
          [[ -f "$f" ]] && SCRIPTS+=("$(basename "$f")" "")
        done
        if [[ ${#SCRIPTS[@]} -gt 0 ]]; then
          SCRIPTS+=("SKIP" "Do not install")
          SEL=$(whiptail --title "Update Script" --menu "Select a script to install:" 15 60 6 "${SCRIPTS[@]}" 3>&1 1>&2 2>&3)
          if [[ -n "$SEL" && "$SEL" != "SKIP" ]]; then
            cp "$TMP_DIR/updates/$SEL" /usr/local/bin/update && chmod 755 /usr/local/bin/update
            log "[✔] Installed '$SEL' to /usr/local/bin/update"
          fi
        fi
      fi

      ROOT_SCRIPTS=()
      for f in "$TMP_DIR"/*; do
        [[ -f "$f" ]] && ROOT_SCRIPTS+=("$(basename "$f")" "")
      done
      if [[ ${#ROOT_SCRIPTS[@]} -gt 0 ]]; then
        ROOT_SCRIPTS+=("ALL" "Install everything" "SKIP" "Do not install")
        SEL=$(whiptail --title "Tool Scripts" --menu "Select script to install:" 15 60 6 "${ROOT_SCRIPTS[@]}" 3>&1 1>&2 2>&3)
        if [[ "$SEL" == "ALL" ]]; then
          for f in "$TMP_DIR"/*; do
            if [[ -f "$f" ]]; then
              base=$(basename "$f")
              cp "$f" "/usr/local/bin/${base%.*}" && chmod 755 "/usr/local/bin/${base%.*}"
            fi
          done
          log "[✔] Installed ALL tool scripts"
        elif [[ -n "$SEL" && "$SEL" != "SKIP" ]]; then
          cp "$TMP_DIR/$SEL" "/usr/local/bin/${SEL%.*}" && chmod 755 "/usr/local/bin/${SEL%.*}"
          log "[✔] Installed tool script '$SEL'"
        fi
      fi
    fi
    rm -rf "$TMP_DIR"
    trap - EXIT
  fi
fi

# --- 6. Terminal & Aliases ---
if [[ "$CHOICES" == *"TERM"* ]]; then
  log "[+] Configuring Shell Aliases, Konsole, and Alacritty Themes..."

  BASHRC_PATH="$REAL_HOME/.bashrc"
  [[ -f "$BASHRC_PATH" ]] && cp "$BASHRC_PATH" "$BASHRC_PATH.bak" && chown "$REAL_USER:$REAL_USER" "$BASHRC_PATH.bak" || true

  cat <<'EOF' >"$BASHRC_PATH"
# .bashrc
if [ -f /etc/bashrc ]; then . /etc/bashrc; fi
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then PATH="$HOME/.local/bin:$HOME/bin:$PATH"; fi
export PATH

if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do [ -f "$rc" ] && . "$rc"; done
fi
unset rc

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias c='clear'
alias u='sudo update'
alias g='ssh -T git@github.com'
alias s='sudo shutdown now'
export PS1="\u@\h:\w\$ "
EOF
  chown "$REAL_USER:$REAL_USER" "$BASHRC_PATH" || true

  KONSOLE_SH="/tmp/setup_konsole.sh"
  cat <<'EOF' >"$KONSOLE_SH"
#!/bin/bash
printf '\033]10;#FFFFFF\007'
printf '\033]11;#000000\007'

scheme_dir="${HOME}/.local/share/konsole"
scheme_file="${scheme_dir}/PureWhiteOnBlack.colorscheme"
mkdir -p "${scheme_dir}"

cat << 'INNER_EOF' > "${scheme_file}"
[General]
Description=Pure White on Black
Opacity=1
[Background]
Color=0,0,0
[Foreground]
Color=255,255,255
INNER_EOF

default_profile="${scheme_dir}/Profile 1.profile"
if [[ -f "${default_profile}" ]]; then
    if grep -q "^ColorScheme=" "${default_profile}"; then
        sed -i 's/^ColorScheme=.*/ColorScheme=PureWhiteOnBlack/' "${default_profile}"
    else
        echo "ColorScheme=PureWhiteOnBlack" >> "${default_profile}"
    fi
fi
EOF
  chmod +x "$KONSOLE_SH"
  su - "$REAL_USER" -c "bash $KONSOLE_SH" || log "[!] Failed to apply Konsole config."
  rm -f "$KONSOLE_SH"

  ALACRITTY_SH="/tmp/setup_alacritty.sh"
  cat <<'EOF' >"$ALACRITTY_SH"
#!/bin/bash
if [ ! -d "$HOME/.local/share/fonts/JetBrainsMono" ]; then
    curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    mkdir -p ~/.local/share/fonts/JetBrainsMono
    unzip -q -o JetBrainsMono.zip -d ~/.local/share/fonts/JetBrainsMono || true
    fc-cache -fv || true
    rm -f JetBrainsMono.zip
fi
mkdir -p ~/.config/alacritty
cat << 'INNER_EOF' > ~/.config/alacritty/alacritty.toml
[general]
live_config_reload = true
[window]
padding = { x = 12, y = 12 }
decorations = "Full"
opacity = 1.0
blur = true
[font.normal]
family = "JetBrainsMono Nerd Font"
style = "Regular"
[colors.primary]
background = "#121212"
foreground = "#e0e0e0"
INNER_EOF
EOF
  chmod +x "$ALACRITTY_SH"
  su - "$REAL_USER" -c "bash $ALACRITTY_SH" || log "[!] Failed to apply Alacritty config."
  rm -f "$ALACRITTY_SH"

  log "[✔] Terminal configuration deployed."
fi

# --- 7. KDE Plasma Desktop Setup ---
if [[ "$CHOICES" == *"DESKTOP"* ]]; then
  if [[ "$DE" == "kde" ]]; then
    log "[+] Configuring KDE Plasma Wallpaper..."

    WALL_TMP=$(mktemp -d)
    trap 'rm -rf "$WALL_TMP"' EXIT
    log "[+] Cloning wallpaper repository..."
    if git clone --depth 1 "https://github.com/77777kaz77777/wallpapers.git" "$WALL_TMP"; then
      WALL_FILES=()
      while IFS= read -r f; do
        [[ -n "$f" ]] && WALL_FILES+=("$(basename "$f")" "")
      done < <(find "$WALL_TMP" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \))

      if [[ ${#WALL_FILES[@]} -gt 0 ]]; then
        SELECTED_WALL=$(whiptail --title "Wallpaper Selection" --menu "Select a wallpaper to apply:" 18 70 8 "${WALL_FILES[@]}" 3>&1 1>&2 2>&3)

        if [[ -n "$SELECTED_WALL" ]]; then
          TARGET_WALL_PATH="$REAL_HOME/Pictures/Wallpapers/$SELECTED_WALL"
          mkdir -p "$REAL_HOME/Pictures/Wallpapers"

          FOUND_FILE=$(find "$WALL_TMP" -name "$SELECTED_WALL" -print -quit)
          if [[ -n "$FOUND_FILE" ]]; then
            cp "$FOUND_FILE" "$TARGET_WALL_PATH"
            chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/Pictures/Wallpapers"

            USER_UID=$(id -u "$REAL_USER")
            DBUS_ENV="export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_UID/bus;"

            su - "$REAL_USER" -c "$DBUS_ENV plasma-apply-wallpaperimage \"$TARGET_WALL_PATH\"" && log "[✔] Applied wallpaper: $SELECTED_WALL" || log "[✘] DBus failed to set wallpaper."
          fi
        fi
      else
        log "[-] No wallpaper images found in repository."
      fi
    fi
    rm -rf "$WALL_TMP"
    trap - EXIT
  else
    log "[!] Desktop setup skipped: System is not running KDE Plasma."
  fi
fi

log "\n--- Installation Sequence Complete ---"
log "Log saved to $(realpath "$LOG_FILE")"
echo -e "\nSetup finished. Please run 'source ~/.bashrc' or open a new terminal to apply alias changes."
