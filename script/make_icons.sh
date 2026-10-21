#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/Resources/Brand/Twig.png"
[[ -f "$SOURCE" ]] || { echo "Missing logo source: $SOURCE" >&2; exit 1; }
ICON_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/twig-icon.XXXXXX")"
trap 'rm -rf "$ICON_ROOT"' EXIT
ICONSET="$ICON_ROOT/AppIcon.iconset"
mkdir -p "$ICONSET"
/usr/bin/sips -s format png -z 1024 1024 "$SOURCE" --out "$ROOT_DIR/Resources/AppIcon.png" >/dev/null
for size in 16 32 128 256 512; do
    /usr/bin/sips -z "$size" "$size" "$ROOT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    /usr/bin/sips -z "$doubled" "$doubled" "$ROOT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET" -o "$ROOT_DIR/Resources/AppIcon.icns"
echo "Exported Resources/AppIcon.png and Resources/AppIcon.icns"
