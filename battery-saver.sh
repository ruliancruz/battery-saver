#!/usr/bin/env bash
# Toggle Dell charge thresholds (Custom 50/80 vs Adaptive).
# Requires libsmbios. Uses sudo for EC writes.

set -euo pipefail

START=50
STOP=80

# Resolve the install directory (works whether invoked directly or via symlink).
SCRIPT_PATH=$(readlink -f "$0")
INSTALL_DIR=$(dirname "$SCRIPT_PATH")

usage() {
  cat <<EOF
Usage: battery-saver <command>

Commands:
  on         Enable Custom $START/$STOP — battery charges only between $START%-$STOP%.
  off        Restore Adaptive mode (Dell default, charges to ~100%).
  status     Show current charging configuration.
  update     Pull the latest version from the upstream repo.
  uninstall  Run the uninstaller (pass --yes to skip prompts).
EOF
  exit 1
}

require_ctl() {
  CTL=$(command -v smbios-battery-ctl || true)
  [[ -z "$CTL" && -x /usr/sbin/smbios-battery-ctl ]] && CTL=/usr/sbin/smbios-battery-ctl
  [[ -z "$CTL" && -x /usr/bin/smbios-battery-ctl ]] && CTL=/usr/bin/smbios-battery-ctl
  if [[ -z "$CTL" ]]; then
    echo "battery-saver: smbios-battery-ctl not found. Install libsmbios." >&2
    exit 127
  fi
}

[[ $# -ge 1 ]] || usage

case "$1" in
on)
  require_ctl
  sudo "$CTL" --set-custom-charge-interval=$START $STOP >/dev/null
  sudo "$CTL" --set-charging-mode=custom >/dev/null
  echo "Battery saver ON — Custom $START/$STOP active."
  sudo "$CTL" --get-charging-cfg
  ;;
off)
  require_ctl
  sudo "$CTL" --set-charging-mode=adaptive >/dev/null
  echo "Battery saver OFF — Adaptive mode restored."
  sudo "$CTL" --get-charging-cfg
  ;;
status)
  require_ctl
  sudo "$CTL" --get-charging-cfg
  upower -i "$(upower -e | grep BAT)" | grep -E "state|percentage|energy-rate"
  ;;
update)
  if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    echo "battery-saver: $INSTALL_DIR is not a git checkout; can't update." >&2
    echo "Re-run the installer to repair: " \
         "curl -fsSL https://raw.githubusercontent.com/ruliancruz/battery-saver/main/install.sh | bash" >&2
    exit 1
  fi
  git -C "$INSTALL_DIR" pull --ff-only
  ;;
uninstall)
  shift
  if [[ ! -x "$INSTALL_DIR/uninstall.sh" ]]; then
    echo "battery-saver: uninstall.sh not found at $INSTALL_DIR." >&2
    exit 1
  fi
  exec bash "$INSTALL_DIR/uninstall.sh" "$@"
  ;;
*)
  usage
  ;;
esac
