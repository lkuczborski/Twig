# Releasing Twig

The app identifier is `com.luku.Twig`. `Support/Info.plist` is the shared source of bundle identity, version, build number, minimum macOS version, and icon metadata for development and distribution.

## Prerequisites

- Xcode 27.1 selected through `xcode-select` or `DEVELOPER_DIR`, and an unlocked Keychain.
- A valid **Developer ID Application** signing identity.
- An authenticated `notarytool` Keychain profile for the same Apple developer team.
- A clean, committed checkout and the checked-in logo exports.

Credentials stay in Keychain. Do not put passwords, certificates, private keys, or profile contents in the repository. `TWIG_SIGNING_IDENTITY` and `TWIG_NOTARY_PROFILE` hold names only; the script does not read a password from source or print one.

## Build and verify

Update `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`, then commit the release changes. The `v0.1` Git tag corresponds to bundle version `0.1.0`, build `1`.

```sh
./script/release.sh v0.1 \
  --signing-identity "Developer ID Application: Your Name (TEAMID)" \
  --notary-profile "your-keychain-profile"
```

The script checks for Xcode 27.1, runs the release tests, builds a universal `arm64`/`x86_64` executable, stages `Twig.app` with its icon and MIT license, enables hardened runtime, and signs with a secure timestamp. It submits a ZIP to Apple's notary service, saves the result and log under ignored `dist/release/v0.1/`, staples the accepted ticket, and checks Gatekeeper acceptance. It then recreates the ZIP so the download includes the stapled ticket, writes a SHA-256 checksum, extracts it into a temporary directory, and checks its signature, staple, and Gatekeeper acceptance again.

Output:

- `dist/release/Twig-v0.1-macos-universal.zip`
- `dist/release/Twig-v0.1-macos-universal.zip.sha256`

The script refuses to overwrite an existing release output. Keep submission metadata if a network interruption requires investigating or waiting for an existing submission; do not keep resubmitting an in-progress build. Inspect Apple's saved notarization log for warnings before publishing. Never upload the unstapled intermediate ZIP.

## Publish

After verification, create the annotated version tag at the exact source commit, push the branch and tag, and create a draft GitHub release with the two verified assets and the corresponding release notes. Check the uploaded checksum, then publish the draft. Do not replace published binaries under the same version; issue a new version for changes.

The script packages and verifies only. Repository publication is a separate explicit step so an unsuccessful notarization cannot publish an unverified artifact. Signing identities, notarization output, and temporary test data stay outside Git.
