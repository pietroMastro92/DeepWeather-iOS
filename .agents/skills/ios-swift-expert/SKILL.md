---
name: ios-swift-expert
description: Expert skill for iOS application development with Swift, SwiftUI, Tuist, and Xcodebuild. Use this skill when building, refactoring, debugging, or verifying iOS apps, SwiftUI views, CoreLocation, UserNotifications, Widgets, Tuist project configurations, simulator operations, and unit tests.
---

# iOS & Swift Development Skill

Comprehensive runbook and operational standards for building high-performance, beautiful iOS applications with SwiftUI, Swift 5.10 / Swift 6, and modern Apple design language.

## 1. Core Workflow Runbook

### Step 1: Project Generation (Tuist)
Always ensure the Xcode workspace is synchronized with `Project.swift`:
```bash
tuist generate --no-open
```

### Step 2: Compiling & Testing (Xcodebuild)
Run clean incremental builds and execute the full test suite:
```bash
xcodebuild test \
  -workspace DeepWeather-iOS.xcworkspace \
  -scheme DeepWeather-iOS \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -derivedDataPath .build/DerivedData
```

### Step 3: Simulator Deployment & Lifecycle
Install and run the compiled app binary on the booted simulator:
```bash
xcrun simctl install "iPhone 17" ".build/DerivedData/Build/Products/Debug-iphonesimulator/DeepWeather.app"
xcrun simctl launch "iPhone 17" com.pietromastro.deepweather
```

### Step 4: Visual Verification & Screenshots
Capture high-fidelity screenshots for UI validation:
```bash
xcrun simctl io "iPhone 17" screenshot /tmp/ios_preview.png
```

---

## 2. SwiftUI Best Practices & Liquid Glass Design

- **Liquid Glass Reference**: See detailed anatomy, opacity curves, and specular lighting in [references/liquid_glass_guide.md](./references/liquid_glass_guide.md).
- **Frosted Glass Styling**: Use `.liquidGlassCard(cornerRadius: 16)` or `.ultraThinMaterial` paired with `RoundedRectangle(cornerRadius: ..., style: .continuous)` or `Capsule()` and a subtle linear gradient stroke overlay (`.white.opacity(0.35)` to `.white.opacity(0.1)`).
- **Smooth Animations**: Use `.spring(response: 0.35, dampingFraction: 0.8)` for natural fluid physical feedback.
- **Haptics**: Trigger tactile feedback with `UIImpactFeedbackGenerator(style: .light).impactOccurred()` on primary interactive gestures.
- **Paging & Scrolling**: Prefer horizontal `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))` for location carousels, with nested independent vertical `ScrollView` instances.
- **Dynamic Type & Accessibility**: Respect `@Environment(\.accessibilityReduceMotion)` to disable or soften animations for accessibility users.

---

## 3. Swift 5.10 / Swift 6 Concurrency Checklist

- Mark `@Observable` store classes with `@MainActor`.
- Avoid global mutable state.
- Ensure all asynchronous network calls handle cancellation gracefully.
- Decouple widget timeline generation from foreground UI tasks via shared App Groups.
