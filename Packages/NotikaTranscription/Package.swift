// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotikaTranscription",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0")
    ],
    products: [
        .library(name: "NotikaTranscription", targets: ["NotikaTranscription"])
    ],
    dependencies: [
        .package(path: "../NotikaCore")
    ],
    targets: [
        .target(
            name: "NotikaTranscription",
            dependencies: ["NotikaCore"]
        ),
        .testTarget(
            name: "NotikaTranscriptionTests",
            dependencies: ["NotikaTranscription"]
        )
    ]
)
