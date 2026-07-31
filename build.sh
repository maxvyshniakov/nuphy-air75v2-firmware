#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$PROJECT_DIR/.work/qmk-firmware"
DIST_DIR="$PROJECT_DIR/dist"
UPSTREAM_URL="https://github.com/ryodeushii/qmk-firmware.git"
UPSTREAM_COMMIT="81c0300bc721884933ab3e77d76cba69416b8cdf"
QMK_IMAGE="qmkfm/qmk_cli@sha256:b7d7fa8fb4432b569931de5ad59098cb788f440ed61a62c5126746b71aee0f4a"
OUTPUT_NAME="nuphy-air75v2-host-indicators.bin"
DOCKER_BIN="$(command -v docker || true)"

if [[ -z "$DOCKER_BIN" ]] || ! "$DOCKER_BIN" info >/dev/null 2>&1; then
  echo "Docker Desktop is not running" >&2
  exit 1
fi

mkdir -p "$(dirname "$WORK_DIR")" "$DIST_DIR"
if [[ ! -d "$WORK_DIR/.git" ]]; then
  git clone --filter=blob:none "$UPSTREAM_URL" "$WORK_DIR"
fi

git -C "$WORK_DIR" fetch origin "$UPSTREAM_COMMIT"
git -C "$WORK_DIR" checkout --detach "$UPSTREAM_COMMIT"
git -C "$WORK_DIR" reset --hard "$UPSTREAM_COMMIT"
git -C "$WORK_DIR" clean -fdx
git -C "$WORK_DIR" submodule update --init --depth 1 \
  lib/chibios \
  lib/chibios-contrib \
  lib/lufa
git -C "$WORK_DIR" apply --recount "$PROJECT_DIR/patches/host-key-indicators.patch"
git -C "$WORK_DIR" apply --recount "$PROJECT_DIR/patches/rgb-calibration.patch"
git -C "$WORK_DIR" apply --recount "$PROJECT_DIR/patches/audio-meter.patch"

"$DOCKER_BIN" run --rm \
  -v "$WORK_DIR:/qmk_firmware" \
  "$QMK_IMAGE" \
  bash -lc \
  'set -o pipefail; /opt/uv/tools/qmk/bin/python3 -m pip install -q -r /qmk_firmware/requirements.txt && /opt/uv/tools/qmk/bin/qmk compile -kb nuphy/air75v2/ansi -km ryodeushii 2>&1 | tail -n 40'

install -m 0644 \
  "$WORK_DIR/nuphy_air75v2_ansi_ryodeushii.bin" \
  "$DIST_DIR/$OUTPUT_NAME"
shasum -a 256 "$DIST_DIR/$OUTPUT_NAME" >"$DIST_DIR/$OUTPUT_NAME.sha256"

echo "Built $DIST_DIR/$OUTPUT_NAME"
