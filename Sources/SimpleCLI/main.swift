// CLI Implementation

import Foundation
import AppKit

/// Simple, working Winamp skin converter library
public struct WinampSkinConverter {
    
    public init() {}
    
    /// Convert a .wsz file to basic macOS format
    public func convertSkin(at path: String) throws -> ConvertedSkin {
        print("🔄 Converting: \(path)")
        
        let skinURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: skinURL.path) else {
            throw ConversionError.fileNotFound(path)
        }
        
        // Extract skin
        let tempDir = NSTemporaryDirectory() + "winamp_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        
        // Simple extraction
        let unzip = Process()
        unzip.launchPath = "/usr/bin/unzip"
        unzip.arguments = ["-q", "-o", path, "-d", tempDir]
        unzip.launch()
        unzip.waitUntilExit()
        
        guard unzip.terminationStatus == 0 else {
            throw ConversionError.extractionFailed
        }
        
        // Find and load main.bmp
        guard let mainBMPPath = findMainBMP(in: tempDir),
              let imageData = FileManager.default.contents(atPath: mainBMPPath),
              let image = NSImage(data: imageData) else {
            throw ConversionError.invalidMainBitmap
        }
        
        print("✅ Loaded main.bmp: \(Int(image.size.width))×\(Int(image.size.height))")
        
        // Basic coordinate conversion
        let windowHeight = image.size.height
        let sampleRegions = createSampleRegions(windowHeight: windowHeight)
        
        return ConvertedSkin(
            name: skinURL.lastPathComponent,
            originalImage: image,
            convertedRegions: sampleRegions,
            windowHeight: windowHeight
        )
    }
    
    private func findMainBMP(in directory: String) -> String? {
        let fileManager = FileManager.default
        
        func searchDirectory(_ dir: String) -> String? {
            guard let items = try? fileManager.contentsOfDirectory(atPath: dir) else { return nil }
            
            // Check current directory
            if items.contains("main.bmp") {
                return dir + "/main.bmp"
            }
            
            // Check subdirectories
            for item in items {
                let fullPath = dir + "/" + item
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                    if let found = searchDirectory(fullPath) {
                        return found
                    }
                }
            }
            
            return nil
        }
        
        return searchDirectory(directory)
    }
    
    private func createSampleRegions(windowHeight: CGFloat) -> [String: CGPoint] {
        // Convert common Winamp button positions from Windows to macOS coordinates
        let windowsRegions = [
            "play": CGPoint(x: 24, y: 28),
            "pause": CGPoint(x: 39, y: 28),
            "stop": CGPoint(x: 54, y: 28),
            "prev": CGPoint(x: 6, y: 28),
            "next": CGPoint(x: 69, y: 28)
        ]
        
        var macOSRegions: [String: CGPoint] = [:]
        for (name, windowsPoint) in windowsRegions {
            macOSRegions[name] = CGPoint(
                x: windowsPoint.x,
                y: windowHeight - windowsPoint.y
            )
        }
        
        return macOSRegions
    }
}

public struct ConvertedSkin {
    public let name: String
    public let originalImage: NSImage
    public let convertedRegions: [String: CGPoint]
    public let windowHeight: CGFloat
    
    public func printSummary() {
        print("📋 Converted Skin: \(name)")
        print("   Size: \(Int(originalImage.size.width))×\(Int(originalImage.size.height))")
        print("   Regions: \(convertedRegions.count)")
        for (name, point) in convertedRegions.sorted(by: { $0.key < $1.key }) {
            print("   • \(name): (\(Int(point.x)), \(Int(point.y)))")
        }
    }
}

public enum ConversionError: Error, LocalizedError {
    case fileNotFound(String)
    case extractionFailed
    case invalidMainBitmap
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Skin file not found: \(path)"
        case .extractionFailed:
            return "Failed to extract .wsz file"
        case .invalidMainBitmap:
            return "Invalid or missing main.bmp in skin"
        }
    }
}

// Execute the CLI
SimpleCLI.main()

// CLI Implementation
struct SimpleCLI {
    static func main() {
        print("🎵 Simple Winamp Skin Converter CLI")
        print("====================================")
        
        let args = CommandLine.arguments
        
        if args.count < 2 {
            printUsage()
            return
        }
        
        let command = args[1]
        
        switch command {
        case "convert":
            if args.count >= 3 {
                convertSkin(args[2])
            } else {
                print("❌ Please specify a skin file")
                printUsage()
            }
        case "batch":
            batchConvert()
        case "test":
            runTest()
        default:
            print("❌ Unknown command: \(command)")
            printUsage()
        }
    }
    
    static func printUsage() {
        print("""
        
        Commands:
          convert <file>    Convert a single .wsz skin
          batch            Convert all .wsz files in current directory
          test             Test with first available skin
        
        Examples:
          swift Sources/SimpleCLI/main.swift convert "Purple_Glow.wsz"
          swift Sources/SimpleCLI/main.swift batch
        """)
    }
    
    static func convertSkin(_ path: String) {
        do {
            let converter = WinampSkinConverter()
            let skin = try converter.convertSkin(at: path)
            skin.printSummary()
            print("✅ Conversion successful!")
        } catch {
            print("❌ Conversion failed: \(error.localizedDescription)")
        }
    }
    
    static func batchConvert() {
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: currentDir)
            let wszFiles = contents.filter { $0.hasSuffix(".wsz") }
            
            print("📁 Found \(wszFiles.count) .wsz files")
            
            for (index, file) in wszFiles.enumerated() {
                print("\n[\(index + 1)/\(wszFiles.count)]")
                convertSkin(file)
            }
            
            print("\n🎯 Batch conversion complete!")
        } catch {
            print("❌ Failed to read directory: \(error)")
        }
    }
    
    static func runTest() {
        let testFiles = ["Carrie-Anne Moss.wsz", "Purple_Glow.wsz", "Deus_Ex_Amp_by_AJ.wsz", "netscape_winamp.wsz"]
        
        for file in testFiles {
            if FileManager.default.fileExists(atPath: file) {
                print("🧪 Testing with: \(file)")
                convertSkin(file)
                return
            }
        }
        
        print("❌ No test skins found. Looking for:")
        for file in testFiles {
            print("   • \(file)")
        }
    }
}
