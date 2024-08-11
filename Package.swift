// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Reactivity",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "SynchronizationExtras", targets: ["SynchronizationExtras"]),
        
        .library(name: "ReactiveGraph", targets: ["ReactiveGraph"]),
    ],
    targets: [
        .target(name: "SynchronizationExtras"),
        .testTarget(name: "SynchronizationExtrasTests",dependencies: ["SynchronizationExtras"]),

        .target(name: "ReactiveGraph", dependencies: ["SynchronizationExtras"]),
        .testTarget(name: "ReactiveGraphTests",dependencies: ["ReactiveGraph"]),
    ]
)
