#!/bin/bash
# What the Simulator will not tell you. Builds Orbit for the booted simulator, then reports
# what actually landed in the bundle and what the app says on its way out.
#
#   Tools/diagnose.sh            # uses the booted simulator
#   Tools/diagnose.sh "iPhone 16"
set -o pipefail
cd "$(dirname "$0")/.." || exit 1

DEVICE=${1:-booted}
BUILD_DIR=$(mktemp -d)

echo "=== Building ==="
if ! xcodebuild -project Orbit.xcodeproj -scheme Orbit \
      -destination "platform=iOS Simulator,name=${DEVICE/booted/iPhone 16}" \
      -derivedDataPath "$BUILD_DIR" -configuration Debug build 2>&1 | tail -30; then
    echo "Build failed — the output above is the real error."
    exit 1
fi

APP=$(find "$BUILD_DIR/Build/Products" -name "Orbit.app" -maxdepth 3 | head -1)
if [ -z "$APP" ]; then echo "No Orbit.app was produced."; exit 1; fi

echo
echo "=== Bundle: $APP ==="
ls -la "$APP"
echo
echo "--- executable ---"
file "$APP/Orbit" 2>&1 || echo "MISSING: the bundle has no executable"
echo
echo "--- Info.plist ---"
plutil -p "$APP/Info.plist"
echo
echo "--- extensions ---"
ls "$APP/PlugIns" 2>/dev/null || echo "(none embedded)"

echo
echo "=== Installing and launching ==="
xcrun simctl install "$DEVICE" "$APP" || { echo "Install failed."; exit 1; }
# --console-pty relays anything the app logs or crashes with, which the IDE swallows.
xcrun simctl launch --console-pty "$DEVICE" com.orbit.compass

echo
echo "=== Most recent crash report, if any ==="
CRASH=$(ls -t ~/Library/Logs/DiagnosticReports/Orbit* 2>/dev/null | head -1)
[ -n "$CRASH" ] && head -40 "$CRASH" || echo "(none)"
