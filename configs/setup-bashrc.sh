# This script safely installs the custom .bashrc configuration and aliases.

#!/usr/bin/env bash
# Description: Terminal configuration and custom bash aliases


TARGET="$HOME/.bashrc"

if [ -f "$TARGET" ]; then
    echo "Backing up existing .bashrc to ~/.bashrc.bak..."
    cp "$TARGET" "$HOME/.bashrc.bak"
fi

cat << 'EOF' > "$TARGET"
# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias c='clear'
alias u='sudo update'
alias g='ssh -T git@github.com'
alias s='sudo shutdown now'
export PS1="\u@\h:\w\$ "
EOF

echo ".bashrc has been successfully updated and configured."
