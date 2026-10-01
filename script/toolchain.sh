# Shared development toolchain setup; sourced by the build and test entrypoints.
if [[ -z "${DEVELOPER_DIR:-}" ]] && ! /usr/bin/xcrun --find swift >/dev/null 2>&1; then
  if [[ -d /Library/Developer/CommandLineTools ]]; then
    export DEVELOPER_DIR=/Library/Developer/CommandLineTools
  fi
fi
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/ModuleCache"
# CLT's macOS 27 SDK references a SwiftUI macro plugin absent from that CLT install.
TWIG_SWIFT_ARGS=(--disable-sandbox --cache-path "$ROOT_DIR/.build/cache")
if [[ -n "${TWIG_SDK_PATH:-}" ]]; then
  TWIG_SWIFT_ARGS+=(--sdk "$TWIG_SDK_PATH")
elif [[ "${DEVELOPER_DIR:-}" == /Library/Developer/CommandLineTools ]] && [[ -d "$DEVELOPER_DIR/SDKs/MacOSX26.5.sdk" ]]; then
  TWIG_SWIFT_ARGS+=(--sdk "$DEVELOPER_DIR/SDKs/MacOSX26.5.sdk")
fi
