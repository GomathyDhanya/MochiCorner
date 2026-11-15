#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
bundle_id="${BUNDLE_ID:-com.screenshire.desktop}"
app_name="MochiCorner"
args=(-c release --arch arm64 --arch x86_64)
swift build "${args[@]}"
bin=$(swift build "${args[@]}" --show-bin-path)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
bundle="$stage/$app_name.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$bin/$app_name" "$bundle/Contents/MacOS/$app_name"
cp -R "$bin/ScreenShire_ScreenShire.bundle" "$bundle/Contents/Resources/"
cp "Sources/ScreenShire/Resources/AppIcon.icns" "$bundle/Contents/Resources/AppIcon.icns"
plist="$bundle/Contents/Info.plist"
plutil -create xml1 "$plist"
for pair in "CFBundleExecutable $app_name" "CFBundleName $app_name" "CFBundleDisplayName $app_name" "CFBundleIconFile AppIcon" "CFBundleIdentifier $bundle_id" "CFBundlePackageType APPL" "CFBundleVersion 1" "CFBundleShortVersionString 1.0" "LSMinimumSystemVersion 14.0"; do
  plutil -insert "${pair%% *}" -string "${pair#* }" "$plist"
done
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$bundle"
else
  codesign --force --deep --sign - "$bundle"
fi
codesign --verify --strict --deep "$bundle"
archive="${1:-.build/MochiCorner.zip}"
ditto -c -k --keepParent "$bundle" "$archive"
echo "Installer archive: $archive"
