// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ControlGrid",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "ControlGrid",
            targets: ["ControlGrid"]
        ),
    ],
    targets: [
        .target(
            name: "ControlGrid",
            path: "Sources/ControlGrid"
        ),
    ]
)
