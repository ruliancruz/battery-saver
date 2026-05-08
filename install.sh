#!/usr/bin/env bash
# Installer for battery-saver.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ruliancruz/battery-saver/main/install.sh | bash
#   # or, after cloning anywhere:
#   bash install.sh
#
# Idempotent: safe to re-run to update an existing install.

set -euo pipefail

REPO_URL="https://github.com/ruliancruz/battery-saver.git"
INSTALL_DIR="$HOME/.local/share/battery-saver"
BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/battery-saver"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
    red "Run this as your normal user, not root. The installer uses sudo only where needed."
    exit 1
fi

# 1. Install libsmbios if smbios-battery-ctl is not already on the system.
if command -v smbios-battery-ctl >/dev/null \
   || [[ -x /usr/sbin/smbios-battery-ctl ]] \
   || [[ -x /usr/bin/smbios-battery-ctl ]]; then
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

# 2. Clone (or update) the repo at the XDG data directory.
if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Updating existing clone at $INSTALL_DIR..."
    git -C "$INSTALL_DIR" pull --ff-only
elif [[ -e "$INSTALL_DIR" ]]; then
    red "$INSTALL_DIR exists but is not a git repository."
    red "Move or remove it and re-run the installer."
    exit 1
else
    echo "Cloning into $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# 3. Symlink the script onto PATH.
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/battery-saver.sh" "$SYMLINK"
green "Linked $SYMLINK -> $INSTALL_DIR/battery-saver.sh"

# 4. Warn if ~/.local/bin is not on PATH.
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        yellow "$BIN_DIR is not on PATH. Add this to your shell rc:"
        yellow '    export PATH="$HOME/.local/bin:$PATH"'
        ;;
esac

green "Done. Run 'battery-saver' to see usage."
