# Liquid Glass & Frosted Glass Design Guide (SwiftUI)

This reference manual documents the architectural standards and design patterns for building authentic Apple-grade Liquid Glass interfaces in SwiftUI on iOS 17+.

---

## 1. Core Visual Anatomy of Liquid Glass

Liquid Glass in modern iOS consists of 4 optical layers:

```
┌─────────────────────────────────────────────────────────┐
│ 1. Specular Border Overlay (Top-Left Specular Gradient) │
│ 2. Content with Dynamic Vibrancy & High Contrast        │
│ 3. Frosted Optical Blur (.ultraThinMaterial)            │
│ 4. Ambient Diffused Shadow (Soft dynamic depth)         │
└─────────────────────────────────────────────────────────┘
```

### Key Parameters:
1. **Material Base**: `.ultraThinMaterial` allows the dynamic atmospheric background (day sky, sunset, rain, night stars) to shine through with real-time variable blur.
2. **Specular Stroke**: A 0.8pt gradient border:
   - Starts at `topLeading`: `.white.opacity(0.40)` to `.white.opacity(0.60)` (simulates ambient light reflection).
   - Fades toward `bottomTrailing`: `.white.opacity(0.10)` to `.white.opacity(0.15)`.
3. **Corner Curvature**: Always use `.continuous` curvature (`RoundedRectangle(cornerRadius: 16, style: .continuous)` or `Capsule(style: .continuous)`).
4. **Diffused Ambient Shadow**: `Color.black.opacity(0.12)` to `0.22` with a blur radius of 10–16pt and subtle vertical offset (y: 3–6pt).

---

## 2. Reusable Modifiers in DeepWeather

DeepWeather provides ready-to-use SwiftUI view modifiers:

```swift
// 1. For Cards and Containers (Forecasts, Charts, Grids)
MyView()
    .liquidGlassCard(cornerRadius: 16, materialOpacity: 0.85)

// 2. For Floating Pills and Pagers
MyPager()
    .liquidGlassCapsule(materialOpacity: 0.85)

// 3. For Circular Action Buttons
MyIconButton()
    .liquidGlassCircle()
```

---

## 3. Dynamic Alpha & State Interactions

Liquid Glass elements that float over content must adapt their alpha based on interaction:

| State | Container Material Opacity | Overall Alpha | Scale Multiplier |
| :--- | :--- | :--- | :--- |
| **Touching / Active Drag** | `0.45` | `1.0` | `1.05` + Haptic Feedback |
| **Recent Selection (2s cooldown)** | `0.35` | `0.95` | `1.00` |
| **Resting (Idle)** | `0.22` | `0.46` | `1.00` |
| **Vertical Scrolling** | `0.15` | `0.28` | `0.97` |

---

## 4. Accessibility & Legibility Guidelines

1. **Reduce Motion**: Check `@Environment(\.accessibilityReduceMotion)`. When enabled, avoid continuous scaling or floating offsets and transition instantly.
2. **Text Vibrancy**: Primary text on glass should use `.white` or `.primary` with subtle drop shadows (`.shadow(color: .black.opacity(0.2), radius: 3)`) when placed over bright daytime skies.
3. **Secondary Labels**: Use `.white.opacity(0.85)` or `.secondary` to maintain strong contrast ratios compliant with WCAG AA.
