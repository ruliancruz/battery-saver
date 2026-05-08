#!/usr/bin/env bash
set -euo pipefail

START=50
STOP=80

SCRIPT_PATH=$(readlink -f "$0")
INSTALL_DIR=$(dirname "$SCRIPT_PATH")

usage() {
  cat <<EOF
Usage: battery-saver <command>

Commands:
  on         Enable Custom $START/$STOP — battery charges only between $START%-$STOP%.
  off        Restore Adaptive mode (Dell default, charges to ~100%).
  status     Show current charging configuration.
  update     Re-download the latest scripts from the upstream repo.
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
  RAW_URL="https://raw.githubusercontent.com/ruliancruz/battery-saver/main"
  fetch() {
    local f="$1" mode="$2"
    echo "Fetching $f..."
    curl -fsSL "$RAW_URL/$f" -o "$INSTALL_DIR/$f.tmp"
    chmod "$mode" "$INSTALL_DIR/$f.tmp"
    mv "$INSTALL_DIR/$f.tmp" "$INSTALL_DIR/$f"
  }
  fetch battery-saver.sh 755
  fetch uninstall.sh 755
  fetch LICENSE 644
  echo "Updated."
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
