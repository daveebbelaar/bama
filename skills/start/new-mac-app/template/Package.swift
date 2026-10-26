// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "__APP_NAME__",
    platforms: [.macOS(.v26)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "__APP_NAME__Kit"),
        .executableTarget(
            name: "__APP_NAME__",
            dependencies: ["__APP_NAME__Kit"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "__APP_NAME__KitTests", dependencies: ["__APP_NAME__Kit"]),
    ]
)
