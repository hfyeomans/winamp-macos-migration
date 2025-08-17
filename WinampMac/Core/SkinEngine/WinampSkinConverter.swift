//
//  WinampSkinConverter.swift
//  WinampMac
//
//  Comprehensive Windows .wsz to macOS skin converter
//  Handles coordinate system conversion, color space mapping, and Metal optimization
//

import Foundation
import AppKit
import Metal
import MetalKit
import CoreImage
import UniformTypeIdentifiers
import OSLog
import Accelerate

/// Comprehensive converter for Windows Winamp skins to macOS format
/// Handles coordinate system differences, color space conversion, and Metal optimization
@available(macOS 15.0, *)
public final class WinampSkinConverter: ObservableObject {
    
    // MARK: - Logger
    private static let logger = Logger(subsystem: "com.winamp.mac.converter", category: "SkinConverter")
    
    // MARK: - Configuration
    private let metalDevice: MTLDevice?
    private let colorSpace: CGColorSpace
    private let ciContext: CIContext
    
    // MARK: - Conversion State
    @Published public private(set) var isConverting: Bool = false
    @Published public private(set) var conversionProgress: Double = 0.0
    @Published public private(set) var currentOperation: String = ""
    
    // MARK: - Initialization
    public init() {
        self.metalDevice = MTLCreateSystemDefaultDevice()
        
        // Create sRGB color space for macOS
        self.colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        
        // Create Core Image context for advanced image processing
        if let device = metalDevice {
            self.ciContext = CIContext(mtlDevice: device)
        } else {
            self.ciContext = CIContext()
        }
    }
    
    // MARK: - Public Interface
    
    /// Convert a Windows .wsz skin to macOS format
    public func convertSkin(from url: URL) async throws -> MacOSSkin {
        await updateProgress(0.0, operation: "Starting conversion...")
        
        // Load the Windows skin
        await updateProgress(0.1, operation: "Loading Windows skin...")
        let windowsSkin = try await AsyncSkinLoader().loadSkin(from: url)
        
        // Convert coordinate system
        await updateProgress(0.3, operation: "Converting coordinate system...")
        let convertedRegions = try await convertCoordinateSystem(windowsSkin.configuration.regions)
        
        // Convert color spaces
        await updateProgress(0.5, operation: "Converting color spaces...")
        let convertedImages = try await convertColorSpaces(windowsSkin.resources.bitmaps)
        
        // Generate texture atlases
        await updateProgress(0.7, operation: "Generating Metal texture atlases...")
        let textureAtlases = try await generateTextureAtlases(from: convertedImages)
        
        // Create hit-test regions
        await updateProgress(0.8, operation: "Creating hit-test regions...")
        let hitTestRegions = try await createHitTestRegions(from: convertedRegions)
        
        // Create final macOS skin
        await updateProgress(0.9, operation: "Finalizing macOS skin...")
        let macOSSkin = try await createMacOSSkin(
            from: windowsSkin,
            regions: convertedRegions,
            images: convertedImages,
            atlases: textureAtlases,
            hitTestRegions: hitTestRegions
        )
        
        await updateProgress(1.0, operation: "Conversion complete!")
        
        Self.logger.info("Successfully converted skin: \(windowsSkin.name)")
        return macOSSkin
    }
    
    /// Convert multiple skins in batch
    public func convertSkins(from urls: [URL]) async throws -> [MacOSSkin] {
        var convertedSkins: [MacOSSkin] = []
        
        for (index, url) in urls.enumerated() {
            let overallProgress = Double(index) / Double(urls.count)
            await updateProgress(overallProgress, operation: "Converting skin \(index + 1) of \(urls.count)...")
            
            do {
                let convertedSkin = try await convertSkin(from: url)
                convertedSkins.append(convertedSkin)
            } catch {
                Self.logger.error("Failed to convert skin at \(url.path): \(error)")
                // Continue with other skins
            }
        }
        
        return convertedSkins
    }
    
    // MARK: - Coordinate System Conversion
    
    /// Convert Windows coordinate system to macOS coordinate system
    /// Windows: Origin at top-left, Y increases downward
    /// macOS: Origin at bottom-left, Y increases upward
    private func convertCoordinateSystem(_ windowsRegions: [String: [CGPoint]]) async throws -> [String: [CGPoint]] {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                var convertedRegions: [String: [CGPoint]] = [:]
                
                // Standard Winamp main window height (116 pixels)
                let windowHeight: CGFloat = 116.0
                
                for (regionName, points) in windowsRegions {
                    let convertedPoints = points.map { point in
                        CGPoint(x: point.x, y: windowHeight - point.y)
                    }
                    convertedRegions[regionName] = convertedPoints
                }
                
                continuation.resume(returning: convertedRegions)
            }
        }
    }
    
    // MARK: - Color Space Conversion
    
    /// Convert Windows RGB images to macOS sRGB color space
    private func convertColorSpaces(_ windowsImages: [String: NSImage]) async throws -> [String: NSImage] {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WinampError.conversionFailed(reason: "Converter deallocated"))
                    return
                }
                
                do {
                    var convertedImages: [String: NSImage] = [:]
                    
                    for (imageName, windowsImage) in windowsImages {
                        let convertedImage = try await self.convertImageColorSpace(windowsImage)
                        convertedImages[imageName] = convertedImage
                    }
                    
                    continuation.resume(returning: convertedImages)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Convert individual image from Windows RGB to macOS sRGB
    private func convertImageColorSpace(_ windowsImage: NSImage) async throws -> NSImage {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WinampError.conversionFailed(reason: "Converter deallocated"))
                    return
                }
                
                do {
                    // Convert NSImage to CGImage
                    guard let cgImage = windowsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                        throw WinampError.imageConversionFailed(reason: "Failed to get CGImage")
                    }
                    
                    // Create Core Image from CGImage
                    let ciImage = CIImage(cgImage: cgImage)
                    
                    // Apply color space conversion filter
                    guard let colorSpaceFilter = CIFilter(name: "CIColorSpace") else {
                        throw WinampError.imageConversionFailed(reason: "Failed to create color space filter")
                    }
                    
                    colorSpaceFilter.setValue(ciImage, forKey: kCIInputImageKey)
                    colorSpaceFilter.setValue(self.colorSpace, forKey: "inputColorSpace")
                    
                    guard let outputImage = colorSpaceFilter.outputImage else {
                        throw WinampError.imageConversionFailed(reason: "Failed to apply color space conversion")
                    }
                    
                    // Render to CGImage with sRGB color space
                    guard let convertedCGImage = self.ciContext.createCGImage(
                        outputImage,
                        from: outputImage.extent,
                        format: .RGBA8,
                        colorSpace: self.colorSpace
                    ) else {
                        throw WinampError.imageConversionFailed(reason: "Failed to render converted image")
                    }
                    
                    // Create NSImage from converted CGImage
                    let convertedNSImage = NSImage(cgImage: convertedCGImage, size: windowsImage.size)
                    
                    continuation.resume(returning: convertedNSImage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Metal Texture Atlas Generation
    
    /// Generate Metal-compatible texture atlases for efficient rendering
    private func generateTextureAtlases(from images: [String: NSImage]) async throws -> [MetalTextureAtlas] {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WinampError.conversionFailed(reason: "Converter deallocated"))
                    return
                }
                
                do {
                    var atlases: [MetalTextureAtlas] = []
                    
                    // Group images by type for optimal atlas packing
                    let mainImages = images.filter { $0.key.contains("main") }
                    let buttonImages = images.filter { $0.key.contains("button") || $0.key.contains("cbuttons") }
                    let numberImages = images.filter { $0.key.contains("numbers") || $0.key.contains("nums") }
                    let textImages = images.filter { $0.key.contains("text") }
                    let otherImages = images.filter { key, _ in
                        !mainImages.keys.contains(key) &&
                        !buttonImages.keys.contains(key) &&
                        !numberImages.keys.contains(key) &&
                        !textImages.keys.contains(key)
                    }
                    
                    // Create atlases for each group
                    if !mainImages.isEmpty {
                        let atlas = try await self.createTextureAtlas(from: mainImages, name: "main")
                        atlases.append(atlas)
                    }
                    
                    if !buttonImages.isEmpty {
                        let atlas = try await self.createTextureAtlas(from: buttonImages, name: "buttons")
                        atlases.append(atlas)
                    }
                    
                    if !numberImages.isEmpty {
                        let atlas = try await self.createTextureAtlas(from: numberImages, name: "numbers")
                        atlases.append(atlas)
                    }
                    
                    if !textImages.isEmpty {
                        let atlas = try await self.createTextureAtlas(from: textImages, name: "text")
                        atlases.append(atlas)
                    }
                    
                    if !otherImages.isEmpty {
                        let atlas = try await self.createTextureAtlas(from: otherImages, name: "misc")
                        atlases.append(atlas)
                    }
                    
                    continuation.resume(returning: atlases)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Create a single texture atlas from a group of images
    private func createTextureAtlas(from images: [String: NSImage], name: String) async throws -> MetalTextureAtlas {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WinampError.conversionFailed(reason: "Converter deallocated"))
                    return
                }
                
                do {
                    // Calculate optimal atlas size
                    let atlasSize = self.calculateOptimalAtlasSize(for: images)
                    
                    // Create atlas image
                    let atlasImage = try await self.packImagesIntoAtlas(images, size: atlasSize)
                    
                    // Create Metal texture
                    guard let metalTexture = try await self.createMetalTexture(from: atlasImage) else {
                        throw WinampError.metalResourceCreationFailed(reason: "Failed to create Metal texture")
                    }
                    
                    // Calculate UV coordinates for each image
                    let uvMappings = try await self.calculateUVMappings(for: images, atlasSize: atlasSize)
                    
                    let atlas = MetalTextureAtlas(
                        name: name,
                        texture: metalTexture,
                        uvMappings: uvMappings,
                        size: atlasSize
                    )
                    
                    continuation.resume(returning: atlas)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Calculate optimal atlas size for given images
    private func calculateOptimalAtlasSize(for images: [String: NSImage]) -> CGSize {
        var totalArea: CGFloat = 0
        var maxWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for (_, image) in images {
            let size = image.size
            totalArea += size.width * size.height
            maxWidth = max(maxWidth, size.width)
            maxHeight = max(maxHeight, size.height)
        }
        
        // Calculate square root of total area as starting point
        let baseSize = sqrt(totalArea)
        
        // Ensure atlas is large enough for largest image
        let minAtlasSize = max(maxWidth, maxHeight)
        
        // Use power of 2 sizes for optimal GPU performance
        let atlasSize = max(nextPowerOfTwo(max(baseSize, minAtlasSize)), 256)
        
        return CGSize(width: atlasSize, height: atlasSize)
    }
    
    /// Pack multiple images into a single atlas texture
    private func packImagesIntoAtlas(_ images: [String: NSImage], size: CGSize) async throws -> NSImage {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                // Create atlas image context
                let atlasImage = NSImage(size: size)
                
                atlasImage.lockFocus()
                defer { atlasImage.unlockFocus() }
                
                // Clear background
                NSColor.clear.setFill()
                NSRect(origin: .zero, size: size).fill()
                
                // Simple left-to-right, top-to-bottom packing
                var currentX: CGFloat = 0
                var currentY: CGFloat = 0
                var rowHeight: CGFloat = 0
                
                for (_, image) in images {
                    let imageSize = image.size
                    
                    // Check if image fits in current row
                    if currentX + imageSize.width > size.width {
                        // Move to next row
                        currentX = 0
                        currentY += rowHeight
                        rowHeight = 0
                    }
                    
                    // Check if we have vertical space
                    if currentY + imageSize.height <= size.height {
                        let rect = NSRect(x: currentX, y: currentY, width: imageSize.width, height: imageSize.height)
                        image.draw(in: rect)
                        
                        currentX += imageSize.width
                        rowHeight = max(rowHeight, imageSize.height)
                    }
                }
                
                continuation.resume(returning: atlasImage)
            }
        }
    }
    
    /// Create Metal texture from NSImage
    private func createMetalTexture(from image: NSImage) async throws -> MTLTexture? {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached { [weak self] in
                guard let self = self,
                      let device = self.metalDevice else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                        throw WinampError.metalResourceCreationFailed(reason: "Failed to get CGImage")
                    }
                    
                    let textureLoader = MTKTextureLoader(device: device)
                    let texture = try textureLoader.newTexture(cgImage: cgImage, options: [
                        .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                        .textureStorageMode: MTLStorageMode.shared.rawValue
                    ])
                    
                    continuation.resume(returning: texture)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Calculate UV coordinates for images in atlas
    private func calculateUVMappings(for images: [String: NSImage], atlasSize: CGSize) async throws -> [String: UVMapping] {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                var uvMappings: [String: UVMapping] = [:]
                
                // Recreate the packing logic to calculate positions
                var currentX: CGFloat = 0
                var currentY: CGFloat = 0
                var rowHeight: CGFloat = 0
                
                for (imageName, image) in images {
                    let imageSize = image.size
                    
                    // Check if image fits in current row
                    if currentX + imageSize.width > atlasSize.width {
                        // Move to next row
                        currentX = 0
                        currentY += rowHeight
                        rowHeight = 0
                    }
                    
                    // Check if we have vertical space
                    if currentY + imageSize.height <= atlasSize.height {
                        // Calculate UV coordinates (0.0 to 1.0)
                        let uvMapping = UVMapping(
                            minU: currentX / atlasSize.width,
                            minV: currentY / atlasSize.height,
                            maxU: (currentX + imageSize.width) / atlasSize.width,
                            maxV: (currentY + imageSize.height) / atlasSize.height
                        )
                        
                        uvMappings[imageName] = uvMapping
                        
                        currentX += imageSize.width
                        rowHeight = max(rowHeight, imageSize.height)
                    }
                }
                
                continuation.resume(returning: uvMappings)
            }
        }
    }
    
    // MARK: - Hit-Test Region Creation
    
    /// Create hit-test regions from converted coordinate points
    private func createHitTestRegions(from regions: [String: [CGPoint]]) async throws -> [String: NSBezierPath] {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                var hitTestRegions: [String: NSBezierPath] = [:]
                
                for (regionName, points) in regions {
                    let path = NSBezierPath()
                    
                    if !points.isEmpty {
                        path.move(to: points[0])
                        
                        for i in 1..<points.count {
                            path.line(to: points[i])
                        }
                        
                        path.close()
                    }
                    
                    hitTestRegions[regionName] = path
                }
                
                continuation.resume(returning: hitTestRegions)
            }
        }
    }
    
    // MARK: - macOS Skin Creation
    
    /// Create final macOS skin from converted components
    private func createMacOSSkin(
        from windowsSkin: WinampSkin,
        regions: [String: [CGPoint]],
        images: [String: NSImage],
        atlases: [MetalTextureAtlas],
        hitTestRegions: [String: NSBezierPath]
    ) async throws -> MacOSSkin {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                let macOSSkin = MacOSSkin(
                    id: windowsSkin.id,
                    name: windowsSkin.name,
                    originalSkin: windowsSkin,
                    convertedImages: images,
                    textureAtlases: atlases,
                    hitTestRegions: hitTestRegions,
                    regions: regions,
                    visualizationColors: windowsSkin.configuration.visualizationColors
                )
                
                continuation.resume(returning: macOSSkin)
            }
        }
    }
    
    // MARK: - Progress Updates
    
    @MainActor
    private func updateProgress(_ progress: Double, operation: String) {
        self.conversionProgress = progress
        self.currentOperation = operation
        self.isConverting = progress < 1.0
    }
    
    // MARK: - Utility Functions
    
    private func nextPowerOfTwo(_ value: CGFloat) -> CGFloat {
        return pow(2.0, ceil(log2(value)))
    }
}

// MARK: - Data Structures

/// Metal texture atlas for efficient GPU rendering
public struct MetalTextureAtlas {
    public let name: String
    public let texture: MTLTexture
    public let uvMappings: [String: UVMapping]
    public let size: CGSize
    
    public init(name: String, texture: MTLTexture, uvMappings: [String: UVMapping], size: CGSize) {
        self.name = name
        self.texture = texture
        self.uvMappings = uvMappings
        self.size = size
    }
}

/// UV texture coordinates for atlas mapping
public struct UVMapping {
    public let minU: CGFloat
    public let minV: CGFloat
    public let maxU: CGFloat
    public let maxV: CGFloat
    
    public init(minU: CGFloat, minV: CGFloat, maxU: CGFloat, maxV: CGFloat) {
        self.minU = minU
        self.minV = minV
        self.maxU = maxU
        self.maxV = maxV
    }
    
    public var width: CGFloat { maxU - minU }
    public var height: CGFloat { maxV - minV }
}

/// macOS-optimized skin representation
public struct MacOSSkin: Sendable {
    public let id: String
    public let name: String
    public let originalSkin: WinampSkin
    public let convertedImages: [String: NSImage]
    public let textureAtlases: [MetalTextureAtlas]
    public let hitTestRegions: [String: NSBezierPath]
    public let regions: [String: [CGPoint]]
    public let visualizationColors: [NSColor]
    
    public init(
        id: String,
        name: String,
        originalSkin: WinampSkin,
        convertedImages: [String: NSImage],
        textureAtlases: [MetalTextureAtlas],
        hitTestRegions: [String: NSBezierPath],
        regions: [String: [CGPoint]],
        visualizationColors: [NSColor]
    ) {
        self.id = id
        self.name = name
        self.originalSkin = originalSkin
        self.convertedImages = convertedImages
        self.textureAtlases = textureAtlases
        self.hitTestRegions = hitTestRegions
        self.regions = regions
        self.visualizationColors = visualizationColors
    }
}

// MARK: - Error Extensions

extension WinampError {
    static func conversionFailed(reason: String) -> WinampError {
        return .skinLoadingFailed(reason: .corruptedData)
    }
    
    static func imageConversionFailed(reason: String) -> WinampError {
        return .skinParsingFailed(file: "image", reason: reason)
    }
    
    static func metalResourceCreationFailed(reason: String) -> WinampError {
        return .skinLoadingFailed(reason: .corruptedData)
    }
}