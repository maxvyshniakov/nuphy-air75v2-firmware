#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIRMWARE="$PROJECT_DIR/dist/nuphy-air75v2-host-indicators.bin"
QMK_TOOLBOX_DFU_UTIL="/Applications/QMK Toolbox.app/Contents/Resources/dfu-util"
if [[ -z "${DFU_UTIL:-}" ]]; then
  if [[ -x "$QMK_TOOLBOX_DFU_UTIL" ]]; then
    DFU_UTIL="$QMK_TOOLBOX_DFU_UTIL"
  else
    DFU_UTIL="$(command -v dfu-util || true)"
  fi
fi

if [[ ! -f "$FIRMWARE" ]]; then
  echo "Build the firmware first with ./build.sh" >&2
  exit 1
fi
if [[ -z "$DFU_UTIL" || ! -x "$DFU_UTIL" ]]; then
  echo "dfu-util not found; install QMK Toolbox or dfu-util, or set DFU_UTIL" >&2
  exit 1
fi
if ! "$DFU_UTIL" -l 2>&1 | grep -qi 'Found DFU: \[0483:df11\]'; then
  echo "Air75 V2 is not in STM32 DFU mode." >&2
  echo "Hold Esc while reconnecting USB, then run ./flash.sh again." >&2
  exit 1
fi

"$DFU_UTIL" \
  -d 0483:DF11 \
  -a 0 \
  -s 0x08000000:leave \
  -D "$FIRMWARE"
