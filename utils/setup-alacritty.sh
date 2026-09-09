#!/bin/bash
# Automates Alacritty installation, font setup, and configuration for Fedora
# Supports --dry-run flag to preview actions without modifying the system

set -e

DRY_RUN=0
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=1
    echo "=== DRY RUN MODE ACTIVE - No changes will be made ==="
fi

# Wrapper function to intercept standard commands
run_cmd() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[DRY RUN] Would execute: $*"
    else
        "$@"
    fi
}

echo "Step 1: Installing Alacritty..."
run_cmd sudo dnf install -y alacritty

echo "Step 2: Installing JetBrains Mono Nerd Font..."
run_cmd curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
run_cmd mkdir -p ~/.local/share/fonts/JetBrainsMono
run_cmd unzip -o JetBrainsMono.zip -d ~/.local/share/fonts/JetBrainsMono
run_cmd fc-cache -fv
run_cmd rm -f JetBrainsMono.zip

echo "Step 3: Applying the Alacritty Configuration..."
run_cmd mkdir -p ~/.config/alacritty

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY RUN] Would write configuration block to: ~/.config/alacritty/alacritty.toml"
else
cat << 'EOF' > ~/.config/alacritty/alacritty.toml
# Alacritty terminal configuration
# =====================================================================
# ALACRITTY - MATTE BLACK HARDWARE INTERFACE (FULL PRO CONFIGURATION)
# =====================================================================

# --- GENERAL SETTINGS ---
# Tells Alacritty to reload changes immediately when you save this file
[general]
live_config_reload = true

[env]
TERM = "xterm-256color"

# --- WINDOW CONFIGURATION ---
[window]
padding = { x = 12, y = 12 }
decorations = "Full"        # Enables Minimize, Maximize, and Close buttons
opacity = 1.0               # Matte black look (change to 0.9 if you want slight transparency)
blur = true                 # Enables background blur if your desktop compositor supports it
startup_mode = "Windowed"   # Can be "Windowed", "Maximized", or "Fullscreen"
dynamic_title = true        # Allows running apps (like bash/nvim) to update the window title

# --- FONT CONFIGURATION ---
[font]
size = 17.0

[font.normal]
family = "JetBrainsMono Nerd Font"
style = "Regular"

[font.bold]
family = "JetBrainsMono Nerd Font"
style = "Bold"

[font.italic]
family = "JetBrainsMono Nerd Font"
style = "Italic"

[font.bold_italic]
family = "JetBrainsMono Nerd Font"
style = "Bold Italic"

# --- SCROLLBACK BUFFER ---
[scrolling]
history = 10000             # Remember 10,000 lines of terminal text scrollback
multiplier = 3              # Number of lines scrolled per mouse wheel tick

# --- CURSOR ---
[cursor]
style = { shape = "Block", blinking = "On" }
blink_interval = 750        # Blink speed in milliseconds
unfocused_hollow = true     # Turns cursor into an empty box when the window loses focus

# --- SELECTION & CLIPBOARD ---
[selection]
save_to_clipboard = true    # Automatically copy highlighted text to your clipboard

# --- MATTE BLACK COLOR SCHEME ---
[colors.primary]
background = "#121212"
foreground = "#e0e0e0"

[colors.selection]
text = "CellForeground"
background = "#282828"

[colors.normal]
black   = "#161616"
red     = "#c30010"
green   = "#90a959"
yellow  = "#f4bf75"
blue    = "#6a9fb5"
magenta = "#aa759f"
cyan    = "#75b5aa"
white   = "#e0e0e0"

[colors.bright]
black   = "#404040"
red     = "#e55555"
green   = "#aac474"
yellow  = "#feca88"
blue    = "#82b8c8"
magenta = "#c28cb8"
cyan    = "#93d3c3"
white   = "#ffffff"

# --- KEYBOARD BINDINGS ---
# Handy layout mapping for basic quality of life terminal actions
[[keyboard.bindings]]
key = "V"
mods = "Control"
action = "Paste"

[[keyboard.bindings]]
key = "C"
mods = "Control"
action = "Copy"

[[keyboard.bindings]]
key = "0"
mods = "Control"
action = "ResetFontSize"

[[keyboard.bindings]]
key = "="
mods = "Control"
action = "IncreaseFontSize"

[[keyboard.bindings]]
key = "-"
mods = "Control"
action = "DecreaseFontSize"

[[keyboard.bindings]]
key = "Enter"
mods = "Control|Shift"
action = "SpawnNewInstance"  # Opens a fresh terminal window in your current path
EOF
fi

echo "Setup Complete! Please refer to fedora-alacritty-setup-and-verification.md for final verification steps."
