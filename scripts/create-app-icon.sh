#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SOURCE="$ROOT/assets/StudyTimer.png"
OUTPUT="${1:?Usage: create-app-icon.sh output.icns}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

width="$(sips -g pixelWidth "$SOURCE" | awk '/pixelWidth/ {print $2}')"
height="$(sips -g pixelHeight "$SOURCE" | awk '/pixelHeight/ {print $2}')"
side="$width"
if [ "$height" -lt "$width" ]; then side="$height"; fi
left="$(((width - side) / 2))"
top="$(((height - side) / 2))"
ICONSET="$WORK_DIR/StudyTimer.iconset"
mkdir -p "$ICONSET" "$(dirname -- "$OUTPUT")"
sips -c "$side" "$side" --cropOffset "$top" "$left" "$SOURCE" --out "$WORK_DIR/base.png" >/dev/null

make_icon() {
	name="$1"
	size="$2"
	sips -z "$size" "$size" "$WORK_DIR/base.png" --out "$ICONSET/$name.png" >/dev/null
}

make_icon icon_16x16 16
make_icon icon_16x16@2x 32
make_icon icon_32x32 32
make_icon icon_32x32@2x 64
make_icon icon_128x128 128
make_icon icon_128x128@2x 256
make_icon icon_256x256 256
make_icon icon_256x256@2x 512
make_icon icon_512x512 512
make_icon icon_512x512@2x 1024
iconutil -c icns "$ICONSET" -o "$OUTPUT"