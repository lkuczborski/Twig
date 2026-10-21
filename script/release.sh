#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: script/release.sh <tag> --signing-identity <identity> --notary-profile <profile>

Build a universal Twig.app, Developer ID sign, notarize, staple, and verify it.
<tag> must match Support/Info.plist (v0.1 also matches bundle version 0.1.0).
Identity/profile can also be supplied as TWIG_SIGNING_IDENTITY/TWIG_NOTARY_PROFILE.
Requires Xcode 27.1 and a clean Git checkout. Does not publish or modify Git tags.
EOF
}
die() { echo "error: $*" >&2; exit 1; }
VERSION=""
SIGNING_IDENTITY="${TWIG_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${TWIG_NOTARY_PROFILE:-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --signing-identity) [[ $# -ge 2 ]] || die "missing signing identity"; SIGNING_IDENTITY="$2"; shift 2 ;;
        --notary-profile) [[ $# -ge 2 ]] || die "missing notarization profile"; NOTARY_PROFILE="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        -*) die "unknown option: $1" ;;
        *) [[ -z "$VERSION" ]] || die "provide one version"; VERSION="$1"; shift ;;
    esac
done
[[ "$VERSION" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || die "provide a release tag such as v0.1"
[[ "$SIGNING_IDENTITY" == "Developer ID Application:"* ]] || die "provide a Developer ID Application identity"
[[ -n "$NOTARY_PROFILE" ]] || die "provide a notarytool Keychain profile"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/toolchain.sh"
source "$ROOT_DIR/script/bundle.sh"
XCODE_VERSION="$(xcodebuild -version | /usr/bin/awk '/^Xcode / { print $2 }')"
[[ "$XCODE_VERSION" == 27.1 ]] || die "select Xcode 27.1 before releasing (found $XCODE_VERSION)"
echo "Release toolchain: Xcode $XCODE_VERSION"
[[ -z "$(git status --porcelain)" ]] || die "commit changes before releasing"
PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
TAG_VERSION="${VERSION#v}"
[[ "$TAG_VERSION" == *.*.* ]] || TAG_VERSION="$TAG_VERSION.0"
[[ "$PLIST_VERSION" == "$TAG_VERSION" ]] || die "tag does not match bundle version $PLIST_VERSION"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Support/Info.plist)" == com.luku.Twig ]] || die "unexpected bundle identifier"
security find-identity -v -p codesigning | /usr/bin/grep -F "\"$SIGNING_IDENTITY\"" >/dev/null || die "signing identity is unavailable"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null

./script/test.sh --configuration release
/usr/bin/swift build "${TWIG_SWIFT_ARGS[@]}" --configuration release --arch arm64 --arch x86_64 --product Twig
BUILD_DIR="$(/usr/bin/swift build "${TWIG_SWIFT_ARGS[@]}" --configuration release --arch arm64 --arch x86_64 --show-bin-path)"
ARCHITECTURES="$(/usr/bin/lipo -archs "$BUILD_DIR/Twig")"
[[ " $ARCHITECTURES " == *" arm64 "* && " $ARCHITECTURES " == *" x86_64 "* ]] || die "missing universal architectures: $ARCHITECTURES"

RELEASE_ROOT="$ROOT_DIR/dist/release"
STAGE_ROOT="$RELEASE_ROOT/$VERSION"
APP_BUNDLE="$STAGE_ROOT/Twig.app"
ZIP_NAME="Twig-$VERSION-macos-universal.zip"
ZIP_PATH="$RELEASE_ROOT/$ZIP_NAME"
[[ ! -e "$STAGE_ROOT" && ! -e "$ZIP_PATH" ]] || die "release output already exists; preserve or remove it before rebuilding"
mkdir -p "$STAGE_ROOT"
twig_stage_bundle "$BUILD_DIR/Twig" "$APP_BUNDLE"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/usr/bin/codesign -dvvv "$APP_BUNDLE" 2>&1 | /usr/bin/grep -E 'flags=.*runtime' >/dev/null || die "hardened runtime is missing"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

# The submission metadata and Apple's log stay under ignored dist/, never in Git.
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$STAGE_ROOT/notarization.json"
SUBMISSION_ID="$(/usr/bin/plutil -extract id raw -o - "$STAGE_ROOT/notarization.json")"
STATUS="$(/usr/bin/plutil -extract status raw -o - "$STAGE_ROOT/notarization.json")"
xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" "$STAGE_ROOT/notarization-log.json"
[[ "$STATUS" == Accepted ]] || die "notarization $STATUS; see $STAGE_ROOT/notarization-log.json"
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"
/usr/sbin/spctl --assess --type execute --verbose=4 "$APP_BUNDLE"

# Repackage after stapling so the download carries the offline ticket.
rm "$ZIP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
(cd "$RELEASE_ROOT" && /usr/bin/shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256")
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/twig-release-verify.XXXXXX")"
trap 'rm -rf "$VERIFY_DIR"' EXIT
/usr/bin/ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/Twig.app"
xcrun stapler validate "$VERIFY_DIR/Twig.app"
/usr/sbin/spctl --assess --type execute --verbose=4 "$VERIFY_DIR/Twig.app"
[[ -f "$VERIFY_DIR/Twig.app/Contents/Resources/LICENSE" ]] || die "packaged license is missing"
[[ -f "$VERIFY_DIR/Twig.app/Contents/Resources/AppIcon.icns" ]] || die "packaged icon is missing"
cat <<EOF
Release verified:
  $ZIP_PATH
  $ZIP_PATH.sha256
  Architectures: $ARCHITECTURES
  Notarization: $SUBMISSION_ID ($STATUS)
  Source commit: $(git rev-parse HEAD)
EOF
