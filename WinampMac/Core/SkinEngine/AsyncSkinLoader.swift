import Foundation
import Compression
import AppKit
import UniformTypeIdentifiers

/// Modern async/await skin loader with Compression framework and NSCache
/// Optimized for macOS 15+ with comprehensive error handling
public actor AsyncSkinLoader {
    
    // MARK: - Configuration
    private let cacheManager: SkinCacheManager
    private let compressionQueue: DispatchQueue
    private let processingQueue: DispatchQueue
    
    // MARK: - State Management
    private var loadingTasks: [String: Task<WinampSkin, Error>] = [:]
    
    public init() {
        self.cacheManager = SkinCacheManager()
        self.compressionQueue = DispatchQueue(label: "com.winamp.compression", qos: .userInitiated)
        self.processingQueue = DispatchQueue(label: "com.winamp.processing", qos: .userInitiated, attributes: .concurrent)
    }
    
    // MARK: - Public Interface
    
    /// Load a Winamp skin from a .wsz file with caching
    public func loadSkin(from url: URL) async throws -> WinampSkin {
        let skinID = url.lastPathComponent
        
        // Check if already loading
        if let existingTask = loadingTasks[skinID] {
            return try await existingTask.value
        }
        
        // Check cache first
        if let cachedSkin = await cacheManager.getCachedSkin(id: skinID) {
            return cachedSkin
        }
        
        // Create loading task
        let task = Task<WinampSkin, Error> {
            do {
                let skin = try await performSkinLoading(from: url)
                await cacheManager.cacheSkin(skin, id: skinID)
                return skin
            } catch {
                await ErrorReporter.shared.reportError(
                    .skinLoadingFailed(reason: .invalidArchive),
                    context: "Loading skin from: \(url.path)"
                )
                throw error
            }
        }
        
        loadingTasks[skinID] = task
        
        defer {
            Task {
                await cleanupLoadingTask(skinID)
            }
        }
        
        return try await task.value
    }
    
    /// Preload multiple skins in background
    public func preloadSkins(from urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        _ = try await self.loadSkin(from: url)
                    } catch {
                        // Silently ignore preloading errors
                    }
                }
            }
        }
    }
    
    /// Clear all cached skins
    public func clearCache() async {
        await cacheManager.clearCache()
    }
    
    // MARK: - Private Implementation
    
    private func performSkinLoading(from url: URL) async throws -> WinampSkin {
        // Validate file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WinampError.fileNotFound(path: url.path)
        }
        
        // Check file size (reasonable limit: 50MB)
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        guard fileSize < 50_000_000 else {
            throw WinampError.skinLoadingFailed(reason: .corruptedData)
        }
        
        // Extract archive
        let extractedContents = try await extractSkinArchive(from: url)
        
        // Parse skin configuration
        let skinConfig = try await parseSkinConfiguration(from: extractedContents)
        
        // Extract bitmaps and resources
        let skinResources = try await extractSkinResources(from: extractedContents, config: skinConfig)
        
        // Create final skin object
        return WinampSkin(
            id: url.lastPathComponent,
            name: skinConfig.name,
            configuration: skinConfig,
            resources: skinResources,
            sourceURL: url
        )
    }
    
    private func extractSkinArchive(from url: URL) async throws -> [String: Data] {
        return try await withCheckedThrowingContinuation { continuation in
            compressionQueue.async {
                do {
                    let archiveData = try Data(contentsOf: url)
                    let extractedFiles = try self.extractZipArchive(data: archiveData)
                    continuation.resume(returning: extractedFiles)
                } catch {
                    continuation.resume(throwing: WinampError.compressionFailed(reason: error.localizedDescription))
                }
            }
        }
    }
    
    private func extractZipArchive(data: Data) throws -> [String: Data] {
        var extractedFiles: [String: Data] = [:]
        
        // Use native Compression framework for .wsz (ZIP) extraction
        try data.withUnsafeBytes { bytes in
            guard let buffer = bytes.bindMemory(to: UInt8.self).baseAddress else {
                throw WinampError.compressionFailed(reason: "Invalid archive data")
            }
            
            // Parse ZIP file structure manually for better control
            var currentOffset = 0
            let totalSize = data.count
            
            while currentOffset < totalSize - 30 { // Minimum ZIP local header size
                // Check for local file header signature (0x04034b50)
                let signature = UInt32(buffer[currentOffset]) |
                               (UInt32(buffer[currentOffset + 1]) << 8) |
                               (UInt32(buffer[currentOffset + 2]) << 16) |
                               (UInt32(buffer[currentOffset + 3]) << 24)
                
                guard signature == 0x04034b50 else {
                    currentOffset += 1
                    continue
                }
                
                // Parse local file header
                let fileNameLength = Int(UInt16(buffer[currentOffset + 26]) | (UInt16(buffer[currentOffset + 27]) << 8))
                let extraFieldLength = Int(UInt16(buffer[currentOffset + 28]) | (UInt16(buffer[currentOffset + 29]) << 8))
                let compressedSize = Int(UInt32(buffer[currentOffset + 18]) |
                                        (UInt32(buffer[currentOffset + 19]) << 8) |
                                        (UInt32(buffer[currentOffset + 20]) << 16) |
                                        (UInt32(buffer[currentOffset + 21]) << 24))
                
                let compressionMethod = UInt16(buffer[currentOffset + 8]) | (UInt16(buffer[currentOffset + 9]) << 8)
                
                // Extract file name
                let fileNameStart = currentOffset + 30
                let fileNameData = Data(bytes: buffer + fileNameStart, count: fileNameLength)
                guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                    currentOffset = fileNameStart + fileNameLength + extraFieldLength + compressedSize
                    continue
                }
                
                // Skip directory entries
                guard !fileName.hasSuffix("/") else {
                    currentOffset = fileNameStart + fileNameLength + extraFieldLength + compressedSize
                    continue
                }
                
                // Extract file data
                let fileDataStart = fileNameStart + fileNameLength + extraFieldLength
                let compressedData = Data(bytes: buffer + fileDataStart, count: compressedSize)
                
                // Decompress if needed
                let fileData: Data
                if compressionMethod == 0 {
                    // No compression
                    fileData = compressedData
                } else if compressionMethod == 8 {
                    // Deflate compression
                    fileData = try compressedData.decompressed(using: .zlib)
                } else {
                    throw WinampError.compressionFailed(reason: "Unsupported compression method: \(compressionMethod)")
                }
                
                extractedFiles[fileName.lowercased()] = fileData
                currentOffset = fileDataStart + compressedSize
            }
        }
        
        guard !extractedFiles.isEmpty else {
            throw WinampError.skinLoadingFailed(reason: .invalidArchive)
        }
        
        return extractedFiles
    }
    
    private func parseSkinConfiguration(from files: [String: Data]) async throws -> SkinConfiguration {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let config = try self.parseConfigurationFiles(files)
                    continuation.resume(returning: config)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func parseConfigurationFiles(_ files: [String: Data]) throws -> SkinConfiguration {
        var config = SkinConfiguration()
        
        // Parse region.txt for window shapes
        if let regionData = files["region.txt"] {
            config.regions = try parseRegionFile(data: regionData)
        }
        
        // Parse pledit.txt for playlist configuration  
        if let pleditData = files["pledit.txt"] {
            config.playlistConfig = try parsePlaylistConfig(data: pleditData)
        }
        
        // Parse viscolor.txt for visualization colors
        if let viscolorData = files["viscolor.txt"] {
            config.visualizationColors = try parseVisualizationColors(data: viscolorData)
        }
        
        // Look for readme or info files for skin name
        for fileName in files.keys {
            if fileName.contains("readme") || fileName.contains("info") {
                if let data = files[fileName],
                   let content = String(data: data, encoding: .utf8) {
                    config.name = extractSkinName(from: content) ?? config.name
                    break
                }
            }
        }
        
        return config
    }
    
    private func parseRegionFile(data: Data) throws -> [String: [CGPoint]] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw WinampError.skinParsingFailed(file: "region.txt", reason: "Invalid text encoding")
        }
        
        var regions: [String: [CGPoint]] = [:]
        let lines = content.components(separatedBy: .newlines)
        
        var currentRegion: String?
        var currentPoints: [CGPoint] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // Check if this is a region name
            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                // Save previous region
                if let regionName = currentRegion, !currentPoints.isEmpty {
                    regions[regionName] = currentPoints
                }
                
                // Start new region
                currentRegion = String(trimmedLine.dropFirst().dropLast())
                currentPoints = []
                continue
            }
            
            // Parse point coordinates
            let components = trimmedLine.components(separatedBy: ",")
            if components.count >= 2,
               let x = Int(components[0].trimmingCharacters(in: .whitespaces)),
               let y = Int(components[1].trimmingCharacters(in: .whitespaces)) {
                currentPoints.append(CGPoint(x: x, y: y))
            }
        }
        
        // Save final region
        if let regionName = currentRegion, !currentPoints.isEmpty {
            regions[regionName] = currentPoints
        }
        
        return regions
    }
    
    private func parsePlaylistConfig(data: Data) throws -> PlaylistConfiguration {
        guard let content = String(data: data, encoding: .utf8) else {
            throw WinampError.skinParsingFailed(file: "pledit.txt", reason: "Invalid text encoding")
        }
        
        var config = PlaylistConfiguration()
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            let components = trimmedLine.components(separatedBy: "=")
            if components.count == 2 {
                let key = components[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = components[1].trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "numex":
                    if let rect = parseRect(from: value) {
                        config.numberDisplayRect = rect
                    }
                case "titletext":
                    if let rect = parseRect(from: value) {
                        config.titleTextRect = rect
                    }
                case "font":
                    config.fontName = value
                default:
                    break
                }
            }
        }
        
        return config
    }
    
    private func parseVisualizationColors(data: Data) throws -> [NSColor] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw WinampError.skinParsingFailed(file: "viscolor.txt", reason: "Invalid text encoding")
        }
        
        var colors: [NSColor] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            let components = trimmedLine.components(separatedBy: ",")
            if components.count >= 3,
               let r = Int(components[0].trimmingCharacters(in: .whitespaces)),
               let g = Int(components[1].trimmingCharacters(in: .whitespaces)),
               let b = Int(components[2].trimmingCharacters(in: .whitespaces)) {
                
                let color = NSColor(
                    red: CGFloat(r) / 255.0,
                    green: CGFloat(g) / 255.0,
                    blue: CGFloat(b) / 255.0,
                    alpha: 1.0
                )
                colors.append(color)
            }
        }
        
        return colors
    }
    
    private func parseRect(from string: String) -> CGRect? {
        let components = string.components(separatedBy: ",")
        guard components.count >= 4,
              let x = Int(components[0].trimmingCharacters(in: .whitespaces)),
              let y = Int(components[1].trimmingCharacters(in: .whitespaces)),
              let width = Int(components[2].trimmingCharacters(in: .whitespaces)),
              let height = Int(components[3].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func extractSkinName(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for common patterns
            if trimmedLine.lowercased().hasPrefix("name:") ||
               trimmedLine.lowercased().hasPrefix("title:") ||
               trimmedLine.lowercased().hasPrefix("skin:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // If no explicit name, use first non-empty line
            if !trimmedLine.isEmpty && trimmedLine.count > 3 && trimmedLine.count < 100 {
                return trimmedLine
            }
        }
        
        return nil
    }
    
    private func extractSkinResources(from files: [String: Data], config: SkinConfiguration) async throws -> SkinResources {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let resources = try self.processResourceFiles(files, config: config)
                    continuation.resume(returning: resources)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func processResourceFiles(_ files: [String: Data], config: SkinConfiguration) throws -> SkinResources {
        var resources = SkinResources()
        
        // Process bitmap files
        let bitmapFiles = ["main.bmp", "eqmain.bmp", "pledit.bmp", "mb.bmp", "avs.bmp"]
        
        for bitmapFile in bitmapFiles {
            if let bitmapData = files[bitmapFile] {
                let image = try createImage(from: bitmapData)
                resources.bitmaps[bitmapFile] = image
            }
        }
        
        // Ensure main.bmp exists
        guard resources.bitmaps["main.bmp"] != nil else {
            throw WinampError.skinLoadingFailed(reason: .missingMainBitmap)
        }
        
        // Process cursor files
        for (fileName, data) in files {
            if fileName.hasSuffix(".cur") {
                let cursor = try createCursor(from: data)
                resources.cursors[fileName] = cursor
            }
        }
        
        return resources
    }
    
    private func createImage(from data: Data) throws -> NSImage {
        guard let image = NSImage(data: data) else {
            throw WinampError.skinParsingFailed(file: "bitmap", reason: "Invalid image data")
        }
        return image
    }
    
    private func createCursor(from data: Data) throws -> NSCursor {
        guard let image = NSImage(data: data) else {
            throw WinampError.skinParsingFailed(file: "cursor", reason: "Invalid cursor data")
        }
        return NSCursor(image: image, hotSpot: CGPoint(x: 0, y: 0))
    }
    
    private func cleanupLoadingTask(_ skinID: String) {
        loadingTasks.removeValue(forKey: skinID)
    }
}

// MARK: - Data Decompression Extension
private extension Data {
    func decompressed(using algorithm: NSData.CompressionAlgorithm) throws -> Data {
        return try (self as NSData).decompressed(using: algorithm) as Data
    }
}

// MARK: - Cache Manager
@globalActor
public actor SkinCacheActor {
    public static let shared = SkinCacheActor()
}

@SkinCacheActor
public final class SkinCacheManager {
    private let cache = NSCache<NSString, CachedSkin>()
    private let maxCacheSize: Int = 100_000_000 // 100MB
    
    private final class CachedSkin {
        let skin: WinampSkin
        let timestamp: Date
        let size: Int
        
        init(skin: WinampSkin, size: Int) {
            self.skin = skin
            self.timestamp = Date()
            self.size = size
        }
    }
    
    public init() {
        cache.countLimit = 20 // Maximum 20 skins in cache
        cache.totalCostLimit = maxCacheSize
    }
    
    public func getCachedSkin(id: String) -> WinampSkin? {
        return cache.object(forKey: id as NSString)?.skin
    }
    
    public func cacheSkin(_ skin: WinampSkin, id: String) {
        let estimatedSize = estimateSkinSize(skin)
        let cachedSkin = CachedSkin(skin: skin, size: estimatedSize)
        cache.setObject(cachedSkin, forKey: id as NSString, cost: estimatedSize)
    }
    
    public func clearCache() {
        cache.removeAllObjects()
    }
    
    private func estimateSkinSize(_ skin: WinampSkin) -> Int {
        var totalSize = 0
        
        for (_, image) in skin.resources.bitmaps {
            if let imageRep = image.representations.first {
                totalSize += imageRep.pixelsWide * imageRep.pixelsHigh * 4 // Assume 4 bytes per pixel
            }
        }
        
        return max(totalSize, 1024) // Minimum 1KB
    }
}

// MARK: - Data Structures
public struct WinampSkin: Sendable {
    public let id: String
    public let name: String
    public let configuration: SkinConfiguration
    public let resources: SkinResources
    public let sourceURL: URL
    
    public init(id: String, name: String, configuration: SkinConfiguration, resources: SkinResources, sourceURL: URL) {
        self.id = id
        self.name = name
        self.configuration = configuration
        self.resources = resources
        self.sourceURL = sourceURL
    }
}

public struct SkinConfiguration: Sendable {
    public var name: String = "Unknown Skin"
    public var regions: [String: [CGPoint]] = [:]
    public var playlistConfig: PlaylistConfiguration = PlaylistConfiguration()
    public var visualizationColors: [NSColor] = []
    
    public init() {}
}

public struct PlaylistConfiguration: Sendable {
    public var numberDisplayRect: CGRect = .zero
    public var titleTextRect: CGRect = .zero
    public var fontName: String = "Arial"
    
    public init() {}
}

public struct SkinResources: Sendable {
    public var bitmaps: [String: NSImage] = [:]
    public var cursors: [String: NSCursor] = [:]
    
    public init() {}
}

// MARK: - NSColor Sendable Conformance
extension NSColor: @unchecked Sendable {}
extension NSImage: @unchecked Sendable {}
extension NSCursor: @unchecked Sendable {}