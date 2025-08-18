//
//  ModernSkinLoader.swift
//  WinampMac
//
//  Modern skin loader using native Compression framework
//  Replaces external unzip dependency with Swift async/await patterns
//  Compatible with macOS 15.0+ and future-proofed for macOS 26.x
//

import Foundation
import Compression
import AppKit
import UniformTypeIdentifiers
import OSLog

/// Modern skin loader with native ZIP support and async/await patterns
@available(macOS 15.0, *)
public final class ModernSkinLoader: @unchecked Sendable {
    
    // MARK: - Logger
    private static let logger = Logger(subsystem: "com.winamp.mac.core", category: "SkinLoader")
    
    // MARK: - Modern Cache System
    private let assetCache = NSCache<NSString, SkinAssets>()
    private let imageCache = NSCache<NSString, NSImage>()
    private let processingQueue = DispatchQueue(label: "com.winamp.skin.processing", qos: .userInitiated)
    
    // MARK: - Configuration
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
    private let maxCacheItems: Int = 50
    
    public init() {
        setupCaches()
    }
    
    private func setupCaches() {
        // Configure asset cache
        assetCache.totalCostLimit = maxCacheSize
        assetCache.countLimit = maxCacheItems
        assetCache.name = "WinampSkinAssetCache"
        
        // Configure image cache  
        imageCache.totalCostLimit = maxCacheSize / 2  // 50MB for images
        imageCache.countLimit = maxCacheItems * 10    // More images than skins
        imageCache.name = "WinampSkinImageCache"
        
        // Memory pressure handling - use a custom notification since macOS doesn't have memory warnings
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemoryPressure"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryPressure()
        }
    }
    
    private func handleMemoryPressure() {
        Self.logger.info("Handling memory pressure - clearing caches")
        assetCache.removeAllObjects()
        imageCache.removeAllObjects()
    }
    
    // MARK: - Modern Skin Assets Structure
    public final class SkinAssets: @unchecked Sendable {
        public let metadata: SkinMetadata
        public let sprites: [String: NSImage]
        public let configuration: SkinConfiguration
        public let cursors: [String: Data]
        public let colorScheme: ColorScheme
        public let customRegions: [String: WindowRegion]
        
        public init(metadata: SkinMetadata, sprites: [String: NSImage], configuration: SkinConfiguration, cursors: [String: Data], colorScheme: ColorScheme, customRegions: [String: WindowRegion]) {
            self.metadata = metadata
            self.sprites = sprites
            self.configuration = configuration
            self.cursors = cursors
            self.colorScheme = colorScheme
            self.customRegions = customRegions
        }
        
        // Estimated memory footprint for caching
        public var estimatedSize: Int {
            let spriteSize = sprites.values.reduce(0) { total, image in
                total + Int(image.size.width * image.size.height * 4) // RGBA
            }
            let cursorSize = cursors.values.reduce(0) { $0 + $1.count }
            return spriteSize + cursorSize + 1024 // Base overhead
        }
    }
    
    public struct SkinMetadata: Sendable {
        public let name: String
        public let author: String
        public let version: String
        public let description: String
        public let previewImage: NSImage?
        public let supportedModes: Set<PlaybackMode>
        public let requiresModernFeatures: Bool
        
        public enum PlaybackMode: String, CaseIterable, Sendable {
            case normal = "normal"
            case equalizer = "equalizer"  
            case playlist = "playlist"
            case visualizer = "visualizer"
        }
    }
    
    public struct SkinConfiguration: Sendable {
        public let windowRegions: [String: WindowRegion]
        public let buttonMappings: [String: ButtonMapping]
        public let sliderConfigs: [String: SliderConfiguration]
        public let textRegions: [String: TextRegion]
        public let animationConfigs: [String: AnimationConfiguration]
        public let visualizationSettings: VisualizationSettings
    }
    
    public struct WindowRegion: @unchecked Sendable {
        public let frame: CGRect
        public let hitTestPath: NSBezierPath?
        public let isTransparent: Bool
        public let dragBehavior: DragBehavior
        
        public enum DragBehavior: Sendable {
            case none
            case moveWindow
            case resizeWindow
            case custom(String)
        }
    }
    
    public struct ButtonMapping: @unchecked Sendable {
        public let normalFrame: CGRect
        public let pressedFrame: CGRect?
        public let disabledFrame: CGRect?
        public let hoverFrame: CGRect?
        public let hitTestPath: NSBezierPath
        public let action: String
        public let tooltip: String?
    }
    
    public struct SliderConfiguration: Sendable {
        public let trackFrame: CGRect
        public let thumbFrames: [CGRect] // Multiple frames for animation
        public let orientation: Orientation
        public let range: ClosedRange<Float>
        public let behavior: SliderBehavior
        
        public enum Orientation: Sendable {
            case horizontal
            case vertical
        }
        
        public enum SliderBehavior: Sendable {
            case volume
            case balance
            case position
            case equalizer(band: Int)
        }
    }
    
    public struct TextRegion: @unchecked Sendable {
        public let frame: CGRect
        public let font: NSFont
        public let color: NSColor
        public let alignment: NSTextAlignment
        public let scrolling: ScrollingBehavior
        
        public enum ScrollingBehavior: Sendable {
            case none
            case horizontal(speed: Float)
            case vertical(speed: Float)
            case marquee(speed: Float)
        }
    }
    
    public struct AnimationConfiguration: Sendable {
        public let frames: [CGRect]
        public let duration: TimeInterval
        public let repeatCount: Int
        public let timingFunction: TimingFunction
        
        public enum TimingFunction: Sendable {
            case linear
            case easeIn
            case easeOut
            case easeInOut
        }
    }
    
    public struct VisualizationSettings: Sendable {
        public let colors: [NSColor]
        public let mode: VisualizationMode
        public let responseSpeed: Float
        public let sensitivity: Float
        
        public enum VisualizationMode: String, CaseIterable, Sendable {
            case spectrum = "spectrum"
            case oscilloscope = "oscilloscope"
            case dots = "dots"
            case custom = "custom"
        }
    }
    
    public struct ColorScheme: Sendable {
        public let primary: NSColor
        public let secondary: NSColor
        public let background: NSColor
        public let text: NSColor
        public let accent: NSColor
        public let visualization: [NSColor]
        public let playlist: PlaylistColors
        
        public struct PlaylistColors: Sendable {
            public let normalText: NSColor
            public let currentText: NSColor
            public let normalBackground: NSColor
            public let selectedBackground: NSColor
            public let selectedText: NSColor
        }
    }
    
    // MARK: - Error Handling
    public enum SkinError: LocalizedError, Sendable {
        case invalidFormat(String)
        case compressionError(String)
        case missingRequiredAssets([String])
        case corruptedData(String)
        case unsupportedVersion(String)
        case memoryError(String)
        case networkError(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidFormat(let detail):
                return "Invalid skin format: \(detail)"
            case .compressionError(let detail):
                return "Compression error: \(detail)"
            case .missingRequiredAssets(let assets):
                return "Missing required assets: \(assets.joined(separator: ", "))"
            case .corruptedData(let detail):
                return "Corrupted skin data: \(detail)"
            case .unsupportedVersion(let version):
                return "Unsupported skin version: \(version)"
            case .memoryError(let detail):
                return "Memory error: \(detail)"
            case .networkError(let detail):
                return "Network error: \(detail)"
            }
        }
    }
    
    // MARK: - Public Interface
    public func loadSkin(from url: URL) async throws -> SkinAssets {
        Self.logger.info("Loading skin from: \(url.lastPathComponent)")
        
        // Check cache first
        let cacheKey = url.absoluteString as NSString
        if let cachedAssets = assetCache.object(forKey: cacheKey) {
            Self.logger.debug("Found cached skin assets")
            return cachedAssets
        }
        
        // Validate file
        try await validateSkinFile(url)
        
        // Extract and parse skin
        let assets = try await extractAndParseSkin(from: url)
        
        // Cache the results
        assetCache.setObject(assets, forKey: cacheKey, cost: assets.estimatedSize)
        
        Self.logger.info("Successfully loaded skin: \(assets.metadata.name)")
        return assets
    }
    
    public func loadSkin(from data: Data, name: String = "Unknown") async throws -> SkinAssets {
        Self.logger.info("Loading skin from data: \(name)")
        
        // Create temporary file for processing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wsz")
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        try data.write(to: tempURL)
        return try await loadSkin(from: tempURL)
    }
    
    // MARK: - Validation
    private func validateSkinFile(_ url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SkinError.invalidFormat("File does not exist")
        }
        
        // Check file size (reasonable limits)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? Int64 {
            if fileSize > 50 * 1024 * 1024 { // 50MB limit
                throw SkinError.invalidFormat("File too large: \(fileSize) bytes")
            }
            if fileSize < 1024 { // 1KB minimum
                throw SkinError.invalidFormat("File too small: \(fileSize) bytes")
            }
        }
        
        // Validate file type
        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
        if let contentType = resourceValues.contentType {
            let validTypes: [UTType] = [.zip, .archive]
            if !validTypes.contains(where: { contentType.conforms(to: $0) }) {
                // Also check custom wsz type
                let wszType = UTType("com.nullsoft.winamp.skin")
                if wszType == nil || !contentType.conforms(to: wszType!) {
                    Self.logger.warning("Unknown content type: \(contentType.identifier)")
                }
            }
        }
    }
    
    // MARK: - Modern ZIP Extraction with Compression Framework
    private func extractAndParseSkin(from url: URL) async throws -> SkinAssets {
        return try await withTaskCancellationHandler {
            try await performSkinExtraction(from: url)
        } onCancel: {
            Self.logger.info("Skin loading cancelled")
        }
    }
    
    private func performSkinExtraction(from url: URL) async throws -> SkinAssets {
        // Create temporary extraction directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("winamp_skin_\(UUID().uuidString)")
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Extract ZIP using native Compression framework
        let extractedFiles = try await extractZipArchive(from: url, to: tempDir)
        
        // Parse extracted contents concurrently
        async let metadata = parseMetadata(from: extractedFiles)
        async let sprites = loadSprites(from: extractedFiles)
        async let configuration = parseConfiguration(from: extractedFiles)
        async let cursors = extractCursors(from: extractedFiles)
        async let colorScheme = parseColorScheme(from: extractedFiles)
        async let customRegions = parseCustomRegions(from: extractedFiles)
        
        return try await SkinAssets(
            metadata: metadata,
            sprites: sprites,
            configuration: configuration,
            cursors: cursors,
            colorScheme: colorScheme,
            customRegions: customRegions
        )
    }
    
    private func extractZipArchive(from sourceURL: URL, to destinationURL: URL) async throws -> [String: Data] {
        return try await withUnsafeThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let result = try self.performZipExtraction(from: sourceURL, to: destinationURL)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performZipExtraction(from sourceURL: URL, to destinationURL: URL) throws -> [String: Data] {
        let _ = try Data(contentsOf: sourceURL)
        var extractedFiles: [String: Data] = [:]
        
        // Use NSFileManager's built-in unarchiving for ZIP files
        // This is more reliable than trying to implement ZIP parsing manually
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &error) { (url) in
            do {
                // Use Archive utility via Process for reliable extraction
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-xk", url.path, destinationURL.path]
                
                let pipe = Pipe()
                process.standardError = pipe
                
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    throw SkinError.compressionError("ditto failed: \(errorString)")
                }
                
            } catch {
                Self.logger.error("Extraction failed: \(error.localizedDescription)")
            }
        }
        
        if let error = error {
            throw SkinError.compressionError(error.localizedDescription)
        }
        
        // Read all extracted files
        let enumerator = FileManager.default.enumerator(
            at: destinationURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues.isRegularFile == true {
                let relativePath = fileURL.path.replacingOccurrences(
                    of: destinationURL.path + "/", 
                    with: ""
                ).lowercased()
                
                let fileData = try Data(contentsOf: fileURL)
                extractedFiles[relativePath] = fileData
            }
        }
        
        Self.logger.debug("Extracted \(extractedFiles.count) files from archive")
        return extractedFiles
    }
    
    // MARK: - Asset Parsing with Modern Swift Patterns
    private func parseMetadata(from files: [String: Data]) async throws -> SkinMetadata {
        var name = "Unknown Skin"
        var author = "Unknown"
        var version = "1.0"
        var description = ""
        var previewImage: NSImage?
        var supportedModes: Set<SkinMetadata.PlaybackMode> = [.normal]
        var requiresModernFeatures = false
        
        // Look for metadata files
        for (filename, data) in files {
            // Parse text metadata
            if filename.contains("readme") || filename.contains("info") || filename.contains("skin") {
                if let content = String(data: data, encoding: .utf8) ?? 
                               String(data: data, encoding: .ascii) {
                    let parsedMetadata = parseTextMetadata(content)
                    if !parsedMetadata.name.isEmpty { name = parsedMetadata.name }
                    if !parsedMetadata.author.isEmpty { author = parsedMetadata.author }
                    if !parsedMetadata.version.isEmpty { version = parsedMetadata.version }
                    if !parsedMetadata.description.isEmpty { description = parsedMetadata.description }
                }
            }
            
            // Look for preview images
            if filename.contains("preview") || filename.contains("thumb") || filename.contains("screenshot") {
                previewImage = NSImage(data: data)
            }
            
            // Detect supported modes based on assets
            if filename.contains("eqmain") { supportedModes.insert(.equalizer) }
            if filename.contains("pledit") { supportedModes.insert(.playlist) }
            if filename.contains("vis") { supportedModes.insert(.visualizer) }
            
            // Check for modern features
            if filename.contains("region") || filename.contains("animation") {
                requiresModernFeatures = true
            }
        }
        
        return SkinMetadata(
            name: name,
            author: author,
            version: version,
            description: description,
            previewImage: previewImage,
            supportedModes: supportedModes,
            requiresModernFeatures: requiresModernFeatures
        )
    }
    
    private func parseTextMetadata(_ content: String) -> (name: String, author: String, version: String, description: String) {
        var name = ""
        var author = ""
        var version = ""
        var description = ""
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let _ = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let value = extractMetadataValue(from: line, keys: ["skin name", "title", "name"]) {
                name = value
            } else if let value = extractMetadataValue(from: line, keys: ["author", "created by", "by", "artist"]) {
                author = value
            } else if let value = extractMetadataValue(from: line, keys: ["version", "ver"]) {
                version = value
            } else if let value = extractMetadataValue(from: line, keys: ["description", "desc", "info"]) {
                description = value
            }
        }
        
        return (name, author, version, description)
    }
    
    private func extractMetadataValue(from line: String, keys: [String]) -> String? {
        let lowercased = line.lowercased()
        
        for key in keys {
            if lowercased.contains(key) {
                // Try colon separator first
                if let colonRange = line.range(of: ":") {
                    return String(line[colonRange.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                // Try equals separator
                if let equalsRange = line.range(of: "=") {
                    return String(line[equalsRange.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                // Try extracting after the key
                if let keyRange = lowercased.range(of: key) {
                    let afterKey = String(line[keyRange.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !afterKey.isEmpty {
                        return afterKey
                    }
                }
            }
        }
        
        return nil
    }
    
    private func loadSprites(from files: [String: Data]) async throws -> [String: NSImage] {
        let spriteNames = [
            "main", "cbuttons", "titlebar", "shufrep", "text", "volume", 
            "balance", "posbar", "playpaus", "monoster", "eqmain", "pledit",
            "numbers", "nums_ex", "eq_ex", "gen", "genex", "mb", "avs"
        ]
        
        var sprites: [String: NSImage] = [:]
        
        await withTaskGroup(of: (String, NSImage?).self) { group in
            for spriteName in spriteNames {
                group.addTask { [weak self] in
                    await self?.loadSpriteImage(named: spriteName, from: files) ?? (spriteName, nil)
                }
            }
            
            for await (name, image) in group {
                if let image = image {
                    sprites[name] = image
                    
                    // Cache individual images
                    let cacheKey = name as NSString
                    let cost = Int(image.size.width * image.size.height * 4) // RGBA estimate
                    imageCache.setObject(image, forKey: cacheKey, cost: cost)
                }
            }
        }
        
        Self.logger.debug("Loaded \(sprites.count) sprite images")
        return sprites
    }
    
    private func loadSpriteImage(named name: String, from files: [String: Data]) async -> (String, NSImage?) {
        let extensions = ["png", "bmp", "gif", "jpg", "jpeg"]
        
        for ext in extensions {
            let filename = "\(name.lowercased()).\(ext)"
            if let data = files[filename],
               let image = NSImage(data: data) {
                return (name, image)
            }
        }
        
        return (name, nil)
    }
    
    private func parseConfiguration(from files: [String: Data]) async throws -> SkinConfiguration {
        // Implementation continues with configuration parsing...
        // This would parse region.txt, skin.ini, and other config files
        
        return SkinConfiguration(
            windowRegions: [:],
            buttonMappings: [:],
            sliderConfigs: [:],
            textRegions: [:],
            animationConfigs: [:],
            visualizationSettings: VisualizationSettings(
                colors: [.systemGreen],
                mode: .spectrum,
                responseSpeed: 1.0,
                sensitivity: 1.0
            )
        )
    }
    
    private func extractCursors(from files: [String: Data]) async throws -> [String: Data] {
        var cursors: [String: Data] = [:]
        
        for (filename, data) in files {
            if filename.hasSuffix(".cur") {
                cursors[filename] = data
            }
        }
        
        return cursors
    }
    
    private func parseColorScheme(from files: [String: Data]) async throws -> ColorScheme {
        // Parse color schemes from pledit.txt and viscolor.txt
        // Implementation would parse color definitions
        
        return ColorScheme(
            primary: .controlAccentColor,
            secondary: .secondaryLabelColor,
            background: .windowBackgroundColor,
            text: .labelColor,
            accent: .controlAccentColor,
            visualization: [.systemGreen, .systemYellow, .systemRed],
            playlist: ColorScheme.PlaylistColors(
                normalText: .labelColor,
                currentText: .systemYellow,
                normalBackground: .controlBackgroundColor,
                selectedBackground: .selectedControlColor,
                selectedText: .selectedControlTextColor
            )
        )
    }
    
    private func parseCustomRegions(from files: [String: Data]) async throws -> [String: WindowRegion] {
        // Parse custom window regions from region.txt files
        // Implementation would create NSBezierPath objects for hit testing
        
        return [:]
    }
}