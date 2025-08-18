// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WinampSkinConverter",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "WinampSkinCLI",
            targets: ["WinampSkinCLI"]
        )
    ],
    targets: [
        .executableTarget(
            name: "WinampSkinCLI",
            path: "Sources/SimpleCLI"
        )
    ]
)
