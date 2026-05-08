#!/usr/bin/env bash
set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/ruliancruz/battery-saver/main"
INSTALL_DIR="$HOME/.local/share/battery-saver"
BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/battery-saver"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
  red "Run this as your normal user, not root. The installer uses sudo only where needed."
  exit 1
fi

if command -v smbios-battery-ctl >/dev/null ||
  [[ -x /usr/sbin/smbios-battery-ctl ]] ||
  [[ -x /usr/bin/smbios-battery-ctl ]]; then
  green "libsmbios already installed."
else
  echo "Installing libsmbios..."
  if command -v apt >/dev/null; then
    sudo apt install -y libsmbios-bin
  elif command -v dnf >/dev/null; then
    sudo dnf install -y smbios-utils-bin
  elif command -v pacman >/dev/null; then
    sudo pacman -S --needed --noconfirm libsmbios
  else
    red "Could not detect apt, dnf, or pacman."
    red "Install libsmbios manually: https://github.com/dell/libsmbios"
    exit 1
  fi
fi

mkdir -p "$INSTALL_DIR"
# Atomic write: download to .tmp, chmod, then mv.
fetch() {
  local f="$1" mode="$2"
  echo "Downloading $f..."
  curl -fsSL "$RAW_URL/$f" -o "$INSTALL_DIR/$f.tmp"
  chmod "$mode" "$INSTALL_DIR/$f.tmp"
  mv "$INSTALL_DIR/$f.tmp" "$INSTALL_DIR/$f"
}
fetch battery-saver.sh 755
fetch uninstall.sh 755
fetch LICENSE 644
green "Installed files to $INSTALL_DIR"

mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/battery-saver.sh" "$SYMLINK"
green "Linked $SYMLINK -> $INSTALL_DIR/battery-saver.sh"

case ":$PATH:" in
*":$BIN_DIR:"*) ;;
*)
  yellow "$BIN_DIR is not on PATH. Add this to your shell rc:"
  yellow '    export PATH="$HOME/.local/bin:$PATH"'
  ;;
esac

green "Done. Run 'battery-saver' to see usage."
