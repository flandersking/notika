// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotikaCore",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0")
    ],
    products: [
        .library(name: "NotikaCore", targets: ["NotikaCore"])
    ],
    targets: [
        .target(
            name: "NotikaCore",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "NotikaCoreTests",
            dependencies: ["NotikaCore"]
        )
    ]
)
