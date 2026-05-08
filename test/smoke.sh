#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-/repo}"
TESTER="${TESTER:-tester}"
INSTALL_DIR="/home/$TESTER/.local/share/battery-saver"
SYMLINK="/home/$TESTER/.local/bin/battery-saver"
BASH_COMP="/home/$TESTER/.local/share/bash-completion/completions/battery-saver"
ZSH_COMP="/home/$TESTER/.local/share/zsh/site-functions/_battery-saver"
TARBALL="/tmp/battery-saver.tar.gz"

red() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }
ok() { printf '\033[32mPASS: %s\033[0m\n' "$*"; }

cat >/usr/local/bin/smbios-battery-ctl <<'EOF'
#!/usr/bin/env bash
echo "mock smbios-battery-ctl: $*" >>/tmp/smbios.log
EOF
chmod 755 /usr/local/bin/smbios-battery-ctl

# Pack working tree to mimic GitHub's tarball layout (top-level dir wrapper).
staging=$(mktemp -d)
cp -r "$REPO" "$staging/battery-saver-main"
tar czf "$TARBALL" -C "$staging" battery-saver-main
chmod 644 "$TARBALL"

run_as_tester() {
  sudo -u "$TESTER" \
    env "TARBALL_URL=file://$TARBALL" "HOME=/home/$TESTER" "PATH=/usr/local/bin:/usr/bin:/bin" \
    bash "$@"
}

echo "=== install (first run) ==="
run_as_tester "$REPO/install.sh"

[[ -f "$INSTALL_DIR/battery-saver.sh" ]] || red "battery-saver.sh missing"
[[ -f "$INSTALL_DIR/uninstall.sh" ]] || red "uninstall.sh missing"
[[ -f "$INSTALL_DIR/LICENSE" ]] || red "LICENSE missing"
[[ "$(stat -c '%a' "$INSTALL_DIR/battery-saver.sh")" == "755" ]] || red "battery-saver.sh mode"
[[ "$(stat -c '%a' "$INSTALL_DIR/uninstall.sh")" == "755" ]] || red "uninstall.sh mode"
[[ "$(stat -c '%a' "$INSTALL_DIR/LICENSE")" == "644" ]] || red "LICENSE mode"
[[ -f "$INSTALL_DIR/completions/battery-saver.bash" ]] || red "bash completion missing"
[[ -f "$INSTALL_DIR/completions/_battery-saver" ]] || red "zsh completion missing"
[[ -L "$SYMLINK" ]] || red "symlink missing"
[[ "$(readlink "$SYMLINK")" == "$INSTALL_DIR/battery-saver.sh" ]] || red "symlink target wrong"
[[ -L "$BASH_COMP" ]] || red "bash completion symlink missing"
[[ -L "$ZSH_COMP" ]] || red "zsh completion symlink missing"
ok "files installed with correct modes and symlinks"

echo "=== install (idempotent re-run) ==="
out=$(run_as_tester "$REPO/install.sh")
echo "$out"
echo "$out" | grep -q "Already up to date" || red "expected 'Already up to date' on re-run"
ok "re-run reports Already up to date"

echo "=== uninstall ==="
run_as_tester "$INSTALL_DIR/uninstall.sh" --yes

[[ -e "$SYMLINK" ]] && red "symlink should be gone"
[[ -e "$BASH_COMP" ]] && red "bash completion symlink should be gone"
[[ -e "$ZSH_COMP" ]] && red "zsh completion symlink should be gone"
[[ -d "$INSTALL_DIR" ]] && red "install dir should be gone"
ok "uninstall cleaned up"

ok "all smoke checks passed"
