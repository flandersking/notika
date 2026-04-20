// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KirjoMacOS",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "KirjoMacOS", targets: ["KirjoMacOS"])
    ],
    dependencies: [
        .package(path: "../KirjoCore"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "KirjoMacOS",
            dependencies: [
                "KirjoCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        ),
        .testTarget(
            name: "KirjoMacOSTests",
            dependencies: ["KirjoMacOS"]
        )
    ]
)
