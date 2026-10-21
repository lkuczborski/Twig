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
if [[ "$MODE" != --build ]]; then /usr/bin/pkill -x Twig >/dev/null 2>&1 || true; fi
/usr/bin/swift build "${TWIG_SWIFT_ARGS[@]}"
BUILD_DIR="$(/usr/bin/swift build "${TWIG_SWIFT_ARGS[@]}" --show-bin-path)"
source "$ROOT_DIR/script/bundle.sh"
twig_stage_bundle "$BUILD_DIR/Twig" "$APP_BUNDLE"
/usr/bin/codesign --force --sign - "$APP_BUNDLE" >/dev/null
case "$MODE" in
  --build) echo "Built $APP_BUNDLE" ;;
  run|--preview) /usr/bin/open -n "$APP_BUNDLE" ;;
  --debug) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/lldb -n Twig ;;
  --logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "Twig"' ;;
  --telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.luku.Twig"' ;;
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 2
    /usr/bin/pgrep -x Twig >/dev/null
    echo "Twig launched successfully. Look for the branch icon in the menu bar."
    ;;
esac
