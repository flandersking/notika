// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotikaPostProcessing",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0")
    ],
    products: [
        .library(name: "NotikaPostProcessing", targets: ["NotikaPostProcessing"])
    ],
    dependencies: [
        .package(path: "../NotikaCore")
    ],
    targets: [
        .target(
            name: "NotikaPostProcessing",
            dependencies: ["NotikaCore"],
            resources: [.copy("Prompts")]
        ),
        .testTarget(
            name: "NotikaPostProcessingTests",
            dependencies: ["NotikaPostProcessing"]
        )
    ]
)
