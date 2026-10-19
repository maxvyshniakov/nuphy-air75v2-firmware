# NuPhy Air75 V2 host-driven firmware

Firmware extensions for the [NuPhy Air75 V2](https://nuphy.com/products/air75-v2)
that let a computer drive the keyboard's lighting at runtime: per-key status
indicators, smooth brightness control, white-balance calibration and a stereo
audio meter on the side lights.

The project is a small set of patches on top of
[ryodeushii's QMK fork](https://github.com/ryodeushii/qmk-firmware), pinned to
the `ryo-1.1.4` release commit `81c0300bc721884933ab3e77d76cba69416b8cdf`.
It does not copy the QMK tree; `build.sh` fetches the pinned source, applies
the patches and compiles in a pinned QMK container, so builds are reproducible.

All host commands go through standard VIA custom values over Raw HID, so the
keyboard stays fully compatible with VIA. The host side is a separate macOS
agent (Wintermute Control) that is not part of this repository; any program
that speaks the VIA protocol can use the commands below.

> [!WARNING]
> Flashing custom firmware is at your own risk. Keep the bundled recovery
> image (see [Recovery](#recovery)) at hand before flashing anything.

## Features

- **Host indicators.** Caps Lock always shows the current input-language
  color at full intensity. F6 (Focus), F8 (Play/Pause) and Mute light up in
  their own colors while the host reports Focus mode, media playback or mute.
  The physical F6 and Mute keys toggle their overlay immediately; the host then
  reconciles it with the real system state.
- **Brightness protocol.** The host sets a target brightness and a transition
  time; the fade runs on the keyboard. A newer target replaces the one in
  flight, so rapid changes never queue up. Physical brightness keys interrupt a
  host transition and use a finer step of `8` instead of upstream's `26`.
- **White-balance calibration.** The calibrated `100/50/50` white point is
  baked into the matrix output stage, so the host starts from a true
  `100/100/100` neutral. Independent volatile chromatic balance is available
  for the key matrix and the side lights, applied after effects and overlays
  and normalized back to each pixel's peak, so white is corrected without
  dimming saturated colors. A test mode switches either group to solid white,
  red, green or blue for calibrating.
- **Side-light audio meter.** Left and right levels map onto the six LEDs of
  each side strip with a dim partial segment, instant attack and a fast
  release. Peak modes add a one-segment marker with a 160 ms hold. Both bars
  grow in the same visual direction, and the language color stays visible
  behind them. Battery, RF, system and calibration overlays keep priority.
- **Side-light fixes.** The WS2812 waveform uses explicit short and long delay
  sequences, preserving the known-good timing of the Ryo release on newer GCC
  versions (which otherwise leave the strip stuck on boot white). Both side
  lights default to Static mode with a custom color, and Ryo's white Mac-mode
  confirmation is suppressed once the host protocol is active. Ryo's cyan Caps
  Lock side indicator, battery and low-power indicators remain available.

Nothing is written to EEPROM. Rebooting the keyboard clears every host overlay
and calibration value until the host applies them again.

## Host protocol

All commands use VIA custom values on channel `0`.

| Value | Payload | Purpose |
| --- | --- | --- |
| `40` | `[red, green, blue, musicPlaying]` | Caps Lock language color and media state |
| `41` | `[target0To190, transitionMilliseconds, 0xB1]` | Matrix brightness with on-device transition |
| `45` | `[red, green, blue]` | F8 Play/Pause indicator color |
| `46` | `[red, green, blue, active]` | F6 Focus indicator |
| `47` | `[red, green, blue, active]` | Mute indicator |
| `48` | `[leftLevel, rightLevel, active, 0xA8]` | Stereo audio meter levels |
| `49` | `[red, green, blue, 0xA9]` | Audio meter color |
| `50` | `[mode, 0, 0, 0xAA]` | Audio meter mode: `0` Bar, `1` Peak, `2` Bar + Peak |

Reading value `41` returns `[current0To190, target0To190, maximumBrightness, 0xB1]`.
The marker and maximum let a host tell this firmware apart from the stock one
and fall back to standard VIA brightness.

Default indicator colors follow the physical key order: Focus/F6 `#00aaff`,
Play/Pause/F8 `#aaff00`, Mute `#ff0024`.

Matrix positions come from the pinned Air75 V2 definition: Caps Lock `(3, 0)`,
F6 `(0, 6)`, F8 `(0, 8)`, Mute `(0, 10)`.

## Build

Requires Docker.

```sh
./build.sh
```

The script clones the pinned upstream source into `.work/`, initializes the
required QMK submodules, applies the patches from `patches/` and builds the
`nuphy/air75v2/ansi:ryodeushii` target. The firmware and its SHA-256 checksum
are written to `dist/`.

| Patch | Adds |
| --- | --- |
| `host-key-indicators.patch` | Host indicators and brightness protocol |
| `rgb-calibration.patch` | White balance, calibration and side-light timing |
| `audio-meter.patch` | Side-light audio meter |

## Flash

Put the keyboard in wired mode, hold Esc while reconnecting the USB cable and
check that it shows up as the STM32 DFU device `0483:df11`. Then run:

```sh
./flash.sh
```

The script uses the `dfu-util` bundled with
[QMK Toolbox](https://github.com/qmk/qmk_toolbox), or `dfu-util` from `PATH`,
or the binary set in `DFU_UTIL`. It addresses only `0483:df11`, never another
DFU device attached to the computer.

## Recovery

`recovery/air75v2-via-ryo-1.1.4.bin` is the unmodified upstream `ryo-1.1.4`
VIA release, with its checksum next to it. Flash it the same way to return to
known-good firmware:

```sh
dfu-util -d 0483:DF11 -a 0 -s 0x08000000:leave -D recovery/air75v2-via-ryo-1.1.4.bin
```

## Settings backup

VIA's layout export misses most lighting and Ryo settings. The backup scripts
capture and restore the full persistent state: all eight keymap layers, the
macro buffer, layout options, RGB matrix settings, both side-light
configurations, debounce and sleep values, and indicator settings.

They call the host agent, which owns the Raw HID connection. Close VIA first,
then run:

```sh
./backup-settings.sh   # writes backups/air75v2-via-settings.json and a checksum
./restore-settings.sh  # writes the snapshot back and verifies it by reading
```

Restoring does not require DFU mode. Both scripts stop the agent's launchd
service for the duration so it cannot race the backup, and start it again
afterwards. Override the defaults with `CONTROL_AGENT`,
`CONTROL_AGENT_SERVICE` and `CONTROL_AGENT_PLIST` if the agent lives elsewhere.

`backups/` holds the author's own snapshot as an example of the format.

## License

GPL-2.0, like the upstream QMK firmware, plus the additional licenses included
by upstream. See [LICENSE](LICENSE).

Based on [ryodeushii/qmk-firmware](https://github.com/ryodeushii/qmk-firmware),
release [`ryo-1.1.4`](https://github.com/ryodeushii/qmk-firmware/releases/tag/ryo-1.1.4).
