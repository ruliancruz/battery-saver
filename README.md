# battery-saver

Toggle Dell laptop charge thresholds between **Custom 50/80** (battery
longevity mode) and **Adaptive** (Dell default, charges to ~100%).

Lithium-ion cells age faster when held at full charge. Capping the upper
limit at 80%, with a 50% lower bound so the EC (Embedded Controller) isn't
flipping on and off every few minutes, buys you a noticeable amount of
extra battery life on a laptop that mostly sits on a desk. From
[Battery University BU-808](https://batteryuniversity.com/article/bu-808-how-to-prolong-lithium-based-batteries):
"every reduction in peak charge voltage of 0.10V/cell is said to double the
cycle life."

This script wraps Dell's `smbios-battery-ctl` so flipping the setting is a
one-word command.

## Requirements

- A **Dell** laptop with BIOS support for the Primary Battery Charge
  Configuration token (Latitude, Precision, XPS, Vostro from ~2016 onward).
  Verified on a Dell Latitude 3440.
- Linux with `sudo` access.
- [`libsmbios`](https://github.com/dell/libsmbios) (provides the
  `smbios-battery-ctl` binary).
- `upower` (used by `battery-saver status`; preinstalled on most desktop
  distros).

## Installation

### Quick install

One command, handles everything (libsmbios, clone, symlink):

```sh
curl -fsSL https://raw.githubusercontent.com/ruliancruz/battery-saver/main/install.sh | bash
```

If you'd rather inspect the script first (recommended for any
`curl | bash`):

```sh
curl -fsSL https://raw.githubusercontent.com/ruliancruz/battery-saver/main/install.sh -o install.sh
less install.sh
bash install.sh
```

To update later, run `battery-saver update`. The installer is also
idempotent if you'd rather re-run it instead.

### Manual install

If you prefer doing it by hand, follow the three steps below.

#### 1. Install libsmbios

Pick the line for your package manager.

##### `apt`

```sh
sudo apt install -y libsmbios-bin
```

##### `dnf`

```sh
sudo dnf install -y smbios-utils-bin
```

##### `pacman`

```sh
sudo pacman -S libsmbios
```

If none of these match, you can also build it from source:
[dell/libsmbios on GitHub](https://github.com/dell/libsmbios).

```sh
command -v smbios-battery-ctl
```

Debian-family distros put it in `/usr/sbin`; Arch and Fedora use `/usr/bin`.
The script handles both.

#### 2. Clone and install the script

Clone into `~/.local/share/` so the install doesn't depend on your dev
checkout location, then symlink the script onto PATH.

```sh
git clone https://github.com/ruliancruz/battery-saver.git ~/.local/share/battery-saver
mkdir -p ~/.local/bin
ln -sf ~/.local/share/battery-saver/battery-saver.sh ~/.local/bin/battery-saver
```

`~/.local/share/` is the standard
[XDG data directory](https://specifications.freedesktop.org/basedir-spec/latest/)
for user-level application files; the symlink in `~/.local/bin/` is what
makes `battery-saver` runnable as a command. To update later, just
`git pull` inside `~/.local/share/battery-saver`.

#### 3. Make sure `~/.local/bin` is on PATH

Most distros add it for you. Check with:

```sh
command -v battery-saver
```

If nothing prints, add it. For bash:

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

For zsh use `~/.zshrc`.

## Usage

```sh
battery-saver on          # Enable Custom 50/80 (battery longevity mode)
battery-saver off         # Restore Adaptive mode (Dell default)
battery-saver status      # Show current charge config + battery state
battery-saver update      # git pull the latest version from upstream
battery-saver uninstall   # Run the uninstaller (--yes to skip prompts)
```

### Typical workflow

- Daily desk use → keep `on`. Battery cycles between 50% and 80% indefinitely.
- Need full range for travel → `battery-saver off` the night before so it
  charges to 100% overnight. Re-enable on return.
- Quarterly fuel-gauge calibration → leave `off` for one full discharge cycle
  (down to ~10%, back to 100%), then re-enable.

## How the 50/80 strategy works

With `battery-saver on`, the
[embedded controller](https://en.wikipedia.org/wiki/Embedded_controller)
(EC) keeps the battery inside a hysteresis band:

- Below **50%** → start charging.
- At **80%** → stop charging. Laptop runs from AC; the cell sits idle, not
  held at float voltage.
- A brief unplug that doesn't drop SoC under 50% won't trigger a recharge
  on plug-in. That's correct, not a fault.

The cell spends its life around 3.75–4.05 V instead of being parked at
4.20 V.
[This matters because](https://batteryuniversity.com/article/bu-808b-what-causes-li-ion-to-die)
above 4.10 V/cell, electrolyte oxidation attacks
the cathode, and "the longer the battery stays in a high voltage, the
faster the degradation occurs."

You give up the top 20% as everyday reserve. On a 54 Wh battery that's
about 11 Wh, usually 30–60 minutes of runtime depending on workload. Run
`battery-saver off` whenever you actually need the full range.

The 50/80 idea applies to any Li-ion laptop battery. The Dell-specific part
is how you enforce it: this script talks to Dell's BIOS/EC through
`smbios-battery-ctl`.

Other vendors expose charge thresholds through different paths
(sysfs nodes, vendor tools, BIOS-only settings), so the same approach works on
them with a different command.

## Verifying it worked

```sh
sudo smbios-battery-ctl --get-charging-cfg
# Expect: "Charging mode: custom" with interval (50, 80)

upower -i "$(upower -e | grep BAT)"
# When SoC ≥ 80% on AC, expect: state: not charging, energy-rate: 0 W
```

Seeing `state: not charging` while plugged in at 80% means it's working.
The EC has cut the charger and the laptop is drawing entirely from the AC
adapter.

## Troubleshooting

### `smbios-battery-ctl: Charging mode: <something else>` after `battery-saver on`

The set-mode call may have failed silently.

Re-run with verbose output: `sudo smbios-battery-ctl -v --set-charging-mode=custom`.

Some BIOS revisions require a SETUP password; pass `--password=<pwd>` to
the tool.

### Battery sits at 51~79% after a brief unplug, won't recharge

Working as intended. Charging only resumes below the 50% start threshold.
Run `battery-saver off` if you need to top up immediately.

### Fuel gauge drifts (reported % feels inaccurate after months)

Run `battery-saver off`, complete one full discharge → charge cycle, then
`battery-saver on`. That recalibrates the gauge.

## Uninstall

### Quick uninstall

```sh
battery-saver uninstall
```

The uninstaller prompts before each destructive step (restoring Adaptive
mode, removing the install directory, removing `libsmbios`). Pass `--yes`
to skip the prompts for non-interactive use.

### Manual uninstall

If you'd rather do it by hand:

```sh
battery-saver off                       # restore Adaptive mode on the EC
rm ~/.local/bin/battery-saver           # remove the symlink
rm -rf ~/.local/share/battery-saver     # remove the clone
```

If you also want to remove `libsmbios`:

```sh
sudo apt remove libsmbios-bin     # apt
sudo dnf remove smbios-utils-bin  # dnf
sudo pacman -R libsmbios          # pacman
```

The charge thresholds you configured live on the EC, not in any file. Once
Adaptive mode is restored, no laptop-side state is left behind.

## License

[MIT](LICENSE)
