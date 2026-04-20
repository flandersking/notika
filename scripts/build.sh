#!/usr/bin/env bash
set -euo pipefail

# Kirjo Build-Script (Debug)
# Nutze: ./scripts/build.sh

cd "$(dirname "$0")/.."

echo "⚙︎  xcodegen generate"
xcodegen generate

echo "🔨 xcodebuild Debug"
xcodebuild \
  -project Kirjo.xcodeproj \
  -scheme Kirjo \
  -configuration Debug \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  build \
  | grep -E "error:|warning:|BUILD " || true

echo "✓  Fertig."
