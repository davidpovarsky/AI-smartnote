#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_DEVELOPER_DIR="${XCODE_DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
IPADOS27_SIMULATOR_ID="${IPADOS27_SIMULATOR_ID:-659D0BFD-5472-491E-91F6-F79BD391172E}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/smartnotes-deriveddata-ipados27}"
ACTION="${1:-test}"

export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"
export PATH="$XCODE_DEVELOPER_DIR/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin"

cd "$ROOT_DIR"

case "$ACTION" in
  build)
    xcodebuild build-for-testing \
      -project SmartNotes.xcodeproj \
      -scheme SmartNotes \
      -destination "id=$IPADOS27_SIMULATOR_ID" \
      -destination-timeout 180 \
      -derivedDataPath "$DERIVED_DATA_PATH"
    ;;
  test)
    xcodebuild test \
      -project SmartNotes.xcodeproj \
      -scheme SmartNotes \
      -destination "id=$IPADOS27_SIMULATOR_ID" \
      -destination-timeout 180 \
      -parallel-testing-enabled NO \
      -derivedDataPath "$DERIVED_DATA_PATH"
    ;;
  destinations)
    xcodebuild -showdestinations \
      -project SmartNotes.xcodeproj \
      -scheme SmartNotes
    ;;
  *)
    echo "Usage: $0 [build|test|destinations]" >&2
    exit 64
    ;;
esac
