# AGENTS.md - DeepWeather iOS Agent Guidelines

This repository is an AI-first, modern iOS weather application built with Swift 5.10 / 6 and SwiftUI.

## Mandatory Architectural & Coding Standards

1. **Swift Concurrency**:
   - All UI-bound state and `@Observable` stores must be annotated with `@MainActor`.
   - Prefer `async`/`await` and structured tasks over completion handlers or GCD.
   - Ensure all data models conforming to `Codable` or transferred across actors are `Sendable`.

2. **SwiftUI & Modern Design (iOS 17+)**:
   - Use `@Observable` and `@Bindable` instead of deprecated `ObservableObject` / `@Published`.
   - Use native Liquid Glass / Frosted Glass aesthetics using `.ultraThinMaterial`, `Capsule()`, and subtle white gradient stroke overlays.
   - Validate all SF Symbols to ensure they exist in iOS 17+ system catalogs (e.g., use `cloud.moon` instead of `moon.cloud`, `cloud.fog.fill` instead of uncatalogued symbols).
   - Ensure full accessibility support with dynamic sizing, `@Environment(\.accessibilityReduceMotion)`, and clear accessibility labels.

3. **Project Generation & Build Tooling**:
   - This project uses **Tuist** for project generation (`Project.swift`).
   - Whenever dependencies, schemes, or project settings are modified, always regenerate with:
     ```bash
     tuist generate --no-open
     ```
   - To build and test:
     ```bash
     xcodebuild test -workspace DeepWeather-iOS.xcworkspace -scheme DeepWeather-iOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath .build/DerivedData
     ```

4. **Multi-Target Architecture & App Groups**:
   - Shared data between the main app and widgets uses App Groups (`group.com.pietromastro.deepweather`).
   - Always verify fallback to `UserDefaults.standard` if running outside an App Group container.
