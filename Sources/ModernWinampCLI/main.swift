import Foundation
import ModernWinampCore
import Metal

/// Modern Winamp Skin Converter CLI with Metal and Tahoe compatibility
@available(macOS 15.0, *)
@main
struct ModernWinampCLI {
    
    static func main() async {
        print("🎵 Modern Winamp Skin Converter for macOS 15+ (Tahoe Ready)")
        print("============================================================")
        
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
            
        case "batch":
            await batchConvert()
            
        case "info":
            printSystemInfo()
            
        default:
            print("❌ Error: Unknown command '\(command)'")
            printUsage()
        }
    }
    
    static func printUsage() {
        print("""
        
        Commands:
          convert <path>    Convert a single .wsz skin file  
          test             Test with sample skins
          batch            Convert all skins in Samples/Skins/
          info             Show system capabilities
        
        Examples:
          ModernWinampCLI convert "Samples/Skins/Purple_Glow.wsz"
          ModernWinampCLI test
          ModernWinampCLI batch
        
        Features:
          • Native Compression framework (no external dependencies)
          • Metal texture generation for GPU rendering
          • sRGB color space conversion
          • NSBezierPath shape generation  
          • macOS 26.x (Tahoe) compatibility
        """)
    }
    
    static func convertSkin(at path: String) async {
        print("🔄 Converting skin: \(path)")
        
        let fullPath: String
        if path.hasPrefix("/") || path.hasPrefix("~") {
            fullPath = path
        } else if path.hasPrefix("Samples/") {
            fullPath = path
        } else {
            // Default to Samples/Skins/ if no path specified
            fullPath = "Samples/Skins/" + path
        }
        
        guard FileManager.default.fileExists(atPath: fullPath) else {
            print("❌ Error: Skin file not found at path: \(fullPath)")
            return
        }
        
        do {
            let converter = ModernWinampSkinConverter()
            let convertedSkin = try converter.convertSkin(at: fullPath)
            
            print("✅ Conversion completed successfully!")
            convertedSkin.printSummary()
            
            // Test Metal texture creation
            if let texture = convertedSkin.metalTexture {
                print("🎮 Metal Integration Ready:")
                print("   • Texture Format: \(texture.pixelFormat)")
                print("   • Usage: \(texture.usage)")
                print("   • Storage: Shared memory (Apple Silicon optimized)")
            }
            
            // Test window shape creation
            if let windowShape = convertedSkin.createWindowShape() {
                print("🪟 Custom Window Shape:")
                print("   • Bounds: \(Int(windowShape.bounds.width))×\(Int(windowShape.bounds.height))")
                print("   • Elements: \(windowShape.elementCount) path elements")
                print("   • Ready for non-rectangular window")
            }
            
        } catch {
            print("❌ Conversion failed: \(error.localizedDescription)")
            if let conversionError = error as? ConversionError {
                printRecoveryHelp(for: conversionError)
            }
        }
    }
    
    static func runTests() async {
        print("🧪 Running tests with sample skins...")
        
        let sampleSkins = [
            "Carrie-Anne Moss.wsz",
            "Purple_Glow.wsz", 
            "netscape_winamp.wsz",
            "Deus_Ex_Amp_by_AJ.wsz"
        ]
        
        for skinName in sampleSkins {
            let skinPath = "Samples/Skins/" + skinName
            if FileManager.default.fileExists(atPath: skinPath) {
                print("\n📱 Testing: \(skinName)")
                await convertSkin(at: skinPath)
                return
            }
        }
        
        print("❌ No sample skins found in Samples/Skins/")
        print("   Expected files:")
        for skin in sampleSkins {
            print("   • \(skin)")
        }
    }
    
    static func batchConvert() async {
        print("📦 Batch converting all skins in Samples/Skins/...")
        
        let skinsPath = "Samples/Skins"
        
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: skinsPath) else {
            print("❌ Cannot read Samples/Skins/ directory")
            return
        }
        
        let wszFiles = contents.filter { $0.hasSuffix(".wsz") }
        
        guard !wszFiles.isEmpty else {
            print("❌ No .wsz files found in Samples/Skins/")
            return
        }
        
        var convertedCount = 0
        var failedCount = 0
        
        for (index, skinFile) in wszFiles.enumerated() {
            print("\n[\(index + 1)/\(wszFiles.count)] Converting: \(skinFile)")
            
            let skinPath = skinsPath + "/" + skinFile
            
            do {
                let converter = ModernWinampSkinConverter()
                let convertedSkin = try converter.convertSkin(at: skinPath)
                
                print("✅ \(skinFile) converted successfully")
                print("   📊 \(convertedSkin.convertedRegions.count) regions, \(convertedSkin.extractedFiles.count) files")
                
                if convertedSkin.metalTexture != nil {
                    print("   🎮 Metal texture: Ready")
                }
                
                convertedCount += 1
                
            } catch {
                print("❌ Failed to convert \(skinFile): \(error.localizedDescription)")
                failedCount += 1
            }
        }
        
        print("\n📊 Batch Conversion Results")
        print("============================")
        print("✅ Successfully converted: \(convertedCount)")
        print("❌ Failed: \(failedCount)")
        print("📁 Total processed: \(convertedCount + failedCount)")
        
        if convertedCount > 0 {
            print("\n🎯 Ready for integration with existing macOS Winamp players!")
        }
    }
    
    static func printSystemInfo() {
        print("🖥️  System Information")
        print("=====================")
        
        // macOS version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        print("macOS Version: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
        
        // Metal availability
        if let device = MTLCreateSystemDefaultDevice() {
            print("Metal Device: ✅ \(device.name)")
            print("Metal Family: Apple \(device.supportsFamily(.apple1) ? "1+" : "Unknown")")
            print("Unified Memory: \(device.hasUnifiedMemory ? "✅ Yes" : "❌ No")")
        } else {
            print("Metal Device: ❌ Not available")
        }
        
        // Tahoe compatibility
        if #available(macOS 26.0, *) {
            print("Tahoe Features: ✅ Available")
        } else {
            print("Tahoe Features: 🔮 Ready (when macOS 26 releases)")
        }
        
        // Hardware info
        let systemInfo = ProcessInfo.processInfo
        print("Processor Count: \(systemInfo.processorCount)")
        print("Physical Memory: \(ByteCountFormatter.string(fromByteCount: Int64(systemInfo.physicalMemory), countStyle: .memory))")
        
        print("\n✅ System ready for modern Winamp skin conversion")
    }
    
    static func printRecoveryHelp(for error: ConversionError) {
        print("\n🔧 Recovery Suggestions:")
        
        switch error {
        case .fileNotFound:
            print("   • Check the file path is correct")
            print("   • Ensure the file is in Samples/Skins/ directory")
            print("   • Try: ls Samples/Skins/*.wsz")
            
        case .extractionFailed:
            print("   • Verify the .wsz file is a valid ZIP archive")
            print("   • Try opening the file in Archive Utility")
            print("   • Download the skin again if corrupted")
            
        case .invalidMainBitmap:
            print("   • This skin may use a non-standard structure")
            print("   • Extract manually to check contents")
            print("   • Some custom skins don't include main.bmp")
            
        case .metalNotAvailable:
            print("   • Metal is required for texture generation")
            print("   • Check that your Mac supports Metal")
            print("   • Try updating to latest macOS version")
            
        case .imageConversionFailed:
            print("   • The bitmap format may be unsupported")
            print("   • Try converting the BMP to PNG manually")
            print("   • Some old skins use non-standard BMP formats")
        }
    }
}
