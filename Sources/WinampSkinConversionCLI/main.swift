//
//  main.swift
//  WinampSkinConversionCLI
//
//  Command-line interface for demonstrating Winamp skin conversion
//

import Foundation
import AppKit

/// Command-line tool for converting Winamp skins
@available(macOS 15.0, *)
@main
struct WinampSkinConversionCLI {
    
    static func main() async {
        print("🎵 Winamp Skin Converter for macOS")
        print("===================================")
        
        let arguments = CommandLine.arguments
        
        if arguments.count < 2 {
            printUsage()
            return
        }
        
        let command = arguments[1]
        
        switch command {
        case "convert":
            if arguments.count >= 3 {
                let skinPath = arguments[2]
                await convertSkin(at: skinPath)
            } else {
                print("❌ Error: Please specify a skin file path")
                printUsage()
            }
            
        case "test":
            await runTests()
            
        case "demo":
            await runDemo()
            
        case "batch":
            await batchConvert()
            
        default:
            print("❌ Error: Unknown command '\(command)'")
            printUsage()
        }
    }
    
    static func printUsage() {
        print("""
        Usage: WinampSkinConversionCLI <command> [options]
        
        Commands:
          convert <path>  Convert a single .wsz skin file
          test           Run all conversion tests
          demo           Run interactive demo
          batch          Convert all sample skins
        
        Examples:
          WinampSkinConversionCLI convert "Carrie-Anne Moss.wsz"
          WinampSkinConversionCLI test
          WinampSkinConversionCLI batch
        """)
    }
    
    static func convertSkin(at path: String) async {
        print("🔄 Converting skin: \(path)")
        
        let skinURL = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: skinURL.path) else {
            print("❌ Error: Skin file not found at path: \(path)")
            return
        }
        
        do {
            let converter = WinampSkinConverter()
            
            // Monitor progress
            let progressTask = Task {
                while !Task.isCancelled {
                    let progress = await converter.conversionProgress
                    let operation = await converter.currentOperation
                    
                    if !operation.isEmpty {
                        print("   \(String(format: "%.1f", progress * 100))% - \(operation)")
                    }
                    
                    if progress >= 1.0 {
                        break
                    }
                    
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            }
            
            let convertedSkin = try await converter.convertSkin(from: skinURL)
            progressTask.cancel()
            
            print("✅ Conversion completed successfully!")
            printSkinDetails(convertedSkin)
            
        } catch {
            print("❌ Conversion failed: \(error)")
        }
    }
    
    static func runTests() async {
        print("🧪 Running conversion tests...")
        await SkinConversionTestRunner.runAllTests()
    }
    
    static func runDemo() async {
        print("🎮 Running interactive demo...")
        print("This would launch the Metal-based demo window showing converted skins.")
        print("(Demo requires a full macOS app to display the Metal view)")
        
        // For CLI, we'll just convert and analyze the first available skin
        let sampleSkins = [
            "Carrie-Anne Moss.wsz",
            "Deus_Ex_Amp_by_AJ.wsz",
            "Purple_Glow.wsz",
            "netscape_winamp.wsz"
        ]
        
        for skinName in sampleSkins {
            if FileManager.default.fileExists(atPath: skinName) {
                print("📱 Demonstrating with: \(skinName)")
                await convertSkin(at: skinName)
                break
            }
        }
    }
    
    static func batchConvert() async {
        print("📦 Batch converting all sample skins...")
        
        let sampleSkins = [
            "Carrie-Anne Moss.wsz",
            "Deus_Ex_Amp_by_AJ.wsz",
            "Purple_Glow.wsz",
            "netscape_winamp.wsz"
        ]
        
        var convertedCount = 0
        var failedCount = 0
        
        for skinName in sampleSkins {
            if FileManager.default.fileExists(atPath: skinName) {
                print("\n🔄 Converting: \(skinName)")
                
                do {
                    let converter = WinampSkinConverter()
                    let skinURL = URL(fileURLWithPath: skinName)
                    let convertedSkin = try await converter.convertSkin(from: skinURL)
                    
                    print("✅ \(skinName) converted successfully")
                    printSkinSummary(convertedSkin)
                    convertedCount += 1
                    
                } catch {
                    print("❌ Failed to convert \(skinName): \(error)")
                    failedCount += 1
                }
            } else {
                print("⚠️  Skin file not found: \(skinName)")
            }
        }
        
        print("\n📊 Batch Conversion Summary")
        print("===========================")
        print("✅ Successfully converted: \(convertedCount)")
        print("❌ Failed: \(failedCount)")
        print("📁 Total processed: \(convertedCount + failedCount)")
    }
    
    static func printSkinDetails(_ skin: MacOSSkin) {
        print("\n📋 Skin Details")
        print("================")
        print("Name: \(skin.name)")
        print("ID: \(skin.id)")
        print("Converted Images: \(skin.convertedImages.count)")
        print("Texture Atlases: \(skin.textureAtlases.count)")
        print("Hit-test Regions: \(skin.hitTestRegions.count)")
        print("Visualization Colors: \(skin.visualizationColors.count)")
        print("Original Regions: \(skin.regions.count)")
        
        print("\n🎨 Texture Atlases:")
        for atlas in skin.textureAtlases {
            print("  • \(atlas.name): \(atlas.texture.width)×\(atlas.texture.height) (\(atlas.uvMappings.count) textures)")
        }
        
        print("\n🎯 Hit-test Regions:")
        for (name, path) in skin.hitTestRegions {
            let bounds = path.bounds
            print("  • \(name): \(Int(bounds.width))×\(Int(bounds.height)) at (\(Int(bounds.origin.x)), \(Int(bounds.origin.y)))")
        }
        
        if !skin.visualizationColors.isEmpty {
            print("\n🌈 Visualization Colors:")
            for (index, color) in skin.visualizationColors.prefix(5).enumerated() {
                if let components = color.cgColor.components, components.count >= 3 {
                    let r = Int(components[0] * 255)
                    let g = Int(components[1] * 255)
                    let b = Int(components[2] * 255)
                    print("  • Color \(index + 1): RGB(\(r), \(g), \(b))")
                }
            }
            if skin.visualizationColors.count > 5 {
                print("  • ... and \(skin.visualizationColors.count - 5) more colors")
            }
        }
    }
    
    static func printSkinSummary(_ skin: MacOSSkin) {
        print("   📊 \(skin.convertedImages.count) images, \(skin.textureAtlases.count) atlases, \(skin.hitTestRegions.count) regions")
    }
}

// MARK: - Required imports for the conversion system
// These would normally be in separate files but included here for the CLI tool

// Import the conversion system components
// (Assuming they're available in the module)

#if canImport(WinampMac)
import WinampMac
#else
// Fallback definitions for standalone CLI

public struct WinampSkinConverter {
    public init() {}
    
    public var conversionProgress: Double = 0.0
    public var currentOperation: String = ""
    
    public func convertSkin(from url: URL) async throws -> MacOSSkin {
        // Placeholder implementation for CLI demo
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return MacOSSkin(
            id: url.lastPathComponent,
            name: "Demo Skin",
            originalSkin: nil,
            convertedImages: [:],
            textureAtlases: [],
            hitTestRegions: [:],
            regions: [:],
            visualizationColors: []
        )
    }
}

public struct MacOSSkin {
    public let id: String
    public let name: String
    public let originalSkin: Any?
    public let convertedImages: [String: Any]
    public let textureAtlases: [Any]
    public let hitTestRegions: [String: Any]
    public let regions: [String: [CGPoint]]
    public let visualizationColors: [Any]
}

public struct SkinConversionTestRunner {
    public static func runAllTests() async {
        print("🧪 Running placeholder tests...")
        print("✅ All tests would run here in the full implementation")
    }
}

#endif