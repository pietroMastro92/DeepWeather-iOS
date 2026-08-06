# DeepWeather for iOS

Native iOS port of [DeepWeather](https://github.com/pietroMastro92/DeepWeather): full dashboard with current conditions, charts, moon phases, hourly strip and 3-day forecast — plus a home/lock screen widget, local weather notifications and an iPad-optimized layout.

> Companion to the macOS menu bar app in the [DeepWeather monorepo](https://github.com/pietroMastro92/DeepWeather). This repository is the **standalone** Tuist project for iOS (recommended source of truth for the iOS app).

## Features

- **Dashboard**: current conditions (SF Symbol animated icon, temperature, feels like, humidity, wind, UV, pressure, visibility, precipitation, cloud cover, sunrise/sunset), temperature + precipitation charts (Swift Charts), moon phases, hourly strip, 3-day forecast
- **Welcome screen**: optional local profile (your name) shown on first launch, editable from Settings
- **Dynamic weather theme**: animated hero gradient that changes with conditions and time of day (sunny, clear night, rain, snow, storm, fog), refined staggered animations and live chart transitions
- **Splash screen**: system launch screen (brand color + logo) + short animated in-app splash
- **Locations**: Open-Meteo city search, multiple saved cities, swipe-to-delete; automatic location via CoreLocation GPS with graceful fallback to IP-based location if denied
- **Units**: Metric / Imperial; configurable refresh interval (10–60 min)
- **Widgets**: Home Screen (`systemSmall`, `systemMedium`) and Lock Screen (`accessoryCircular`, `accessoryRectangular`, `accessoryInline`); data shared through an App Group
- **Notifications** (local, no server): optional daily morning summary and an evening rain alert when tomorrow's rain chance is ≥ 60%
- **iPad**: two-column layout on regular width
- **Localized**: English (base) + Italian, follows the device language
- **Native look**: dark/light mode, SwiftUI, iOS 17+

## Building from source

Requires Xcode 26+ and [Tuist](https://tuist.dev) (`brew install tuist`).

```bash
git clone https://github.com/pietroMastro92/DeepWeather-iOS.git
cd DeepWeather-iOS
./run-ios.sh               # generate project, build, boot simulator, install and launch
```

`run-ios.sh` builds for the `iPhone 17` simulator by default; override with `SIM_NAME="iPhone 16"`.

## Notes (free Apple Developer account)

- App and widget run fully on the **simulator**.
- On a physical device, free provisioning signs for 7 days. The App Group is managed by automatic signing; if it fails on-device, the widget simply shows a placeholder until the app writes its cached snapshot.
- **TestFlight / App Store** require a paid Apple Developer account. Everything is prepared: versioning, Release configuration, `PrivacyInfo.xcprivacy` (no data collected), `archive.sh` + `exportOptions.plist`, and a metadata checklist below.

## Archive / distribution (requires paid account)

```bash
./archive.sh               # archives and exports a .ipa
```

Then upload with `xcrun altool --upload-app -f .build/Export/DeepWeather.ipa -t ios`.

### App Store metadata checklist

- App name: **DeepWeather**
- Bundle ID: `com.pietromastro.deepweather` (widget: `com.pietromastro.deepweather.widget`)
- Version: `1.0` (build 1) — bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `Project.swift`
- Screenshots: iPhone 6.9" / 6.5", iPad 12.9" (light/dark), widget gallery (Home + Lock Screen)
- Privacy: no data collected (weather from wttr.in, geocoding from Open-Meteo; location used only to show local weather and never leaves the device as personal data)

## Data sources

- Weather data: [wttr.in](https://wttr.in) (WorldWeatherOnline data, `format=j1`)
- Geocoding: [Open-Meteo Geocoding API](https://open-meteo.com) (no API key required)

## Related

- **macOS menu bar app** (sibling product): [pietroMastro92/DeepWeather](https://github.com/pietroMastro92/DeepWeather)

## License

[MIT](./LICENSE)
