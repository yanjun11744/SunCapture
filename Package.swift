// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SunCapture",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SunCapture",
            targets: ["SunCapture"]
        ),
    ],
    targets: [
        .target(
            name: "SunCapture",
            path: "Sources/SunCapture"
        ),
        .testTarget(
            name: "SunCaptureTests",
            dependencies: ["SunCapture"],
            path: "Tests/SunCaptureTests"
        ),
    ]
)
