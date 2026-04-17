#!/usr/bin/env bash
set -euo pipefail

# Notika Launcher (Debug-Build aus DerivedData)
# Nutze: ./scripts/run.sh

APP_PATH=$(xcodebuild \
  -project "$(dirname "$0")/../Notika.xcodeproj" \
  -scheme Notika \
  -configuration Debug \
  -showBuildSettings 2>/dev/null \
  | awk '/ BUILT_PRODUCTS_DIR =/ {print $3}')

if [[ -z "${APP_PATH:-}" ]] || [[ ! -d "$APP_PATH/Notika.app" ]]; then
  echo "❌ Notika.app nicht gefunden. Bitte erst bauen: ./scripts/build.sh"
  exit 1
fi

# Laufende Instanz beenden (falls vorhanden)
pkill -9 -f "Notika.app" 2>/dev/null || true
sleep 0.5

echo "▶︎  Starte $APP_PATH/Notika.app"
open "$APP_PATH/Notika.app"
sleep 1
pgrep -lf Notika.app || echo "⚠︎  Prozess nicht sichtbar — siehe Console.app für Fehler."
