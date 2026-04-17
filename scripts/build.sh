#!/usr/bin/env bash
set -euo pipefail

# Notika Build-Script (Debug)
# Nutze: ./scripts/build.sh

cd "$(dirname "$0")/.."

echo "⚙︎  xcodegen generate"
xcodegen generate

echo "🔨 xcodebuild Debug"
xcodebuild \
  -project Notika.xcodeproj \
  -scheme Notika \
  -configuration Debug \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  build \
  | grep -E "error:|warning:|BUILD " || true

echo "✓  Fertig."
