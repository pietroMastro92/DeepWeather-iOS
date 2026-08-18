#!/bin/bash
set -e

echo "==> Regenerating Tuist project..."
tuist generate --no-open

echo "==> Running xcodebuild tests..."
xcodebuild test \
  -workspace DeepWeather-iOS.xcworkspace \
  -scheme DeepWeather-iOS \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -derivedDataPath .build/DerivedData

echo "==> All iOS unit tests passed successfully!"
