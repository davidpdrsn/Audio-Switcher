// swift-tools-version: 6.2
import PackageDescription

// Builds the app without Xcode; scripts/build-app.sh wraps the executable in an app bundle.
// The Swift settings mirror the Xcode target's so both builds compile the same way.
let package = Package(
    name: "AudioSwitcher",
    platforms: [.macOS("26.3")],
    products: [
        .executable(name: "AudioSwitcher", targets: ["AudioSwitcher"]),
    ],
    targets: [
        .executableTarget(
            name: "AudioSwitcher",
            path: "Audio Switcher",
            exclude: ["Assets.xcassets"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("MemberImportVisibility"),
                // Xcode's "Approachable Concurrency" setting.
                .enableUpcomingFeature("DisableOutwardActorInference"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
