#!/usr/bin/env bash
set -euo pipefail

START=50
STOP=80

SCRIPT_PATH=$(readlink -f "$0")
INSTALL_DIR=$(dirname "$SCRIPT_PATH")

usage() {
  cat <<EOF
Usage: battery-saver <command> [args]

Commands:
  on                  Enable Custom $START/$STOP — battery charges only between $START%-$STOP%.
  off                 Restore Adaptive mode (Dell default, charges to ~100%).
  custom START STOP   Enable Custom mode with arbitrary thresholds.
                      START in [50,95], STOP in [55,100], STOP >= START+5.
  status              Show current charging configuration.
  doctor              Look if everything in the installation is ok.
  update              Re-download the latest scripts from the upstream repository.
  uninstall           Run the uninstaller (pass --yes to skip prompts).
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
custom)
  require_ctl
  [[ $# -eq 3 ]] || usage

  START="$2"
  STOP="$3"

  if ! [[ "$START" =~ ^[0-9]+$ && "$STOP" =~ ^[0-9]+$ ]] ||
    ((START < 50 || START > 95 || STOP < 55 || STOP > 100 || STOP < START + 5)); then
    echo "battery-saver: invalid interval $START/$STOP. START in [50,95], STOP in [55,100], STOP >= START+5." >&2
    exit 1
  fi

  sudo "$CTL" --set-custom-charge-interval=$START $STOP >/dev/null
  sudo "$CTL" --set-charging-mode=custom >/dev/null
  echo "Battery saver ON — Custom $START/$STOP active."
  sudo "$CTL" --get-charging-cfg
  ;;
status)
  require_ctl
  sudo "$CTL" --get-charging-cfg

  upower -i "$(upower -e | grep BAT)" |
    grep -E "(state|percentage|energy-rate|capacity|charge-cycles|energy-full):"
  ;;
doctor)
  fail=0

  ok() { printf '  \033[32mOK\033[0m   %s\n' "$1"; }

  bad() {
    printf '  \033[31mFAIL\033[0m %s\n' "$1"
    fail=$((fail + 1))
  }

  CTL=$(command -v smbios-battery-ctl || true)

  [[ -z "$CTL" && -x /usr/sbin/smbios-battery-ctl ]] && CTL=/usr/sbin/smbios-battery-ctl
  [[ -z "$CTL" && -x /usr/bin/smbios-battery-ctl ]] && CTL=/usr/bin/smbios-battery-ctl

  if [[ -n "$CTL" ]]; then
    ok "libsmbios installed ($CTL)"
  else
    bad "libsmbios not installed"
  fi

  if command -v upower >/dev/null; then
    ok "upower installed"
  else
    bad "upower not installed (used by status)"
  fi

  if [[ -n "$CTL" ]] && sudo "$CTL" --get-charging-cfg >/dev/null 2>&1; then
    ok "BIOS exposes charging config"
  else
    bad "BIOS does not expose charging config (try: sudo $CTL --get-charging-cfg)"
  fi

  if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    ok "$HOME/.local/bin on PATH"
  else
    bad "$HOME/.local/bin not on PATH"
  fi

  echo
  if [[ $fail -eq 0 ]]; then
    echo "All checks passed."
  else
    echo "$fail check(s) failed."
    exit 1
  fi
  ;;
update)
  INSTALL_URL="${INSTALL_URL:-https://raw.githubusercontent.com/ruliancruz/battery-saver/main/install.sh}"

  exec bash -c "curl -fsSL --max-time 60 '$INSTALL_URL' | bash"
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
