# Shared bundle staging for development and distribution. Source after ROOT_DIR is set.
# Signing remains explicit in the calling workflow.
twig_stage_bundle() {
    local binary="$1" app_bundle="$2"
    [[ -x "$binary" ]] || { echo "Missing executable: $binary" >&2; return 1; }
    [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]] || {
        echo "Missing app icon. Run ./script/make_icons.sh first." >&2; return 1;
    }
    mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
    cp "$binary" "$app_bundle/Contents/MacOS/Twig"
    cp "$ROOT_DIR/Support/Info.plist" "$app_bundle/Contents/Info.plist"
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$app_bundle/Contents/Resources/AppIcon.icns"
    cp "$ROOT_DIR/LICENSE" "$app_bundle/Contents/Resources/LICENSE"
    chmod +x "$app_bundle/Contents/MacOS/Twig"
    /usr/bin/plutil -lint "$app_bundle/Contents/Info.plist" >/dev/null
}
