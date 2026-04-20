// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KirjoCore",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0")
    ],
    products: [
        .library(name: "KirjoCore", targets: ["KirjoCore"])
    ],
    targets: [
        .target(
            name: "KirjoCore",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "KirjoCoreTests",
            dependencies: ["KirjoCore"]
        )
    ]
)
