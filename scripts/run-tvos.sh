#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v xcodegen >/dev/null 2>&1 || {
  echo "xcodegen is required. Install it with: brew install xcodegen" >&2
  exit 1
}

device_name="Seminterrato"
default_device_id="50772D4F-6E52-5646-BEF9-A68B8BF36343"
device_id="${TVOS_DEVICE_ID:-$default_device_id}"
derived_data="$repo_root/build/tvos-mpv-derived"
package_cache="$repo_root/build/tvos-packages"
app_path="$derived_data/Build/Products/Debug-appletvos/Nuvio.app"

echo "Generating the NuvioTV Xcode project"
xcodegen generate --spec tvosApp/project.yml

echo "Checking for Apple TV: $device_name"
device_listing="$(xcrun devicectl list devices --timeout 20)"
if [[ "$device_listing" != *"$device_name"* ]]; then
  echo "Apple TV '$device_name' is not connected or available to CoreDevice." >&2
  exit 1
fi

if [[ "$device_listing" != *"$device_id"* ]]; then
  echo "The paired device was found, but identifier '$device_id' was not present." >&2
  echo "Set TVOS_DEVICE_ID to the identifier shown by: xcrun devicectl list devices" >&2
  exit 1
fi
if [[ "$device_listing" == *"$device_name"*"unavailable"* ]]; then
  echo "Apple TV '$device_name' is paired but unavailable. Wake it and reconnect USB-C, then rerun." >&2
  exit 1
fi

echo "Building Nuvio for $device_name ($device_id)"
xcodebuild \
  -project tvosApp/NuvioTV.xcodeproj \
  -scheme NuvioTV \
  -configuration Debug \
  -destination "id=$device_id" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$package_cache" \
  -allowProvisioningUpdates \
  build

if [[ ! -d "$app_path" ]]; then
  echo "Built app not found at $app_path" >&2
  exit 1
fi

echo "Installing Nuvio"
xcrun devicectl device install app --device "$device_id" "$app_path"

echo "Launching Nuvio"
xcrun devicectl device process launch \
  --device "$device_id" \
  --terminate-existing \
  com.nuviace.app.tvos
