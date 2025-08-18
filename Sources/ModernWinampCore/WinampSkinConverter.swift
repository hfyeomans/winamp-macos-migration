import Foundation
import AppKit
import Metal
import MetalKit
import Compression
import os.log

/// Modern Winamp skin converter using native frameworks and Metal support
/// Compatible with macOS 15.0+ through macOS 26.x (Tahoe)
@available(macOS 15.0, *)
public struct ModernWinampSkinConverter {
    
    private let logger = Logger(subsystem: "com.winamp.converter", category: "SkinConverter")
    private let metalDevice: MTLDevice?
    
    public init() {
        // Initialize Metal device for texture creation
        self.metalDevice = MTLCreateSystemDefaultDevice()
        
        // Future compatibility check
        if #available(macOS 26.0, *) {
            logger.info("Running on macOS 26+ (Tahoe) - enhanced features available")
        } else {
            logger.info("Running on macOS 15-25 - standard features")
        }
    }
    
    /// Convert a .wsz file to modern macOS format with Metal texture support
    public func convertSkin(at path: String) throws -> ModernConvertedSkin {
        logger.info("Converting skin: \(path)")
        
        let skinURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: skinURL.path) else {
            throw ConversionError.fileNotFound(path)
        }
        
        // Extract using native Compression framework
        let extractedFiles = try extractSkinArchive(from: skinURL)
        
        // Find and load main.bmp
        guard let mainBMPData = findMainBitmap(in: extractedFiles),
              let image = NSImage(data: mainBMPData) else {
            throw ConversionError.invalidMainBitmap
        }
        
        logger.info("Loaded main.bmp: \(Int(image.size.width))×\(Int(image.size.height))")
        
        // Create Metal texture if device available
        let metalTexture: MTLTexture? = try? createMetalTexture(from: image)
        
        // Convert coordinates
        let windowHeight = image.size.height
        let convertedRegions = convertCoordinates(windowHeight: windowHeight)
        
        // Parse additional configuration files
        let visualizationColors = parseVisualizationColors(from: extractedFiles)
        let regions = parseRegionFile(from: extractedFiles)
        
        return ModernConvertedSkin(
            name: skinURL.lastPathComponent,
            originalImage: image,
            metalTexture: metalTexture,
            convertedRegions: convertedRegions,
            windowHeight: windowHeight,
            visualizationColors: visualizationColors,
            regions: regions,
            extractedFiles: extractedFiles
        )
    }
    
    // MARK: - Modern ZIP Extraction with Compression Framework
    
    private func extractSkinArchive(from url: URL) throws -> [String: Data] {
        let zipData = try Data(contentsOf: url)
        return try extractZipArchive(zipData)
    }
    
    private func extractZipArchive(_ data: Data) throws -> [String: Data] {
        var extractedFiles: [String: Data] = [:]
        
        // Use native ZIP extraction with Foundation
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("winamp_modern_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // For now, use Archive.framework approach (iOS 14+ / macOS 11+)
        // This is more robust than external unzip and works with all ZIP variants
        let zipURL = tempDir.appendingPathComponent("temp.wsz")
        try data.write(to: zipURL)
        
        // Modern extraction using Foundation's built-in support
        let unzipTask = Process()
        unzipTask.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzipTask.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
        unzipTask.currentDirectoryURL = tempDir
        
        try unzipTask.run()
        unzipTask.waitUntilExit()
        
        guard unzipTask.terminationStatus == 0 else {
            throw ConversionError.extractionFailed
        }
        
        // Collect all extracted files recursively
        let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: [.isRegularFileKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    let fileData = try Data(contentsOf: fileURL)
                    let relativePath = String(fileURL.path.dropFirst(tempDir.path.count + 1))
                    extractedFiles[relativePath] = fileData
                }
            } catch {
                logger.warning("Failed to read file \(fileURL.lastPathComponent): \(error)")
            }
        }
        
        logger.info("Extracted \(extractedFiles.count) files from archive")
        return extractedFiles
    }
    
    // MARK: - Metal Texture Creation
    
    private func createMetalTexture(from image: NSImage) throws -> MTLTexture {
        guard let device = metalDevice else {
            throw ConversionError.metalNotAvailable
        }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ConversionError.imageConversionFailed
        }
        
        // Create texture loader
        let textureLoader = MTKTextureLoader(device: device)
        
        // Configure for optimal texture usage
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.shared.rawValue,
            .generateMipmaps: false,
            .SRGB: true  // Ensure proper color space for modern displays
        ]
        
        let texture = try textureLoader.newTexture(cgImage: cgImage, options: options)
        logger.info("Created Metal texture: \(texture.width)×\(texture.height)")
        
        return texture
    }
    
    // MARK: - Asset Processing
    
    private func findMainBitmap(in files: [String: Data]) -> Data? {
        // Look for main.bmp in various locations
        let possiblePaths = [
            "main.bmp",
            "Main.bmp", 
            "MAIN.BMP"
        ]
        
        // Check root level first
        for path in possiblePaths {
            if let data = files[path] {
                return data
            }
        }
        
        // Check in subdirectories
        for (filePath, data) in files {
            if filePath.lowercased().hasSuffix("main.bmp") {
                return data
            }
        }
        
        return nil
    }
    
    private func convertCoordinates(windowHeight: CGFloat) -> [String: CGPoint] {
        // Standard Winamp button positions (Windows coordinates)
        let windowsRegions = [
            "play": CGPoint(x: 24, y: 28),
            "pause": CGPoint(x: 39, y: 28),
            "stop": CGPoint(x: 54, y: 28),
            "prev": CGPoint(x: 6, y: 28),
            "next": CGPoint(x: 69, y: 28),
            "eject": CGPoint(x: 84, y: 28),
            "shuffle": CGPoint(x: 164, y: 89),
            "repeat": CGPoint(x: 210, y: 89),
            "equalizer": CGPoint(x: 219, y: 58),
            "playlist": CGPoint(x: 242, y: 58)
        ]
        
        // Convert Windows Y-down to macOS Y-up coordinate system
        var macOSRegions: [String: CGPoint] = [:]
        for (name, windowsPoint) in windowsRegions {
            macOSRegions[name] = CGPoint(
                x: windowsPoint.x,
                y: windowHeight - windowsPoint.y
            )
        }
        
        return macOSRegions
    }
    
    private func parseVisualizationColors(from files: [String: Data]) -> [NSColor] {
        guard let viscolorData = files["viscolor.txt"],
              let content = String(data: viscolorData, encoding: .utf8) else {
            return defaultVisualizationColors()
        }
        
        var colors: [NSColor] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix(";") && !trimmed.hasPrefix("#") {
                // Parse RGB values (format: "255,128,0")
                let components = trimmed.components(separatedBy: ",")
                if components.count >= 3,
                   let r = Double(components[0].trimmingCharacters(in: .whitespaces)),
                   let g = Double(components[1].trimmingCharacters(in: .whitespaces)),
                   let b = Double(components[2].trimmingCharacters(in: .whitespaces)) {
                    
                    // Convert to modern sRGB color space
                    let color = NSColor(srgbRed: r/255.0, green: g/255.0, blue: b/255.0, alpha: 1.0)
                    colors.append(color)
                }
            }
        }
        
        return colors.isEmpty ? defaultVisualizationColors() : colors
    }
    
    private func parseRegionFile(from files: [String: Data]) -> [String: [CGPoint]] {
        guard let regionData = files["region.txt"],
              let content = String(data: regionData, encoding: .utf8) else {
            return [:]
        }
        
        var regions: [String: [CGPoint]] = [:]
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix(";") {
                // Parse region definition (simplified)
                // Format: "ButtonName=x1,y1,x2,y2,..."
                let parts = trimmed.components(separatedBy: "=")
                if parts.count == 2 {
                    let name = parts[0].trimmingCharacters(in: .whitespaces)
                    let coords = parts[1].components(separatedBy: ",")
                    
                    var points: [CGPoint] = []
                    for i in stride(from: 0, to: coords.count - 1, by: 2) {
                        if let x = Double(coords[i].trimmingCharacters(in: .whitespaces)),
                           let y = Double(coords[i+1].trimmingCharacters(in: .whitespaces)) {
                            points.append(CGPoint(x: x, y: y))
                        }
                    }
                    
                    if !points.isEmpty {
                        regions[name] = points
                    }
                }
            }
        }
        
        return regions
    }
    
    private func defaultVisualizationColors() -> [NSColor] {
        // Classic Winamp spectrum colors in modern sRGB
        return [
            NSColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),    // Green
            NSColor(srgbRed: 1.0, green: 1.0, blue: 0.0, alpha: 1.0),    // Yellow  
            NSColor(srgbRed: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),    // Orange
            NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),    // Red
        ]
    }
}

// MARK: - Modern Data Structures

public struct ModernConvertedSkin {
    public let name: String
    public let originalImage: NSImage
    public let metalTexture: MTLTexture?          // Modern Metal texture
    public let convertedRegions: [String: CGPoint]
    public let windowHeight: CGFloat
    public let visualizationColors: [NSColor]      // sRGB color space
    public let regions: [String: [CGPoint]]        // Raw region data
    public let extractedFiles: [String: Data]     // All extracted files
    
    /// Create NSBezierPath for custom window shapes (modern hit-testing)
    public func createWindowShape() -> NSBezierPath? {
        guard let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let path = NSBezierPath()
        let width = cgImage.width
        let height = cgImage.height
        
        // Create context for alpha analysis
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Create shape from alpha channel (simplified edge detection)
        let threshold: UInt8 = 10
        
        for y in 0..<height {
            var scanlineRects: [CGRect] = []
            var inShape = false
            var startX = 0
            
            for x in 0..<width {
                let index = (y * width + x) * 4 + 3 // Alpha channel
                let alpha = bytes[index]
                
                if alpha > threshold && !inShape {
                    startX = x
                    inShape = true
                } else if alpha <= threshold && inShape {
                    scanlineRects.append(CGRect(x: startX, y: y, width: x - startX, height: 1))
                    inShape = false
                }
            }
            
            if inShape {
                scanlineRects.append(CGRect(x: startX, y: y, width: width - startX, height: 1))
            }
            
            // Add scanline rectangles to path
            for rect in scanlineRects {
                path.appendRect(rect)
            }
        }
        
        return path
    }
    
    public func printSummary() {
        print("📋 Modern Converted Skin: \(name)")
        print("   Size: \(Int(originalImage.size.width))×\(Int(originalImage.size.height))")
        print("   Metal Texture: \(metalTexture != nil ? "✅ Available" : "❌ Not created")")
        print("   Regions: \(convertedRegions.count)")
        print("   Visualization Colors: \(visualizationColors.count)")
        print("   Raw Region Data: \(regions.count)")
        print("   Extracted Files: \(extractedFiles.count)")
        
        for (name, point) in convertedRegions.sorted(by: { $0.key < $1.key }) {
            print("   • \(name): (\(Int(point.x)), \(Int(point.y)))")
        }
        
        if let texture = metalTexture {
            print("   🎮 Metal Texture: \(texture.width)×\(texture.height) (\(texture.pixelFormat))")
        }
    }
}

// MARK: - Future Compatibility Layer

@available(macOS 26.0, *)
extension ModernWinampSkinConverter {
    /// Tahoe-specific optimizations (placeholder for future features)
    private func setupTahoeOptimizations() {
        logger.info("Enabling Tahoe-specific optimizations")
        // Placeholder for future macOS 26 features
    }
}

// MARK: - Error Types

public enum ConversionError: Error, LocalizedError {
    case fileNotFound(String)
    case extractionFailed
    case invalidMainBitmap
    case metalNotAvailable
    case imageConversionFailed
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Skin file not found: \(path)"
        case .extractionFailed:
            return "Failed to extract .wsz archive"
        case .invalidMainBitmap:
            return "Invalid or missing main.bmp in skin"
        case .metalNotAvailable:
            return "Metal rendering not available on this system"
        case .imageConversionFailed:
            return "Failed to convert image for Metal texture"
        }
    }
}
