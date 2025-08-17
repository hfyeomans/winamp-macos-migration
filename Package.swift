// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WinampMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "WinampCore",
            targets: ["WinampCore"]
        ),
        .library(
            name: "WinampUI",
            targets: ["WinampUI"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .target(
            name: "WinampCore",
            dependencies: [],
            path: "WinampMac/Core",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "WinampUI",
            dependencies: ["WinampCore"],
            path: "WinampMac/UI"
        ),
        .testTarget(
            name: "WinampCoreTests",
            dependencies: ["WinampCore"],
            path: "WinampMac/Tests"
        ),
    ]
)