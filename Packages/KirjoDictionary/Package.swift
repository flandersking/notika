// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotikaDictionary",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "NotikaDictionary", targets: ["NotikaDictionary"])
    ],
    dependencies: [
        .package(path: "../NotikaCore")
    ],
    targets: [
        .target(
            name: "NotikaDictionary",
            dependencies: ["NotikaCore"]
        ),
        .testTarget(
            name: "NotikaDictionaryTests",
            dependencies: ["NotikaDictionary"]
        )
    ]
)
