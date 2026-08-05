#!/bin/zsh
# Archive DeepWeather-iOS for distribution (requires a paid Apple Developer account
# to upload to TestFlight / App Store).
set -euo pipefail
cd "$(dirname "$0")"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export TUIST_SKIP_UPDATE_CHECK=1

tuist generate --no-open

xcodebuild -workspace DeepWeather-iOS.xcworkspace \
    -scheme DeepWeather-iOS \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath .build/DerivedData \
    archive -archivePath .build/DeepWeather.xcarchive

xcodebuild -exportArchive \
    -archivePath .build/DeepWeather.xcarchive \
    -exportOptionsPlist exportOptions.plist \
    -exportPath .build/Export

echo "Archive + export complete: .build/DeepWeather.xcarchive"
echo "Upload to TestFlight/App Store requires a paid Apple Developer account:"
echo "  xcrun altool --upload-app -f .build/Export/DeepWeather.ipa -t ios"
