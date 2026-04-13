#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
DERIVED_DATA_PATH="${ROOT_DIR}/build/release-derived-data"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/LayerKeys.app"
ZIP_PATH="${DIST_DIR}/LayerKeys.zip"
SHA_PATH="${DIST_DIR}/LayerKeys.sha256"
PLIST_PATH="${ROOT_DIR}/LayerKeys/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST_PATH}")"

mkdir -p "${DIST_DIR}"
rm -rf "${DERIVED_DATA_PATH}" "${ZIP_PATH}" "${SHA_PATH}"

BUILD_ARGS=(
  -scheme LayerKeys
  -project "${ROOT_DIR}/LayerKeys.xcodeproj"
  -configuration Release
  -destination "platform=macOS"
  -derivedDataPath "${DERIVED_DATA_PATH}"
)

if [[ "${CI:-}" == "true" ]]; then
  BUILD_ARGS+=(
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGN_IDENTITY=
  )
fi

xcodebuild "${BUILD_ARGS[@]}"

ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
shasum -a 256 "${ZIP_PATH}" | awk '{print $1}' > "${SHA_PATH}"

echo "Built LayerKeys ${VERSION}"
echo "Zip: ${ZIP_PATH}"
echo "SHA256: $(cat "${SHA_PATH}")"
