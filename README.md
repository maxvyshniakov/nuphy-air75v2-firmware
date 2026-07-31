# NuPhy Air75 V2 host indicators

Private, reproducible firmware extension for the NuPhy Air75 V2 used by
Wintermute on macOS.

The project stays pinned to ryodeushii's `ryo-1.1.4` release commit
`81c0300bc721884933ab3e77d76cba69416b8cdf` and carries the local behavior as a
small patch instead of copying the full QMK repository.

## Host protocols

The patch adds volatile VIA custom values on channel `0`:

- `40` controls per-key host indicators with payload
  `[red, green, blue, musicPlaying]`.
- `41` sets native matrix brightness with payload
  `[target0To190, transitionMilliseconds, 0xB1]`.
- `45` sets the independent F8 Play/Pause indicator color with payload
  `[red, green, blue]`.
- `46` controls the F6 Focus indicator with payload
  `[red, green, blue, active]`.
- `47` controls the Mute-key indicator with payload
  `[red, green, blue, active]`.

Reading value `41` returns
`[current0To190, target0To190, maximumBrightness, 0xB1]`. The marker and
maximum let the macOS agent distinguish this extension from the unmodified
firmware and fall back to standard VIA brightness automatically.

- Caps Lock is always rendered at full RGB intensity using the host-provided
  input-language color.
- F8 uses its separately configurable color only while macOS reports active
  media playback.
- F6 and Mute each use an independent configurable color and are rendered only
  while macOS reports the corresponding state as active. Their physical keys
  also toggle the local overlay immediately; the agent then reconciles it with
  the system state.
- The baked indicator defaults follow the physical order: Focus/F6 `#00aaff`,
  Play–Pause/F8 `#aaff00`, and Mute `#ff0024`.
- Ryo's cyan left-side Caps Lock indicator remains available, independently
  from the always-visible input-language color under the Caps Lock key.
- Ryo's white Mac-mode side-light confirmation is suppressed after the host
  protocol is activated, so it cannot cover the input-language color. Battery
  and low-power indicators remain available.
- Nothing is written to the keyboard EEPROM. A keyboard reboot clears the
  overlay until the Wintermute agent reapplies it.
- Brightness transitions run on the keyboard. A newer target replaces the
  in-flight target immediately, so rapid changes never accumulate in a queue.
- Physical brightness keys interrupt an in-flight host transition and use a
  finer step of `8` instead of upstream's `26`.

## White-balance calibration

The firmware bakes the calibrated `100/50/50` white point into the main key
matrix output stage. The host-facing calibration therefore starts at a genuine
`100/100/100` Neutral instead of exposing the keyboard's hardware correction as
a user setting. It also exposes independent volatile chromatic balance for the
main key matrix and side lights. Calibration is applied after effects and
indicator overlays, then normalized back to the source pixel's peak value. This
corrects white without dimming pure saturated colors or clipping mixed colors.
Wintermute Control presents the underlying red-versus-cyan ratio as one
`Cool ↔ Warm` slider per hardware group and can switch both groups to white,
red, green, or blue test output. The test color keeps the normal matrix and
side-light brightness paths active, so host brightness following remains
visible while calibrating. Values stay out of EEPROM while tuning; rebooting
the keyboard restores neutral balance and turns the test output off.

The side-light WS2812 waveform uses explicit short and long delay sequences.
This preserves the timing of the known-good Ryo release even with newer GCC
versions whose different loop-unrolling otherwise makes the strip reject every
frame and remain boot-white.

Both side lights default to Static mode with custom color enabled. Wintermute
reapplies the active macOS input-language color at agent startup, keyboard
reconnect, and every input-source change.

Host value `48` carries `[leftLevel, rightLevel, active, 0xA8]` for the stereo
audio meter; value `49` carries its `[red, green, blue, 0xA9]` overlay color;
value `50` carries `[mode, 0, 0, 0xAA]`, where `0` is Bar, `1` is Peak, and
`2` is Bar + Peak.
The firmware maps each channel onto its six individually
addressable side LEDs, supports a dim partial segment, applies immediate attack
and a fast release suited to beat pulses. Peak modes add a one-segment marker
with a 160 ms hold and a slightly slower fall. The right strip is rendered in
the opposite physical direction so both bars grow the same way. The ordinary language color remains visible as the
background while active meter segments use the separately calibrated host color;
when input becomes inactive or stale, the overlay disappears. Battery, RF, system, and
calibration overlays retain higher priority.

Matrix positions come from the pinned Air75 V2 definition: Caps Lock is
`(3, 0)`, Focus/F6 is `(0, 6)`, F8 is `(0, 8)`, and Mute is `(0, 10)`.

## Build

Docker Desktop must already be running.

```sh
./build.sh
```

The script clones the pinned upstream source into `.work/`, initializes its QMK
submodules, applies the host-indicator, RGB-calibration, and audio-meter patches, and builds the
`nuphy/air75v2/ansi:ryodeushii` target in a pinned QMK container. The resulting
firmware and SHA-256 checksum are written to `dist/`.

## Flash

Put the keyboard in wired mode, hold Esc while reconnecting its USB cable, and
confirm that it appears as `0483:df11`. Then run:

```sh
./flash.sh
```

The script uses the `dfu-util` bundled with QMK Toolbox and addresses only the
STM32 DFU device, not any other runtime DFU interface on the Mac.

The untouched upstream `air75v2-via-ryo-1.1.4.bin` is kept in `recovery/` so
the known-good release remains available before any local firmware is flashed.

## Settings backup

VIA's layout export does not include the complete lighting and Ryo settings.
After configuring the keyboard, close VIA so it stops using Raw HID, then
capture the full persistent state with:

```sh
./backup-settings.sh
```

This stores the eight-layer keymap, macro buffer, layout options, RGB matrix
settings, both side-light configurations, debounce/sleep values, and indicator
settings in `backups/air75v2-via-settings.json`, alongside a SHA-256 checksum.
The script temporarily stops the Wintermute agent so it cannot race VIA on the
Raw HID interface, then starts it again.

Restore and read-back-verify the snapshot without entering DFU mode:

```sh
./restore-settings.sh
```

## Upstream

- Source: https://github.com/ryodeushii/qmk-firmware
- Release: https://github.com/ryodeushii/qmk-firmware/releases/tag/ryo-1.1.4
- License: GPL-2.0 and the additional licenses included by upstream.
