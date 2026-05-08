#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/share/battery-saver"
BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/battery-saver"
BASH_COMP="$HOME/.local/share/bash-completion/completions/battery-saver"
ZSH_COMP="$HOME/.local/share/zsh/site-functions/_battery-saver"

ASSUME_YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && ASSUME_YES=1

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

confirm() {
  local prompt="$1" answer
  [[ $ASSUME_YES -eq 1 ]] && return 0
  while true; do
    read -rp "$prompt [y/n] " answer
    case "$answer" in
    y | Y) return 0 ;;
    n | N) return 1 ;;
    esac
  done
}

if [[ $EUID -eq 0 ]]; then
  red "Run this as your normal user, not root."
  exit 1
fi

# cd out of the install dir so its removal below doesn't yank our cwd.
cd /

if command -v smbios-battery-ctl >/dev/null ||
  [[ -x /usr/sbin/smbios-battery-ctl ]] ||
  [[ -x /usr/bin/smbios-battery-ctl ]]; then
  if confirm "Restore Adaptive charging mode (recommended)?"; then
    CTL=$(command -v smbios-battery-ctl ||
      ls /usr/sbin/smbios-battery-ctl /usr/bin/smbios-battery-ctl 2>/dev/null |
      head -1)
    sudo "$CTL" --set-charging-mode=adaptive >/dev/null
    green "Charging mode restored to Adaptive."
  else
    yellow "Skipped. Your BIOS will keep enforcing whatever charge mode is currently set."
  fi
else
  yellow "smbios-battery-ctl not found; skipping mode restore."
fi

for link in "$SYMLINK" "$BASH_COMP" "$ZSH_COMP"; do
  if [[ -L "$link" ]]; then
    rm -f "$link"
    green "Removed symlink $link"
  elif [[ -e "$link" ]]; then
    yellow "$link exists but isn't a symlink; leaving it alone."
  fi
done

if [[ -d "$INSTALL_DIR" ]]; then
  if confirm "Remove $INSTALL_DIR?"; then
    rm -rf "$INSTALL_DIR"
    green "Removed $INSTALL_DIR"
  else
    yellow "Skipped removing $INSTALL_DIR."
  fi
fi

if confirm "Also remove the libsmbios package?"; then
  if command -v apt >/dev/null && dpkg -l libsmbios-bin >/dev/null 2>&1; then
    sudo apt remove -y libsmbios-bin
  elif command -v dnf >/dev/null && rpm -q smbios-utils-bin >/dev/null 2>&1; then
    sudo dnf remove -y smbios-utils-bin
  elif command -v pacman >/dev/null && pacman -Q libsmbios >/dev/null 2>&1; then
    sudo pacman -R --noconfirm libsmbios
  else
    yellow "Couldn't detect a matching package; remove libsmbios manually if you want it gone."
  fi
fi

green "Done. The charge thresholds you set live on the EC, not in any file. With Adaptive restored, no laptop-side state remains."
