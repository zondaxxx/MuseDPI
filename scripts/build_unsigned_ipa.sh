#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
project_file="$project_root/SwByeDPI.xcodeproj"
output_dir="$project_root/packages"
output_file="$output_dir/MuseDPI-unsigned.ipa"
bundle_id="${PALKA_BUNDLE_ID:-dev.local.palkadpi}"
app_group="${PALKA_APP_GROUP:-group.$bundle_id}"

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "error: xcodebuild not found; install the full Xcode application" >&2
    exit 1
fi

if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
    echo "error: an iPhoneOS SDK is not available in the active Xcode" >&2
    echo "select a full Xcode installation with xcode-select" >&2
    exit 1
fi

work_dir="$(mktemp -d -t palkadpi-build.XXXXXX)"
archive_path="$work_dir/MuseDPI.xcarchive"
payload_dir="$work_dir/Payload"

cleanup() {
    rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$output_dir"

xcodebuild \
    -project "$project_file" \
    -scheme ByeByeDPI \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$archive_path" \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    archive \
    PALKA_BUNDLE_ID="$bundle_id" \
    PALKA_APP_GROUP="$app_group" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    PROVISIONING_PROFILE_SPECIFIER=""

app_path="$archive_path/Products/Applications/ByeByeDPI.app"
extension_path="$app_path/PlugIns/ByeByeDPITun.appex"
widget_path="$app_path/PlugIns/PalkaWidget.appex"

if [[ ! -d "$app_path" || ! -d "$extension_path" || ! -d "$widget_path" ]]; then
    echo "error: archive does not contain the host app, packet tunnel, and widget extensions" >&2
    exit 1
fi

mkdir -p "$payload_dir"
ditto "$app_path" "$payload_dir/MuseDPI.app"

(
    cd "$work_dir"
    ditto -c -k --sequesterRsrc --keepParent Payload "$output_file"
)

echo "Created: $output_file"
shasum -a 256 "$output_file"
echo "Host bundle id: $bundle_id"
echo "Tunnel bundle id: $bundle_id.tun"
echo "App Group: $app_group"
