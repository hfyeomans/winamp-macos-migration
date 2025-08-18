import Foundation
import AppKit

/// Simple, working Winamp skin converter library
/// No complex concurrency, no over-engineering, just working code

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
        for (name, point) in convertedRegions {
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
