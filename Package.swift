// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WinampMac",
    platforms: [
        .macOS(.v15)
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
        .library(
            name: "WinampRendering",
            targets: ["WinampRendering"]
        ),
        .library(
            name: "WinampPerformance",
            targets: ["WinampPerformance"]
        ),
        .executable(
            name: "WinampMacApp",
            targets: ["WinampMacApp"]
        ),
        .executable(
            name: "WinampSkinConversionCLI",
            targets: ["WinampSkinConversionCLI"]
        ),
    ],
    dependencies: [
        // No external dependencies - using only Apple frameworks for future-proofing
    ],
    targets: [
        .target(
            name: "WinampCore",
            dependencies: [],
            path: "WinampMac/Core",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "WinampRendering",
            dependencies: ["WinampCore"],
            path: "WinampMac/Rendering",
            resources: [
                .process("Shaders")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "WinampPerformance",
            dependencies: ["WinampCore", "WinampRendering"],
            path: "WinampMac/Performance",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "WinampUI",
            dependencies: ["WinampCore", "WinampRendering", "WinampPerformance"],
            path: "WinampMac/UI",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "WinampMacApp",
            dependencies: ["WinampCore", "WinampUI", "WinampRendering", "WinampPerformance"],
            path: "WinampMac/App",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "WinampCoreTests",
            dependencies: ["WinampCore"],
            path: "WinampMac/Tests/Core",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "WinampRenderingTests",
            dependencies: ["WinampRendering", "WinampCore"],
            path: "WinampMac/Tests/Rendering",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "WinampUITests",
            dependencies: ["WinampUI", "WinampCore"],
            path: "WinampMac/Tests/UI",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "WinampPerformanceTests",
            dependencies: ["WinampPerformance", "WinampCore", "WinampRendering"],
            path: "WinampMac/Tests/Performance",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "WinampSkinConversionCLI",
            dependencies: ["WinampCore", "WinampRendering"],
            path: "Sources/WinampSkinConversionCLI",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)