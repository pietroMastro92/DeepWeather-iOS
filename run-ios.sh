#!/bin/zsh
# Build DeepWeather-iOS with Tuist, boot a simulator, install and launch.
set -euo pipefail
cd "$(dirname "$0")"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export TUIST_SKIP_UPDATE_CHECK=1

SIM_NAME="${SIM_NAME:-iPhone 17}"

tuist generate --no-open

xcodebuild -workspace DeepWeather-iOS.xcworkspace \
    -scheme DeepWeather-iOS \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -derivedDataPath .build/DerivedData \
    build

xcrun simctl boot "$SIM_NAME" 2>/dev/null || true
open -a Simulator

APP_PATH=".build/DerivedData/Build/Products/Debug-iphonesimulator/DeepWeather.app"
xcrun simctl install "$SIM_NAME" "$APP_PATH"
xcrun simctl launch "$SIM_NAME" com.pietromastro.deepweather
