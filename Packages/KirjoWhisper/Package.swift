// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KirjoWhisper",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "KirjoWhisper", targets: ["KirjoWhisper"])
    ],
    dependencies: [
        .package(path: "../KirjoCore"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "KirjoWhisper",
            dependencies: [
                "KirjoCore",
                .product(name: "WhisperKit", package: "WhisperKit")
            ]
        ),
        .testTarget(
            name: "KirjoWhisperTests",
            dependencies: ["KirjoWhisper"]
        )
    ]
)
