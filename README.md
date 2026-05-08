# battery-saver

A small CLI to toggle Dell laptop charge thresholds between **Custom 50/80**
(battery longevity mode) and **Adaptive** (Dell default, charges to ~100%).

Holding a Li-ion cell at 100% accelerates calendar aging. Capping the upper
charge limit to 80% (with a lower bound of 50% so the EC isn't constantly
toggling) is one of the highest-impact things you can do for battery lifespan
on a desk-bound laptop. This script is just a thin wrapper around Dell's
`smbios-battery-ctl` to make that toggle a one-word command.

## Requirements

- A **Dell** laptop with BIOS support for the Primary Battery Charge
  Configuration token (Latitude, Precision, XPS, Vostro from ~2016 onward).
  Verified on a Dell Latitude 3440.
- Linux with `sudo` access.
- `libsmbios-bin` package (provides `smbios-battery-ctl`).
- `upower` (for `status` output; usually already installed on desktop
  Linux distributions).

This script does **not** work on ThinkPad, ASUS, HP, Framework, etc. Those
vendors expose charge thresholds through different mechanisms (see
[Portability](#portability) below).

## Installation

```sh
# 1. Install dependency
sudo apt install -y libsmbios-bin

# 2. Clone and install the script
git clone <this-repo> ~/code/battery-saver
mkdir -p ~/.local/bin
ln -s ~/code/battery-saver/battery-saver ~/.local/bin/battery-saver

# 3. Make sure ~/.local/bin is in PATH (most distros do this by default)
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### Optional: passwordless toggling

`smbios-battery-ctl` requires root to write to the embedded controller, so
each `battery-saver` invocation prompts for `sudo`. To skip that prompt for
this one command, install a narrow sudoers rule:

```sh
echo "$USER ALL=(root) NOPASSWD: /usr/sbin/smbios-battery-ctl" | \
    sudo tee /etc/sudoers.d/battery-saver >/dev/null
sudo chmod 0440 /etc/sudoers.d/battery-saver
sudo visudo -c -f /etc/sudoers.d/battery-saver  # validate syntax
```

This grants passwordless `sudo` for **only** `/usr/sbin/smbios-battery-ctl`.
The tool can only manipulate Dell EC battery settings — it cannot be used as
a general root escalation. Skip this step on shared/policy-managed machines.

## Usage

```sh
battery-saver on       # Enable Custom 50/80 (battery longevity mode)
battery-saver off      # Restore Adaptive mode (Dell default)
battery-saver status   # Show current charge config + battery state
```

### Typical workflow

- Daily desk use → keep `on`. Battery cycles between 50% and 80% indefinitely.
- Need full range for travel → `battery-saver off` the night before so it
  charges to 100% overnight. Re-enable on return.
- Quarterly fuel-gauge calibration → leave `off` for one full discharge cycle
  (down to ~10%, back to 100%), then re-enable.

## How the 50/80 strategy works

When `on`, the embedded controller (EC) enforces a hysteresis band:

- Battery falls below **50%** → start charging.
- Battery reaches **80%** → stop charging. Laptop runs from AC; the cell sits
  electrically parked, no float voltage stress.
- Brief unplugs that don't drop SoC below 50% will not trigger a recharge.
  This is correct behavior, not a fault.

The cell spends its life around 3.75–4.05 V per cell (Li-ion's happy zone)
instead of being held at 4.20 V (full-charge stress).

Trade-off: you give up the top 20% as daily reserve. On a battery rated for
54 Wh, that's ~11 Wh — typically 30–60 min of runtime. Override with
`battery-saver off` when you need it.

## Portability

The **strategy** (50/80 hysteresis) is universal. The **implementation** is
Dell-specific because each vendor exposes charge thresholds differently:

| Vendor       | Mechanism                                                       |
|--------------|-----------------------------------------------------------------|
| Dell         | `smbios-battery-ctl` (this script)                              |
| Lenovo       | `/sys/class/power_supply/BAT*/charge_{start,stop}_threshold`    |
| ASUS         | `/sys/class/power_supply/BAT*/charge_control_end_threshold`     |
| Framework    | `/sys/class/power_supply/BAT*/charge_control_end_threshold`     |
| HP / Acer    | Vendor-specific BIOS setting; rarely runtime-toggleable         |

For non-Dell hardware, configure the equivalent via TLP
(`START_CHARGE_THRESH_BAT0` / `STOP_CHARGE_THRESH_BAT0` in `/etc/tlp.conf`)
or write directly to the sysfs node.

## Verifying it worked

```sh
sudo smbios-battery-ctl --get-charging-cfg
# Expect: "Charging mode: custom" with interval (50, 80)

upower -i $(upower -e | grep BAT)
# When SoC ≥ 80% on AC, expect: state: not charging, energy-rate: 0 W
```

`upower` reporting `state: not charging` while plugged in at exactly 80% is
the desired steady state — the EC has stopped the charger and the laptop is
running entirely from the AC adapter.

## Troubleshooting

**`smbios-battery-ctl: Charging mode: <something else>` after `battery-saver on`**
The set-mode call may have failed silently. Re-run with verbose output:
`sudo smbios-battery-ctl -v --set-charging-mode=custom`. Some BIOS revisions
require a SETUP password — pass `--password=<pwd>` to the tool.

**Battery sits at 76% after a brief unplug, won't recharge**
Working as intended. Charging only resumes below the 50% start threshold.
Run `battery-saver off` if you need to top up immediately.

**Fuel gauge drifts (reported % feels inaccurate after months)**
Run `battery-saver off`, complete one full charge → discharge → charge cycle,
then `battery-saver on`. Recalibrates the gauge.

## License

MIT
