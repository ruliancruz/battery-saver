_battery_saver() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ $COMP_CWORD -eq 1 ]]; then
    mapfile -t COMPREPLY < <(compgen -W "on off custom status doctor update uninstall" -- "$cur")
  fi
}
complete -F _battery_saver battery-saver
