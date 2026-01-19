// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EasyAI",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "EasyAI",
            targets: ["EasyAI"]),
    ],
    targets: [
        .target(
            name: "EasyAI",
            dependencies: []),
    ]
)

