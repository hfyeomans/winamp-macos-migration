// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WinampSkinConverter",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "ModernWinampCore",
            targets: ["ModernWinampCore"]
        ),
        .executable(
            name: "ModernWinampCLI",
            targets: ["ModernWinampCLI"]
        )
    ],
    targets: [
        .target(
            name: "ModernWinampCore",
            path: "Sources/ModernWinampCore"
        ),
        .executableTarget(
            name: "ModernWinampCLI",
            dependencies: ["ModernWinampCore"],
            path: "Sources/ModernWinampCLI"
        )
    ]
)
