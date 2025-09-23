#!/bin/bash
set -euo pipefail

SCHEME="translation"
DEST="platform=iOS Simulator,name=iPhone 16"

# Reset simulator state to avoid xctrunner launch failures
xcrun simctl shutdown all >/dev/null 2>&1 || true
xcrun simctl erase all >/dev/null 2>&1 || true

xcodebuild \
  -project ios/translation.xcodeproj \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  test \
  -only-testing:translationUITests
