// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebSocket",
    platforms: [.macOS(.v12), .iOS(.v16), .watchOS(.v6), .tvOS(.v16)],
    products: [
        .library(
            name: "WebSocket",
            targets: ["WebSocket"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/websocket-kit", from: "2.15.0"),
    ],
    targets: [
        .target(
            name: "WebSocket",
            dependencies: [
                .product(name: "WebSocketKit", package: "websocket-kit"),
            ]),
        .testTarget(
            name: "WebSocketTests",
            dependencies: ["WebSocket"]),
    ]
)
