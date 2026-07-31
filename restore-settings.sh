#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTROL_AGENT="/Users/maxvishnyakov/mac2mqtt/control-agent"
SERVICE="com.local.wintermute-control-agent"
PLIST="/Users/maxvishnyakov/Library/LaunchAgents/${SERVICE}.plist"
DOMAIN="gui/$(id -u)"
INPUT="${1:-$BASE_DIR/backups/air75v2-via-settings.json}"
AGENT_WAS_RUNNING=0

restart_agent() {
  if [[ "$AGENT_WAS_RUNNING" == "1" ]]; then
    launchctl bootstrap "$DOMAIN" "$PLIST"
  fi
}
trap restart_agent EXIT

if [[ ! -f "$INPUT" ]]; then
  echo "Backup not found: $INPUT" >&2
  exit 1
fi
if [[ -f "$INPUT.sha256" ]]; then
  (
    cd "$(dirname "$INPUT")"
    shasum -a 256 -c "$(basename "$INPUT").sha256"
  )
fi

if launchctl print "$DOMAIN/$SERVICE" >/dev/null 2>&1; then
  AGENT_WAS_RUNNING=1
  launchctl bootout "$DOMAIN/$SERVICE"
fi

"$CONTROL_AGENT" --restore-nuphy-via "$INPUT"
