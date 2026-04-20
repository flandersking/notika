// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KirjoTranscription",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0")
    ],
    products: [
        .library(name: "KirjoTranscription", targets: ["KirjoTranscription"])
    ],
    dependencies: [
        .package(path: "../KirjoCore")
    ],
    targets: [
        .target(
            name: "KirjoTranscription",
            dependencies: ["KirjoCore"]
        ),
        .testTarget(
            name: "KirjoTranscriptionTests",
            dependencies: ["KirjoTranscription"]
        )
    ]
)
