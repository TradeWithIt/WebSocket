// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebSocket",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(
            name: "WebSocket",
            targets: ["WebSocket"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/websocket-kit", from: "2.15.0"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.20.0"),
    ],
    targets: [
        .target(
            name: "WebSocket",
            dependencies: [
                .product(
                    name: "WebSocketKit",
                    package: "websocket-kit",
                    condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .android, .linux, .windows])
                ),
                .product(
                    name: "JavaScriptKit",
                    package: "JavaScriptKit",
                    condition: .when(platforms: [.wasi])
                ),
            ]),
        .testTarget(
            name: "WebSocketTests",
            dependencies: ["WebSocket"]),
    ]
)
