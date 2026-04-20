// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotikaWhisper",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "NotikaWhisper", targets: ["NotikaWhisper"])
    ],
    dependencies: [
        .package(path: "../NotikaCore"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "NotikaWhisper",
            dependencies: [
                "NotikaCore",
                .product(name: "WhisperKit", package: "WhisperKit")
            ]
        ),
        .testTarget(
            name: "NotikaWhisperTests",
            dependencies: ["NotikaWhisper"]
        )
    ]
)
