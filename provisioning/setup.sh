#!/bin/bash
# Automated Linux workstation bootstrap: toolstack, repositories, debloat, scripts, terminal and desktop setup.
# Supports Fedora / RHEL-family (dnf, dnf5) and Arch-family (pacman) systems. Run with sudo.
set -uo pipefail

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
REPO_URL="https://github.com/77777kaz77777/linux-environment-automation.git"
WALLPAPER_REPO_URL="https://github.com/77777kaz77777/wallpapers.git"
INSTALL_DIR="/usr/local/bin"
LOG_FILE="/var/log/workstation-setup-$(date +%Y%m%d-%H%M%S).log"

# -----------------------------------------------------------------------------
# Logging, cleanup and result tracking
# -----------------------------------------------------------------------------
FAILURES=()
TMP_DIRS=()

log() { echo -e "$1" | tee -a "$LOG_FILE"; }
ok() { log "[✔] $1"; }
info() { log "[+] $1"; }
skip() { log "[=] $1"; }
warn() { log "[!] $1"; }
fail() {
  log "[✘] $1"
  FAILURES+=("$1")
}

cleanup() {
  local d
  for d in "${TMP_DIRS[@]}"; do rm -rf "$d"; done
}
trap cleanup EXIT

# make_tmp_dir VAR: create a temp dir, store its path in VAR, remove it on exit
make_tmp_dir() {
  local d
  d=$(mktemp -d) || return 1
  TMP_DIRS+=("$d")
  printf -v "$1" '%s' "$d"
}

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root. Re-run it with: sudo bash $0"
  exit 1
fi

REAL_USER="${SUDO_USER:-}"
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
  echo "Run this with sudo from your normal user account (not as root directly),"
  echo "so your shell, terminal and desktop settings go to the right home folder."
  exit 1
fi
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
REAL_GROUP=$(id -gn "$REAL_USER")
if [[ -z "$REAL_HOME" || ! -d "$REAL_HOME" ]]; then
  echo "Could not find the home folder for user '$REAL_USER'."
  exit 1
fi

echo "=== Workstation setup log: $(date) ===" >"$LOG_FILE"

# Run a command as the real (non-root) user, with their HOME
as_user() { sudo -u "$REAL_USER" -H "$@"; }

# -----------------------------------------------------------------------------
# System detection
# -----------------------------------------------------------------------------
DISTRO="unknown"
DISTRO_LIKE=""
OS_VERSION=""
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  DISTRO="${ID:-unknown}"
  DISTRO_LIKE="${ID_LIKE:-}"
  OS_VERSION="${VERSION_ID%%.*}"
fi

DE="generic"
if pgrep -x plasmashell >/dev/null || pgrep -x kwin_wayland >/dev/null || pgrep -x kwin_x11 >/dev/null; then
  DE="kde"
elif pgrep -x gnome-shell >/dev/null; then
  DE="gnome"
elif pgrep -f cosmic-comp >/dev/null || pgrep -f cosmic-session >/dev/null; then
  DE="cosmic"
else
  COMBINED="${XDG_CURRENT_DESKTOP:-} ${DESKTOP_SESSION:-}"
  COMBINED="${COMBINED,,}"
  case "$COMBINED" in
    *kde* | *plasma*) DE="kde" ;;
    *gnome*) DE="gnome" ;;
    *cosmic*) DE="cosmic" ;;
  esac
fi

if command -v dnf5 &>/dev/null; then
  PKG_MGR="dnf5"
elif command -v dnf &>/dev/null; then
  PKG_MGR="dnf"
elif command -v pacman &>/dev/null; then
  PKG_MGR="pacman"
else
  echo "Unsupported system: no dnf, dnf5 or pacman found."
  exit 1
fi

# -----------------------------------------------------------------------------
# Package helpers
# -----------------------------------------------------------------------------
pkg_install() {
  case "$PKG_MGR" in
    dnf5) dnf5 install -y "$@" ;;
    dnf) dnf install -y "$@" ;;
    pacman) pacman -S --needed --noconfirm "$@" ;;
  esac
}

pkg_remove() {
  case "$PKG_MGR" in
    dnf5) dnf5 remove -y "$@" ;;
    dnf) dnf remove -y "$@" ;;
    pacman) pacman -Rns --noconfirm "$@" ;;
  esac
}

pkg_installed() {
  if [[ "$PKG_MGR" == "pacman" ]]; then
    pacman -Qq "$1" &>/dev/null
  else
    rpm -q "$1" &>/dev/null
  fi
}

pkg_available() {
  case "$PKG_MGR" in
    dnf5) dnf5 -q info "$1" &>/dev/null ;;
    dnf) dnf -q info "$1" &>/dev/null ;;
    pacman) pacman -Si "$1" &>/dev/null ;;
  esac
}

# Install a list of packages: one fast batch, then one-by-one for anything that failed.
install_packages() {
  local to_install=() pkg
  for pkg in "$@"; do
    if pkg_installed "$pkg"; then
      skip "$pkg already installed"
    elif pkg_available "$pkg"; then
      to_install+=("$pkg")
    else
      fail "$pkg is not available in the configured repositories"
    fi
  done
  [[ ${#to_install[@]} -eq 0 ]] && return 0

  if pkg_install "${to_install[@]}" >>"$LOG_FILE" 2>&1; then
    ok "Installed: ${to_install[*]}"
    return 0
  fi
  warn "Batch install failed; retrying packages one at a time..."
  for pkg in "${to_install[@]}"; do
    if pkg_install "$pkg" >>"$LOG_FILE" 2>&1; then
      ok "Installed: $pkg"
    else
      fail "Could not install $pkg (see $LOG_FILE)"
    fi
  done
}

# Make sure a command exists, installing its package if needed.
require_cmd() {
  local cmd="$1" pkg="${2:-$1}"
  command -v "$cmd" &>/dev/null && return 0
  info "Installing $pkg (needed for this step)..."
  pkg_install "$pkg" >>"$LOG_FILE" 2>&1 && command -v "$cmd" &>/dev/null
}

# Set key=value inside the [main] section of an INI file, keeping everything else.
set_ini_main_key() {
  local file="$1" key="$2" value="$3"
  [[ -f "$file" ]] || printf '[main]\n' >"$file"
  grep -q '^\[main\]' "$file" || sed -i '1i [main]' "$file"
  if awk -v k="$key" '
      /^\[/ { in_main = ($0 == "[main]") }
      in_main && $0 ~ "^[[:space:]]*" k "[[:space:]]*=" { found = 1 }
      END { exit !found }' "$file"; then
    awk -v k="$key" -v v="$value" '
      /^\[/ { in_main = ($0 == "[main]") }
      in_main && $0 ~ "^[[:space:]]*" k "[[:space:]]*=" { print k "=" v; next }
      { print }' "$file" >"$file.tmp" && cat "$file.tmp" >"$file" && rm -f "$file.tmp"
  else
    sed -i "/^\[main\]/a ${key}=${value}" "$file"
  fi
}

# Add a dnf repo from a .repo URL (skipped if the repo file already exists).
add_dnf_repo() {
  local name="$1" repo_url="$2" key_url="${3:-}"
  if [[ -f "/etc/yum.repos.d/${name}.repo" ]]; then
    skip "$name repository already configured"
    return 0
  fi
  if [[ -n "$key_url" ]] && ! rpm --import "$key_url" >>"$LOG_FILE" 2>&1; then
    fail "Could not import the signing key for $name"
    return 1
  fi
  local added=1
  if [[ "$PKG_MGR" == "dnf5" ]]; then
    dnf5 config-manager addrepo --from-repofile="$repo_url" >>"$LOG_FILE" 2>&1 && added=0
  else
    dnf config-manager --add-repo "$repo_url" >>"$LOG_FILE" 2>&1 && added=0
  fi
  if [[ $added -eq 0 ]]; then ok "Added $name repository"; else fail "Could not add $name repository"; fi
  return $added
}

# -----------------------------------------------------------------------------
# Menu
# -----------------------------------------------------------------------------
if ! command -v whiptail &>/dev/null; then
  info "Installing whiptail for the menu..."
  if [[ "$PKG_MGR" == "pacman" ]]; then
    pacman -Syu --needed --noconfirm libnewt >>"$LOG_FILE" 2>&1 || true
  else
    pkg_install newt >>"$LOG_FILE" 2>&1 || true
  fi
  if ! command -v whiptail &>/dev/null; then
    echo "Could not install whiptail (package 'newt' or 'libnewt'). Install it and re-run."
    exit 1
  fi
fi

DESKTOP_DEFAULT="OFF"
[[ "$DE" == "kde" ]] && DESKTOP_DEFAULT="ON"

CHOICES=$(whiptail --title "Linux Workstation Bootstrap" \
  --backtitle "Distro: ${DISTRO^^} ${OS_VERSION} | Desktop: ${DE^^} | User: $REAL_USER | Packages: $PKG_MGR" \
  --checklist "Choose what to set up (space toggles, enter confirms):" 20 86 7 \
  "PREREQS" "Prerequisites, DNF tuning and third-party repositories" ON \
  "CORE" "Core apps (Brave, Firefox, Sublime, Podman, btop, VLC, ...)" ON \
  "DEBLOAT" "Remove preinstalled apps you don't use" ON \
  "FLATPAKS" "Flatpaks (LM Studio, Podman Desktop, Zenmap, Trayscale)" ON \
  "GITHUB" "Install scripts from linux-environment-automation" ON \
  "TERM" "Shell aliases, Konsole and Alacritty themes" ON \
  "DESKTOP" "KDE wallpaper from the wallpapers repo" "$DESKTOP_DEFAULT" \
  3>&1 1>&2 2>&3) || CHOICES=""

if [[ -z "$CHOICES" ]]; then
  log "Nothing selected. Exiting."
  exit 0
fi

selected() { [[ "$CHOICES" == *"\"$1\""* ]]; }

log "--- Starting setup on $DISTRO ($PKG_MGR, $DE) for $REAL_USER ---"

if [[ "$PKG_MGR" == "pacman" ]] && { selected PREREQS || selected CORE || selected FLATPAKS; }; then
  # Installing against a stale package database risks a partial upgrade on Arch
  info "Syncing package databases and upgrading first (pacman -Syu)..."
  pacman -Syu --noconfirm >>"$LOG_FILE" 2>&1 || warn "pacman -Syu reported errors; continuing."
fi

# -----------------------------------------------------------------------------
# 1. Prerequisites & repositories
# -----------------------------------------------------------------------------
if selected PREREQS; then
  info "Installing prerequisites..."
  if [[ "$PKG_MGR" == "pacman" ]]; then
    install_packages curl flatpak go git wget unzip fontconfig
  else
    install_packages curl flatpak golang git wget unzip fontconfig
  fi

  if [[ "$PKG_MGR" != "pacman" ]]; then
    # Tune dnf.conf without wiping existing settings
    cp -a /etc/dnf/dnf.conf "/etc/dnf/dnf.conf.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    set_ini_main_key /etc/dnf/dnf.conf gpgcheck 1
    set_ini_main_key /etc/dnf/dnf.conf installonly_limit 3
    set_ini_main_key /etc/dnf/dnf.conf clean_requirements_on_remove True
    set_ini_main_key /etc/dnf/dnf.conf max_parallel_downloads 10
    ok "Tuned /etc/dnf/dnf.conf (backup saved next to it)"

    [[ "$PKG_MGR" == "dnf" ]] && install_packages dnf-plugins-core

    case "$DISTRO" in
      centos | rocky | almalinux) TS_REPO="https://pkgs.tailscale.com/stable/centos/${OS_VERSION}/tailscale.repo" ;;
      rhel) TS_REPO="https://pkgs.tailscale.com/stable/rhel/${OS_VERSION}/tailscale.repo" ;;
      *) TS_REPO="https://pkgs.tailscale.com/stable/fedora/tailscale.repo" ;;
    esac

    add_dnf_repo brave-browser \
      https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo \
      https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
    add_dnf_repo sublime-text \
      https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo \
      https://download.sublimetext.com/sublimehq-pub.gpg
    add_dnf_repo tailscale "$TS_REPO"
  else
    skip "Arch: Brave and Sublime Text are AUR-only, so they are skipped in CORE below"
  fi
fi

# -----------------------------------------------------------------------------
# 2. Core toolstack
# -----------------------------------------------------------------------------
if selected CORE; then
  info "Installing core apps..."
  CORE_PKGS=(firefox podman btop vlc nmap fastfetch tailscale alacritty dolphin)
  if [[ "$PKG_MGR" != "pacman" ]]; then
    CORE_PKGS=(brave-origin sublime-text "${CORE_PKGS[@]}")
  fi
  [[ "$DE" == "kde" ]] && CORE_PKGS+=(spectacle)
  install_packages "${CORE_PKGS[@]}"

  if pkg_installed tailscale; then
    systemctl enable --now tailscaled >>"$LOG_FILE" 2>&1 && ok "tailscaled enabled (run 'sudo tailscale up' to log in)"
  fi
fi

# -----------------------------------------------------------------------------
# 3. Debloat
# -----------------------------------------------------------------------------
if selected DEBLOAT; then
  info "Removing unused apps for ${DE^^} on $DISTRO..."
  BLOAT=(thunderbird libreoffice-core libreoffice-writer libreoffice-calc libreoffice-impress)
  case "$DE" in
    kde) BLOAT+=(akonadi kmail kontact korganizer kaddressbook akregator pim-data-exporter kfind kleopatra kmouth ktnef
      dragon dragonplayer elisa-player kamoso kmahjongg kmines kpat krdc krfb mediawriter kdepim-addons
      kmail-account-wizard neochat kwrite pim-sieve-editor kdepim-runtime) ;;
    gnome) BLOAT+=(gnome-tour epiphany gnome-weather gnome-clocks gnome-maps totem cheese) ;;
    cosmic) BLOAT+=(totem evince gnome-calendar cheese) ;;
  esac

  TO_REMOVE=()
  for pkg in "${BLOAT[@]}"; do
    pkg_installed "$pkg" && TO_REMOVE+=("$pkg")
  done

  if [[ ${#TO_REMOVE[@]} -gt 0 ]]; then
    info "Removing ${#TO_REMOVE[@]} packages: ${TO_REMOVE[*]}"
    if pkg_remove "${TO_REMOVE[@]}" >>"$LOG_FILE" 2>&1; then
      ok "Removed ${#TO_REMOVE[@]} packages"
    else
      fail "Some packages could not be removed (see $LOG_FILE)"
    fi
  else
    skip "None of the listed apps are installed"
  fi

  case "$PKG_MGR" in
    dnf5) dnf5 autoremove -y >>"$LOG_FILE" 2>&1 || true ;;
    dnf) dnf autoremove -y >>"$LOG_FILE" 2>&1 || true ;;
    pacman)
      ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
      # shellcheck disable=SC2086
      [[ -n "$ORPHANS" ]] && pacman -Rns --noconfirm $ORPHANS >>"$LOG_FILE" 2>&1 || true
      ;;
  esac
fi

# -----------------------------------------------------------------------------
# 4. Flatpaks & Trayscale
# -----------------------------------------------------------------------------
if selected FLATPAKS; then
  info "Installing Flatpaks..."
  if require_cmd flatpak; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >>"$LOG_FILE" 2>&1 || true

    FLATPAK_NAMES=("LM Studio" "Podman Desktop" "Zenmap" "Trayscale")
    FLATPAK_IDS=(ai.lmstudio.lm-studio io.podman_desktop.PodmanDesktop org.nmap.Zenmap dev.deedles.Trayscale)
    for i in "${!FLATPAK_IDS[@]}"; do
      name="${FLATPAK_NAMES[$i]}" id="${FLATPAK_IDS[$i]}"
      if flatpak info --system "$id" &>/dev/null; then
        skip "$name already installed"
      elif flatpak install -y --noninteractive flathub "$id" >>"$LOG_FILE" 2>&1; then
        ok "$name installed"
      elif [[ "$id" == "dev.deedles.Trayscale" ]] && command -v go &>/dev/null; then
        warn "Trayscale Flatpak failed; building it with Go instead..."
        if as_user go install deedles.dev/trayscale/cmd/trayscale@latest >>"$LOG_FILE" 2>&1 &&
          install -m 755 "$REAL_HOME/go/bin/trayscale" "$INSTALL_DIR/trayscale"; then
          ok "Trayscale built and installed to $INSTALL_DIR"
        else
          fail "Could not install Trayscale"
        fi
      else
        fail "Could not install Flatpak: $name"
      fi
    done
  else
    fail "Flatpak is not available; skipped Flatpaks"
  fi
fi

# -----------------------------------------------------------------------------
# 5. Scripts from linux-environment-automation
# -----------------------------------------------------------------------------
if selected GITHUB; then
  info "Fetching scripts from linux-environment-automation..."
  if require_cmd git && make_tmp_dir REPO_TMP &&
    git clone -q --depth 1 "$REPO_URL" "$REPO_TMP" >>"$LOG_FILE" 2>&1; then

    # 5a. The 'update' command: pick the update script, preselecting the one for this distro
    case "$DISTRO $DISTRO_LIKE" in
      *fedora* | *rhel* | *centos*) SUGGESTED="update-fedora.sh" ;;
      *arch*) SUGGESTED="update-arch.sh" ;;
      *ubuntu*) SUGGESTED="update-ubuntu.sh" ;;
      *linuxmint* | *debian*) SUGGESTED="update-mint.sh" ;;
      *) SUGGESTED="" ;;
    esac
    UPDATE_ITEMS=()
    for f in "$REPO_TMP"/updates/update-*.sh; do
      [[ -f "$f" ]] || continue
      base=$(basename "$f")
      state="OFF"
      [[ "$base" == "$SUGGESTED" ]] && state="ON"
      UPDATE_ITEMS+=("$base" "$(sed -n '2s/^#[[:space:]]*//p' "$f" | cut -c1-50)" "$state")
    done
    UPDATE_ITEMS+=("SKIP" "Don't install an update command" "OFF")
    SEL=$(whiptail --title "The 'update' command" \
      --radiolist "Install which script as '$INSTALL_DIR/update'?" 16 86 6 \
      "${UPDATE_ITEMS[@]}" 3>&1 1>&2 2>&3) || SEL="SKIP"
    if [[ -n "$SEL" && "$SEL" != "SKIP" ]]; then
      install -m 755 "$REPO_TMP/updates/$SEL" "$INSTALL_DIR/update" && ok "Installed $SEL as $INSTALL_DIR/update"
      for old in /usr/local/sbin/update /usr/sbin/update; do
        [[ -e "$old" ]] && warn "An older '$old' also exists and may run instead of the new one. Remove it with: sudo rm $old"
      done
    fi

    # 5b. Tool scripts from utils/, maintenance/ and security/ (including its subfolders),
    #     installed without the .sh/.py extension
    TOOL_ITEMS=()
    for f in "$REPO_TMP"/utils/*.sh "$REPO_TMP"/utils/*.py \
      "$REPO_TMP"/maintenance/*.sh \
      "$REPO_TMP"/security/*.sh "$REPO_TMP"/security/*.py "$REPO_TMP"/security/*/*.sh; do
      [[ -f "$f" ]] || continue
      rel="${f#"$REPO_TMP"/}"
      TOOL_ITEMS+=("$rel" "$(sed -n '2s/^#[[:space:]]*//p' "$f" | cut -c1-45)" "OFF")
    done
    if [[ ${#TOOL_ITEMS[@]} -gt 0 ]]; then
      TOOLS=$(whiptail --title "Tool scripts" \
        --checklist "Install which tools into $INSTALL_DIR? (installed without the extension)" 20 96 10 \
        "${TOOL_ITEMS[@]}" 3>&1 1>&2 2>&3) || TOOLS=""
      for rel in $TOOLS; do
        rel="${rel//\"/}"
        name=$(basename "$rel")
        name="${name%.*}"
        if install -m 755 "$REPO_TMP/$rel" "$INSTALL_DIR/$name"; then
          ok "Installed $rel as $INSTALL_DIR/$name"
        else
          fail "Could not install $rel"
        fi
      done
    fi
  else
    fail "Could not download linux-environment-automation (need git and network access)"
  fi
fi

# -----------------------------------------------------------------------------
# 6. Shell aliases & terminal themes
# -----------------------------------------------------------------------------
if selected TERM; then
  info "Setting up shell aliases and terminal themes..."

  # Aliases go in ~/.bashrc.d so the existing ~/.bashrc is kept, not replaced
  BASHRC="$REAL_HOME/.bashrc"
  as_user mkdir -p "$REAL_HOME/.bashrc.d"
  cat >"$REAL_HOME/.bashrc.d/workstation-aliases.sh" <<'EOF'
# Added by linux-environment-automation provisioning/setup.sh
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
  chown "$REAL_USER:$REAL_GROUP" "$REAL_HOME/.bashrc.d/workstation-aliases.sh"

  # Fedora's default .bashrc already loads ~/.bashrc.d; add the loader once if it doesn't
  if ! grep -qs 'bashrc\.d' "$BASHRC"; then
    [[ -f "$BASHRC" ]] && cp -a "$BASHRC" "$BASHRC.bak-$(date +%Y%m%d-%H%M%S)"
    cat >>"$BASHRC" <<'EOF'

# Load extra shell config from ~/.bashrc.d (added by setup.sh)
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do [ -f "$rc" ] && . "$rc"; done
  unset rc
fi
EOF
    chown "$REAL_USER:$REAL_GROUP" "$BASHRC"
    ok "Added a ~/.bashrc.d loader to ~/.bashrc (backup saved next to it)"
  fi
  ok "Aliases installed to ~/.bashrc.d/workstation-aliases.sh"

  # Konsole: white-on-black scheme, applied to every existing profile (or a new default one)
  if [[ "$DE" == "kde" ]] || command -v konsole &>/dev/null; then
    if as_user bash -s >>"$LOG_FILE" 2>&1 <<'EOF'; then
set -e
scheme_dir="$HOME/.local/share/konsole"
mkdir -p "$scheme_dir"
cat >"$scheme_dir/PureWhiteOnBlack.colorscheme" <<'SCHEME'
[General]
Description=Pure White on Black
Opacity=1
[Background]
Color=0,0,0
[Foreground]
Color=255,255,255
SCHEME

shopt -s nullglob
profiles=("$scheme_dir"/*.profile)
if [ ${#profiles[@]} -eq 0 ]; then
  printf '[General]\nName=Default\n\n[Appearance]\nColorScheme=PureWhiteOnBlack\n' >"$scheme_dir/Default.profile"
  kw=$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)
  if [ -n "$kw" ]; then "$kw" --file konsolerc --group "Desktop Entry" --key DefaultProfile Default.profile; fi
else
  for p in "${profiles[@]}"; do
    if grep -q '^ColorScheme=' "$p"; then
      sed -i 's/^ColorScheme=.*/ColorScheme=PureWhiteOnBlack/' "$p"
    elif grep -q '^\[Appearance\]' "$p"; then
      sed -i '/^\[Appearance\]/a ColorScheme=PureWhiteOnBlack' "$p"
    else
      printf '\n[Appearance]\nColorScheme=PureWhiteOnBlack\n' >>"$p"
    fi
  done
fi
EOF
      ok "Konsole theme applied"
    else
      fail "Could not apply the Konsole theme"
    fi
  fi

  # Alacritty: JetBrainsMono Nerd Font + config (existing config is backed up)
  if as_user bash -s >>"$LOG_FILE" 2>&1 <<'EOF'; then
set -e
font_dir="$HOME/.local/share/fonts/JetBrainsMono"
if [ ! -d "$font_dir" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/JetBrainsMono.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  mkdir -p "$font_dir"
  unzip -q -o "$tmp/JetBrainsMono.zip" -d "$font_dir"
  fc-cache -f "$font_dir" || true
fi

cfg="$HOME/.config/alacritty/alacritty.toml"
mkdir -p "$(dirname "$cfg")"
[ -f "$cfg" ] && cp -a "$cfg" "$cfg.bak-$(date +%Y%m%d-%H%M%S)"
cat >"$cfg" <<'TOML'
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
TOML
EOF
    ok "Alacritty font and config applied"
  else
    fail "Could not set up Alacritty (see $LOG_FILE)"
  fi
fi

# -----------------------------------------------------------------------------
# 7. KDE wallpaper
# -----------------------------------------------------------------------------
if selected DESKTOP; then
  if [[ "$DE" != "kde" ]]; then
    skip "Wallpaper step skipped: KDE Plasma is not running"
  elif ! command -v plasma-apply-wallpaperimage &>/dev/null; then
    fail "plasma-apply-wallpaperimage not found; skipped wallpaper"
  else
    info "Fetching wallpapers..."
    if require_cmd git && make_tmp_dir WALL_TMP &&
      git clone -q --depth 1 "$WALLPAPER_REPO_URL" "$WALL_TMP" >>"$LOG_FILE" 2>&1; then
      WALL_ITEMS=()
      while IFS= read -r f; do
        WALL_ITEMS+=("${f#"$WALL_TMP"/}" "")
      done < <(find "$WALL_TMP" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -not -path '*/.git/*' | sort)

      if [[ ${#WALL_ITEMS[@]} -gt 0 ]]; then
        SEL=$(whiptail --title "Wallpaper" --menu "Pick a wallpaper:" 20 80 10 \
          "${WALL_ITEMS[@]}" 3>&1 1>&2 2>&3) || SEL=""
        if [[ -n "$SEL" ]]; then
          DEST_DIR="$REAL_HOME/Pictures/Wallpapers"
          DEST="$DEST_DIR/$(basename "$SEL")"
          as_user mkdir -p "$DEST_DIR"
          install -m 644 -o "$REAL_USER" -g "$REAL_GROUP" "$WALL_TMP/$SEL" "$DEST"
          USER_UID=$(id -u "$REAL_USER")
          if as_user env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_UID/bus" \
            plasma-apply-wallpaperimage "$DEST" >>"$LOG_FILE" 2>&1; then
            ok "Wallpaper applied: $(basename "$SEL")"
          else
            fail "Could not apply the wallpaper (it was saved to $DEST)"
          fi
        fi
      else
        skip "No images found in the wallpapers repo"
      fi
    else
      fail "Could not download the wallpapers repo"
    fi
  fi
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
chmod 644 "$LOG_FILE"
log ""
if [[ ${#FAILURES[@]} -eq 0 ]]; then
  log "--- Setup complete, no errors ---"
else
  log "--- Setup complete with ${#FAILURES[@]} problem(s): ---"
  for f in "${FAILURES[@]}"; do log "  - $f"; done
fi
log "Full log: $LOG_FILE"
echo -e "\nOpen a new terminal (or run 'source ~/.bashrc') to use the new aliases."
[[ ${#FAILURES[@]} -eq 0 ]]
