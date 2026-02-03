// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
// 主要功能：
// - 定义 Swift Package 的平台、依赖与目标配置


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
    dependencies: [
        .package(url: "https://github.com/Tencent/wcdb.git", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "EasyAI",
            dependencies: ["WCDBSwift"]),
    ]
)
