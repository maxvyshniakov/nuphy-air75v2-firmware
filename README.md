# NuPhy Air75 V2 host indicators

Private, reproducible firmware extension for the NuPhy Air75 V2 used by
Wintermute on macOS.

The project stays pinned to ryodeushii's `ryo-1.1.4` release commit
`81c0300bc721884933ab3e77d76cba69416b8cdf` and carries the local behavior as a
small patch instead of copying the full QMK repository.

## Host indicator protocol

The patch adds volatile VIA custom value `40` on channel `0`. Its four-byte
payload is `[red, green, blue, musicPlaying]`.

- Caps Lock is always rendered at full RGB intensity using the host-provided
  input-language color.
- F8 uses the same color only while macOS reports active media playback.
- The ordinary Caps Lock indicator is suppressed after the host protocol is
  activated, so it cannot flash the firmware's cyan over the language color.
- Nothing is written to the keyboard EEPROM. A keyboard reboot clears the
  overlay until the Wintermute agent reapplies it.

Matrix positions come from the pinned Air75 V2 definition: Caps Lock is
`(3, 0)` and F8 is `(0, 8)`.

## Build

Docker Desktop must already be running.

```sh
./build.sh
```

The script clones the pinned upstream source into `.work/`, initializes its QMK
submodules, applies `patches/host-key-indicators.patch`, and builds the
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

## Upstream

- Source: https://github.com/ryodeushii/qmk-firmware
- Release: https://github.com/ryodeushii/qmk-firmware/releases/tag/ryo-1.1.4
- License: GPL-2.0 and the additional licenses included by upstream.
