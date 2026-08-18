#!/bin/bash
set -e

DEVICE_NAME="${1:-iPhone 17}"
APP_PATH=".build/DerivedData/Build/Products/Debug-iphonesimulator/DeepWeather.app"

echo "==> Installing app on $DEVICE_NAME..."
xcrun simctl install "$DEVICE_NAME" "$APP_PATH"

echo "==> Launching DeepWeather app..."
xcrun simctl launch "$DEVICE_NAME" com.pietromastro.deepweather
