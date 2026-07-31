#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTROL_AGENT="/Users/maxvishnyakov/mac2mqtt/control-agent"
SERVICE="com.local.wintermute-control-agent"
PLIST="/Users/maxvishnyakov/Library/LaunchAgents/${SERVICE}.plist"
DOMAIN="gui/$(id -u)"
OUTPUT="${1:-$BASE_DIR/backups/air75v2-via-settings.json}"
AGENT_WAS_RUNNING=0

restart_agent() {
  if [[ "$AGENT_WAS_RUNNING" == "1" ]]; then
    launchctl bootstrap "$DOMAIN" "$PLIST"
  fi
}
trap restart_agent EXIT

if launchctl print "$DOMAIN/$SERVICE" >/dev/null 2>&1; then
  AGENT_WAS_RUNNING=1
  launchctl bootout "$DOMAIN/$SERVICE"
fi

mkdir -p "$(dirname "$OUTPUT")"
"$CONTROL_AGENT" --backup-nuphy-via "$OUTPUT"
(
  cd "$(dirname "$OUTPUT")"
  shasum -a 256 "$(basename "$OUTPUT")" >"$(basename "$OUTPUT").sha256"
)

echo "Backup: $OUTPUT"
echo "Checksum: $OUTPUT.sha256"
