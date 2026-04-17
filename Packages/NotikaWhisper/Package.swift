// swift-tools-version: 6.0
import PackageDescription

// NotikaWhisper wird in Phase 1b mit whisper.cpp befüllt.
// Aktuell nur Stub, damit das Workspace aufgelöst werden kann.
let package = Package(
    name: "NotikaWhisper",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "NotikaWhisper", targets: ["NotikaWhisper"])
    ],
    dependencies: [
        .package(path: "../NotikaCore")
    ],
    targets: [
        .target(
            name: "NotikaWhisper",
            dependencies: ["NotikaCore"]
        )
    ]
)
