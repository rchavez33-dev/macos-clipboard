// swift-tools-version: 6.0
// SwiftPM keeps every build artifact and dependency inside ./.build,
// so the project is fully isolated (the Swift equivalent of a virtualenv).
import PackageDescription

let package = Package(
    name: "SwiftClipboard",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SwiftClipboard",
            path: "Sources/SwiftClipboard"
        )
    ],
    swiftLanguageModes: [.v5]
)
