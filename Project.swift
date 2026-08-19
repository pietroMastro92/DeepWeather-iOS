import ProjectDescription

let project = Project(
    name: "DeepWeather-iOS",
    options: .options(
        defaultKnownRegions: ["en", "it", "Base"],
        developmentRegion: "en"
    ),
    targets: [
        .target(
            name: "DeepWeather-iOS",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.pietromastro.deepweather",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
                "CFBundleLocalizations": ["en", "it"],
                "CFBundleAllowMixedLocalizations": true,
                "UILaunchScreen": [
                    "UIColorName": "LaunchBackground"
                ],
                "NSLocationWhenInUseUsageDescription": "DeepWeather uses your location to show local weather when no city is selected.",
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight"
                ],
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight"
                ]
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            entitlements: .file(path: "DeepWeather-iOS.entitlements"),
            dependencies: [
                .target(name: "DeepWeatherWidget")
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
                "PRODUCT_NAME": "DeepWeather",
                "MARKETING_VERSION": "1.0",
                "CURRENT_PROJECT_VERSION": "1"
            ])
        ),
        .target(
            name: "DeepWeatherWidget",
            destinations: [.iPhone, .iPad],
            product: .appExtension,
            bundleId: "com.pietromastro.deepweather.widget",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
                "CFBundleLocalizations": ["en", "it"],
                "CFBundleAllowMixedLocalizations": true,
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
                ],
                "GeneratedExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).DeepWeatherWidgetBundle"
            ]),
            sources: [
                "Widget/**",
                "Sources/Shared/**"
            ],
            resources: ["Resources/**"],
            entitlements: .file(path: "DeepWeatherWidget.entitlements"),
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
                "PRODUCT_NAME": "DeepWeatherWidget",
                "MARKETING_VERSION": "1.0",
                "CURRENT_PROJECT_VERSION": "1",
                "APPLICATION_EXTENSION_API_ONLY": "YES",
                "SKIP_INSTALL": "YES"
            ])
        ),
        .target(
            name: "DeepWeather-iOSTests",
            destinations: [.iPhone, .iPad],
            product: .unitTests,
            bundleId: "com.pietromastro.deepweather.tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "DeepWeather-iOS")
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
                "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/DeepWeather.app/DeepWeather",
                "BUNDLE_LOADER": "$(TEST_HOST)"
            ])
        )
    ]
)
