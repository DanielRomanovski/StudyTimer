#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP="$ROOT/dist/StudyTimer.app"

cd "$ROOT"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/StudyTimer "$APP/Contents/MacOS/StudyTimer"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
printf 'Built %s\n' "$APP"