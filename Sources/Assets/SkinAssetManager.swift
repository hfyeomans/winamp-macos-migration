import Foundation
import Metal
import MetalKit
import Compression
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Modern asset pipeline with NSCache optimization and progressive loading
/// Handles WSZ files, color space conversion, and memory-efficient texture management
class SkinAssetManager {
    
    // MARK: - Properties
    private let device: MTLDevice
    private let textureLoader: MTKTextureLoader
    
    // Multi-level caching system
    private let textureCache = NSCache<NSString, MTLTexture>()
    private let imageCache = NSCache<NSString, CGImage>()
    private let skinDataCache = NSCache<NSString, SkinData>()
    
    // Asset processing queues
    private let assetProcessingQueue = DispatchQueue(label: "skin.asset.processing", qos: .utility)
    private let textureCreationQueue = DispatchQueue(label: "skin.texture.creation", qos: .userInitiated)
    
    // Progressive loading
    private var loadingTasks: [String: Task<MTLTexture?, Error>] = [:]
    private let loadingQueue = DispatchQueue(label: "skin.loading", qos: .userInitiated)
    
    // Color space management
    private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let displayP3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3)
    
    init(device: MTLDevice) {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)
        
        configureCache()
    }
    
    private func configureCache() {
        // Configure texture cache (primary bottleneck)
        textureCache.countLimit = 200
        textureCache.totalCostLimit = 512 * 1024 * 1024 // 512MB for textures
        textureCache.evictsObjectsWithDiscardedContent = true
        
        // Configure image cache for intermediate processing
        imageCache.countLimit = 100
        imageCache.totalCostLimit = 256 * 1024 * 1024 // 256MB for images
        
        // Configure skin data cache
        skinDataCache.countLimit = 10
        skinDataCache.totalCostLimit = 64 * 1024 * 1024 // 64MB for parsed skin data
        
        // Memory pressure handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryPressure),
            name: NSApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryPressure() {
        // Clear caches on memory pressure
        assetProcessingQueue.async {
            self.textureCache.removeAllObjects()
            self.imageCache.removeAllObjects()
            // Keep skin data cache for faster reload
        }
    }
    
    // MARK: - WSZ File Processing
    
    /// Load and process WSZ file with modern Compression framework
    func loadSkinFromWSZ(url: URL) async throws -> SkinData {
        let cacheKey = url.path as NSString
        
        // Check cache first
        if let cachedSkin = skinDataCache.object(forKey: cacheKey) {
            return cachedSkin
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            assetProcessingQueue.async {
                do {
                    let skinData = try self.processWSZFile(at: url)
                    
                    // Cache the result
                    let cost = skinData.estimatedMemoryFootprint
                    self.skinDataCache.setObject(skinData, forKey: cacheKey, cost: cost)
                    
                    continuation.resume(returning: skinData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func processWSZFile(at url: URL) throws -> SkinData {
        // Read file data
        let fileData = try Data(contentsOf: url)
        
        // Decompress using modern Compression framework
        let decompressedData = try decompressData(fileData)
        
        // Parse skin structure
        let skinStructure = try parseSkinStructure(from: decompressedData)
        
        // Extract textures and create skin data
        let skinData = try createSkinData(from: skinStructure, sourceURL: url)
        
        return skinData
    }
    
    private func decompressData(_ data: Data) throws -> Data {
        // Use modern Compression framework instead of deprecated methods
        return try data.withUnsafeBytes { bytes in
            let buffer = UnsafeRawBufferPointer(bytes)
            
            // Try different compression algorithms
            for algorithm in [COMPRESSION_LZFSE, COMPRESSION_ZLIB, COMPRESSION_LZMA] {
                if let decompressed = try? Data(buffer).decompressed(using: algorithm) {
                    return decompressed
                }
            }
            
            // If no compression detected, return original data
            return data
        }
    }
    
    private func parseSkinStructure(from data: Data) throws -> SkinStructure {
        // Parse the decompressed WSZ structure
        // This would implement the specific WSZ format parsing
        let parser = WSZParser(data: data)
        return try parser.parse()
    }
    
    private func createSkinData(from structure: SkinStructure, sourceURL: URL) throws -> SkinData {
        let skinData = SkinData(
            identifier: sourceURL.lastPathComponent,
            sourceURL: sourceURL,
            structure: structure,
            creationDate: Date()
        )
        
        return skinData
    }
    
    // MARK: - Progressive Texture Loading
    
    /// Load texture with progressive enhancement and color space conversion
    func loadTexture(named: String, from skinData: SkinData, priority: TaskPriority = .medium) async throws -> MTLTexture {
        let cacheKey = "\(skinData.identifier)_\(named)" as NSString
        
        // Check cache first
        if let cachedTexture = textureCache.object(forKey: cacheKey) {
            return cachedTexture
        }
        
        // Check if already loading
        if let existingTask = loadingTasks[cacheKey as String] {
            return try await existingTask.value ?? MTLTexture()
        }
        
        // Create new loading task
        let task = Task(priority: priority) {
            return try await self.createTexture(named: named, from: skinData, cacheKey: cacheKey)
        }
        
        loadingTasks[cacheKey as String] = task
        
        defer {
            loadingTasks.removeValue(forKey: cacheKey as String)
        }
        
        return try await task.value ?? MTLTexture()
    }
    
    private func createTexture(named: String, from skinData: SkinData, cacheKey: NSString) async throws -> MTLTexture {
        // Extract image data from skin
        guard let imageData = skinData.getImageData(for: named) else {
            throw AssetError.imageNotFound(named)
        }
        
        // Process image with color space conversion
        let processedImage = try await processImageForMetal(imageData)
        
        // Create Metal texture
        let texture = try await createMetalTexture(from: processedImage)
        
        // Cache the result
        let textureCost = texture.width * texture.height * 4 // Estimate 4 bytes per pixel
        textureCache.setObject(texture, forKey: cacheKey, cost: textureCost)
        
        return texture
    }
    
    private func processImageForMetal(_ imageData: Data) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            textureCreationQueue.async {
                do {
                    guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
                          let originalImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                        throw AssetError.imageProcessingFailed
                    }
                    
                    // Convert color space for Windows -> macOS compatibility
                    let processedImage = try self.convertColorSpace(originalImage)
                    
                    continuation.resume(returning: processedImage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func convertColorSpace(_ image: CGImage) throws -> CGImage {
        // Handle Windows RGB -> macOS sRGB conversion
        let targetColorSpace: CGColorSpace
        
        // Use P3 color space if available and beneficial
        if let p3ColorSpace = displayP3ColorSpace,
           device.supportsFamily(.apple4) { // Apple Silicon optimization
            targetColorSpace = p3ColorSpace
        } else {
            targetColorSpace = sRGBColorSpace
        }
        
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: targetColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw AssetError.colorSpaceConversionFailed
        }
        
        // Set high-quality interpolation
        context.interpolationQuality = .high
        
        // Draw and convert
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        
        guard let convertedImage = context.makeImage() else {
            throw AssetError.colorSpaceConversionFailed
        }
        
        return convertedImage
    }
    
    private func createMetalTexture(from image: CGImage) async throws -> MTLTexture {
        return try await withCheckedThrowingContinuation { continuation in
            let options: [MTKTextureLoader.Option: Any] = [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
                .generateMipmaps: true,
                .SRGB: false // We handle color space conversion manually
            ]
            
            textureLoader.newTexture(cgImage: image, options: options) { texture, error in
                if let texture = texture {
                    continuation.resume(returning: texture)
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: AssetError.textureCreationFailed)
                }
            }
        }
    }
    
    // MARK: - Sprite Atlas Generation
    
    /// Create optimized sprite atlas for batched rendering
    func createSpriteAtlas(from skinData: SkinData, atlasSize: Int = 2048) async throws -> (MTLTexture, [String: CGRect]) {
        let cacheKey = "\(skinData.identifier)_atlas_\(atlasSize)" as NSString
        
        if let cachedAtlas = textureCache.object(forKey: cacheKey) {
            // Return cached atlas with stored coordinates
            let coordinatesKey = "\(cacheKey)_coords"
            if let coordsData = UserDefaults.standard.data(forKey: coordinatesKey),
               let coordinates = try? JSONDecoder().decode([String: CGRect].self, from: coordsData) {
                return (cachedAtlas, coordinates)
            }
        }
        
        return try await createNewSpriteAtlas(skinData: skinData, atlasSize: atlasSize, cacheKey: cacheKey)
    }
    
    private func createNewSpriteAtlas(skinData: SkinData, atlasSize: Int, cacheKey: NSString) async throws -> (MTLTexture, [String: CGRect]) {
        // Load all images for the skin
        let imageNames = skinData.getAllImageNames()
        var images: [String: CGImage] = [:]
        
        // Load images concurrently
        try await withThrowingTaskGroup(of: (String, CGImage).self) { group in
            for imageName in imageNames {
                group.addTask {
                    let imageData = skinData.getImageData(for: imageName)!
                    let image = try await self.processImageForMetal(imageData)
                    return (imageName, image)
                }
            }
            
            for try await (name, image) in group {
                images[name] = image
            }
        }
        
        // Pack images into atlas using bin packing algorithm
        let (packedAtlas, coordinates) = try await packImagesIntoAtlas(images: images, atlasSize: atlasSize)
        
        // Cache the atlas
        let cost = atlasSize * atlasSize * 4
        textureCache.setObject(packedAtlas, forKey: cacheKey, cost: cost)
        
        // Store coordinates for retrieval
        let coordinatesKey = "\(cacheKey)_coords"
        if let coordsData = try? JSONEncoder().encode(coordinates) {
            UserDefaults.standard.set(coordsData, forKey: coordinatesKey)
        }
        
        return (packedAtlas, coordinates)
    }
    
    private func packImagesIntoAtlas(images: [String: CGImage], atlasSize: Int) async throws -> (MTLTexture, [String: CGRect]) {
        // Simple bin packing implementation
        var coordinates: [String: CGRect] = [:]
        var currentX = 0
        var currentY = 0
        var rowHeight = 0
        
        // Create atlas texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: atlasSize,
            height: atlasSize,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .renderTarget]
        textureDescriptor.storageMode = .private
        
        guard let atlas = device.makeTexture(descriptor: textureDescriptor) else {
            throw AssetError.textureCreationFailed
        }
        
        // Create render pass to draw images into atlas
        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw AssetError.metalResourceCreationFailed
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = atlas
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw AssetError.metalResourceCreationFailed
        }
        
        // Pack each image
        for (name, image) in images.sorted(by: { $0.value.height > $1.value.height }) {
            let imageWidth = image.width
            let imageHeight = image.height
            
            // Check if image fits in current row
            if currentX + imageWidth > atlasSize {
                currentX = 0
                currentY += rowHeight
                rowHeight = 0
            }
            
            // Check if image fits in atlas
            if currentY + imageHeight > atlasSize {
                print("Warning: Image \(name) doesn't fit in atlas")
                continue
            }
            
            // Record coordinates (normalized to 0-1 range)
            coordinates[name] = CGRect(
                x: Double(currentX) / Double(atlasSize),
                y: Double(currentY) / Double(atlasSize),
                width: Double(imageWidth) / Double(atlasSize),
                height: Double(imageHeight) / Double(atlasSize)
            )
            
            // TODO: Use blit encoder to copy image data to atlas
            // This would require converting CGImage to MTLTexture first
            
            currentX += imageWidth
            rowHeight = max(rowHeight, imageHeight)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return (atlas, coordinates)
    }
    
    // MARK: - Memory Management
    
    func preloadSkinAssets(_ skinData: SkinData, priority: [String] = []) async {
        // Preload high-priority assets first
        await withTaskGroup(of: Void.self) { group in
            for assetName in priority {
                group.addTask {
                    try? await self.loadTexture(named: assetName, from: skinData, priority: .high)
                }
            }
        }
        
        // Then load remaining assets at lower priority
        let allAssets = Set(skinData.getAllImageNames())
        let remainingAssets = allAssets.subtracting(Set(priority))
        
        await withTaskGroup(of: Void.self) { group in
            for assetName in remainingAssets {
                group.addTask {
                    try? await self.loadTexture(named: assetName, from: skinData, priority: .low)
                }
            }
        }
    }
    
    func clearCache() {
        textureCache.removeAllObjects()
        imageCache.removeAllObjects()
        skinDataCache.removeAllObjects()
        loadingTasks.removeAll()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        clearCache()
    }
}

// MARK: - Supporting Types

struct SkinData {
    let identifier: String
    let sourceURL: URL
    let structure: SkinStructure
    let creationDate: Date
    
    var estimatedMemoryFootprint: Int {
        // Estimate based on number of images and average size
        return structure.images.count * 256 * 256 * 4 // Rough estimate
    }
    
    func getImageData(for name: String) -> Data? {
        return structure.images[name]
    }
    
    func getAllImageNames() -> [String] {
        return Array(structure.images.keys)
    }
}

struct SkinStructure {
    let images: [String: Data]
    let configuration: SkinConfiguration
    let metadata: [String: Any]
}

struct SkinConfiguration: Codable {
    let windowSize: CGSize
    let buttonPositions: [String: CGRect]
    let colors: [String: String]
    let animations: [String: AnimationData]
}

struct AnimationData: Codable {
    let frames: [String]
    let duration: Double
    let looping: Bool
}

// Mock WSZ parser - would need actual implementation
class WSZParser {
    private let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    func parse() throws -> SkinStructure {
        // TODO: Implement actual WSZ parsing
        // This is a placeholder that would parse the WSZ format
        return SkinStructure(
            images: [:],
            configuration: SkinConfiguration(
                windowSize: CGSize(width: 400, height: 300),
                buttonPositions: [:],
                colors: [:],
                animations: [:]
            ),
            metadata: [:]
        )
    }
}

// MARK: - Error Types

enum AssetError: Error, LocalizedError {
    case imageNotFound(String)
    case imageProcessingFailed
    case colorSpaceConversionFailed
    case textureCreationFailed
    case metalResourceCreationFailed
    case cacheError(String)
    
    var errorDescription: String? {
        switch self {
        case .imageNotFound(let name):
            return "Image '\(name)' not found in skin data"
        case .imageProcessingFailed:
            return "Failed to process image data"
        case .colorSpaceConversionFailed:
            return "Failed to convert image color space"
        case .textureCreationFailed:
            return "Failed to create Metal texture"
        case .metalResourceCreationFailed:
            return "Failed to create Metal resources"
        case .cacheError(let message):
            return "Cache error: \(message)"
        }
    }
}

// MARK: - Data Extensions

extension Data {
    func decompressed(using algorithm: compression_algorithm) throws -> Data {
        return try self.withUnsafeBytes { bytes in
            let buffer = UnsafeRawBufferPointer(bytes)
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count * 4)
            defer { destinationBuffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                destinationBuffer, count * 4,
                buffer.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, algorithm
            )
            
            guard decompressedSize > 0 else {
                throw AssetError.imageProcessingFailed
            }
            
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }
    }
}