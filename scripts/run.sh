#!/usr/bin/env bash
set -euo pipefail

# Kirjo Launcher (Debug-Build aus DerivedData)
# Nutze: ./scripts/run.sh

APP_PATH=$(xcodebuild \
  -project "$(dirname "$0")/../Kirjo.xcodeproj" \
  -scheme Kirjo \
  -configuration Debug \
  -showBuildSettings 2>/dev/null \
  | awk '/ BUILT_PRODUCTS_DIR =/ {print $3}')

if [[ -z "${APP_PATH:-}" ]] || [[ ! -d "$APP_PATH/Kirjo.app" ]]; then
  echo "❌ Kirjo.app nicht gefunden. Bitte erst bauen: ./scripts/build.sh"
  exit 1
fi

# Laufende Instanz beenden (falls vorhanden)
pkill -9 -f "Kirjo.app" 2>/dev/null || true
sleep 0.5

echo "▶︎  Starte $APP_PATH/Kirjo.app"
open "$APP_PATH/Kirjo.app"
sleep 1
pgrep -lf Kirjo.app || echo "⚠︎  Prozess nicht sichtbar — siehe Console.app für Fehler."
