// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Reactivity",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "ReactiveGraph", targets: ["ReactiveGraph"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5")
    ],
    targets: [
        .target(
            name: "ReactiveGraph",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ReactiveGraphTests",
            dependencies: ["ReactiveGraph"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
    ]
)
