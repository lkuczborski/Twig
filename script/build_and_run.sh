#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  run|--build|--preview|--debug|--logs|--telemetry|--verify) ;;
  *) echo "Usage: $0 [--build|--preview|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/toolchain.sh"
if [[ "$MODE" == --preview ]]; then TWIG_SWIFT_ARGS+=(-Xswiftc -DTWIG_PREVIEW); fi
APP_BUNDLE="$ROOT_DIR/dist/Twig.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Twig"
if [[ "$MODE" != --build ]]; then /usr/bin/pkill -x Twig >/dev/null 2>&1 || true; fi
/usr/bin/swift build "${TWIG_SWIFT_ARGS[@]}"
BUILD_DIR="$(/usr/bin/swift build "${TWIG_SWIFT_ARGS[@]}" --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/Twig" "$APP_BINARY"
chmod +x "$APP_BINARY"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Twig</string>
<key>CFBundleIdentifier</key><string>dev.twig.app</string>
<key>CFBundleName</key><string>Twig</string>
<key>CFBundleDisplayName</key><string>Twig</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/bin/codesign --force --sign - "$APP_BUNDLE" >/dev/null
case "$MODE" in
  --build) echo "Built $APP_BUNDLE" ;;
  run|--preview) /usr/bin/open -n "$APP_BUNDLE" ;;
  --debug) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/lldb -n Twig ;;
  --logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "Twig"' ;;
  --telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "dev.twig.app"' ;;
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 2
    /usr/bin/pgrep -x Twig >/dev/null
    echo "Twig launched successfully. Look for the branch icon in the menu bar."
    ;;
esac
