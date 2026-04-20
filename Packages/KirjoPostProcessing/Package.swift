// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KirjoPostProcessing",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0")
    ],
    products: [
        .library(name: "KirjoPostProcessing", targets: ["KirjoPostProcessing"])
    ],
    dependencies: [
        .package(path: "../KirjoCore")
    ],
    targets: [
        .target(
            name: "KirjoPostProcessing",
            dependencies: ["KirjoCore"],
            resources: [.copy("Prompts")]
        ),
        .testTarget(
            name: "KirjoPostProcessingTests",
            dependencies: ["KirjoPostProcessing"],
            resources: [.copy("Fixtures")]
        )
    ]
)
