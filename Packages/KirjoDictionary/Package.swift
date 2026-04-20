// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KirjoDictionary",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "KirjoDictionary", targets: ["KirjoDictionary"])
    ],
    dependencies: [
        .package(path: "../KirjoCore")
    ],
    targets: [
        .target(
            name: "KirjoDictionary",
            dependencies: ["KirjoCore"]
        ),
        .testTarget(
            name: "KirjoDictionaryTests",
            dependencies: ["KirjoDictionary"]
        )
    ]
)
