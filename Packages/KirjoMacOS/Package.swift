// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotikaMacOS",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "NotikaMacOS", targets: ["NotikaMacOS"])
    ],
    dependencies: [
        .package(path: "../NotikaCore"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "NotikaMacOS",
            dependencies: [
                "NotikaCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        ),
        .testTarget(
            name: "NotikaMacOSTests",
            dependencies: ["NotikaMacOS"]
        )
    ]
)
