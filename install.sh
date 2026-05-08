#!/usr/bin/env bash
set -euo pipefail

TARBALL_URL="https://codeload.github.com/ruliancruz/battery-saver/tar.gz/refs/heads/main"
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
echo "Downloading battery-saver..."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --max-time 60 "$TARBALL_URL" | tar xz -C "$tmp" --strip-components=1
install -m 755 "$tmp/battery-saver.sh" "$INSTALL_DIR/battery-saver.sh"
install -m 755 "$tmp/uninstall.sh" "$INSTALL_DIR/uninstall.sh"
install -m 644 "$tmp/LICENSE" "$INSTALL_DIR/LICENSE"
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
