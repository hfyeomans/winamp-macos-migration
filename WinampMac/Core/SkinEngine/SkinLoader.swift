//
//  SkinLoader.swift
//  WinampMac
//
//  Handles loading and parsing of Winamp .wsz skin files
//

import Foundation
import AppKit
import Compression

/// Loads and parses Winamp skin files (.wsz format)
public class SkinLoader {
    
    /// Represents loaded skin assets
    public struct SkinAssets {
        let sprites: [String: NSImage]
        let configuration: SkinConfiguration
        let cursors: [String: NSCursor]
        let metadata: SkinMetadata
    }
    
    /// Skin configuration from INI files
    public struct SkinConfiguration {
        let windowSize: CGSize
        let visualizationColors: [NSColor]
        let playlistColors: PlaylistColors
        
        struct PlaylistColors {
            let normalText: NSColor
            let currentText: NSColor
            let normalBackground: NSColor
            let selectedBackground: NSColor
        }
    }
    
    /// Skin metadata
    public struct SkinMetadata {
        let name: String
        let author: String?
        let version: String?
        let comment: String?
    }
    
    /// Errors that can occur during skin loading
    public enum SkinError: Error {
        case invalidFormat
        case missingMainBitmap
        case corruptedArchive
        case unsupportedVersion
    }
    
    /// Loads a skin from a .wsz file
    /// - Parameter url: URL to the .wsz file
    /// - Returns: Loaded skin assets
    public func loadSkin(from url: URL) async throws -> SkinAssets {
        // Verify file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SkinError.invalidFormat
        }
        
        // Extract ZIP archive
        let extractedPath = try await extractArchive(from: url)
        
        // Parse configuration files
        let configuration = try await parseConfiguration(at: extractedPath)
        
        // Load sprite assets
        let sprites = try await loadSprites(from: extractedPath)
        
        // Load cursor files
        let cursors = try await loadCursors(from: extractedPath)
        
        // Parse metadata
        let metadata = try await parseMetadata(from: extractedPath)
        
        return SkinAssets(
            sprites: sprites,
            configuration: configuration,
            cursors: cursors,
            metadata: metadata
        )
    }
    
    // MARK: - Private Methods
    
    private func extractArchive(from url: URL) async throws -> URL {
        // Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // TODO: Implement ZIP extraction
        // For now, return the temp directory
        return tempDir
    }
    
    private func parseConfiguration(at path: URL) async throws -> SkinConfiguration {
        // Parse viscolor.txt for visualization colors
        let viscolorsPath = path.appendingPathComponent("viscolor.txt")
        let visualizationColors = try parseVisualizationColors(from: viscolorsPath)
        
        // Parse pledit.txt for playlist colors
        let pleditPath = path.appendingPathComponent("pledit.txt")
        let playlistColors = try parsePlaylistColors(from: pleditPath)
        
        return SkinConfiguration(
            windowSize: CGSize(width: 275, height: 116), // Default Winamp size
            visualizationColors: visualizationColors,
            playlistColors: playlistColors
        )
    }
    
    private func parseVisualizationColors(from url: URL) throws -> [NSColor] {
        guard let content = try? String(contentsOf: url) else {
            return defaultVisualizationColors()
        }
        
        var colors: [NSColor] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let components = line.components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            
            if components.count >= 3 {
                let color = NSColor(
                    red: CGFloat(components[0]) / 255.0,
                    green: CGFloat(components[1]) / 255.0,
                    blue: CGFloat(components[2]) / 255.0,
                    alpha: 1.0
                )
                colors.append(color)
            }
        }
        
        return colors.isEmpty ? defaultVisualizationColors() : colors
    }
    
    private func parsePlaylistColors(from url: URL) throws -> SkinConfiguration.PlaylistColors {
        // TODO: Implement INI-style parsing for pledit.txt
        return SkinConfiguration.PlaylistColors(
            normalText: NSColor.white,
            currentText: NSColor.yellow,
            normalBackground: NSColor.black,
            selectedBackground: NSColor.blue
        )
    }
    
    private func loadSprites(from path: URL) async throws -> [String: NSImage] {
        var sprites: [String: NSImage] = [:]
        
        let spriteFiles = [
            "main", "cbuttons", "titlebar", "shufrep",
            "text", "volume", "balance", "posbar",
            "playpaus", "monoster", "eqmain", "pledit"
        ]
        
        for filename in spriteFiles {
            // Try loading PNG first, then BMP
            if let image = loadImage(named: filename, extension: "png", from: path) ??
                           loadImage(named: filename, extension: "bmp", from: path) {
                sprites[filename] = image
            }
        }
        
        return sprites
    }
    
    private func loadImage(named name: String, extension ext: String, from path: URL) -> NSImage? {
        let imagePath = path.appendingPathComponent("\(name).\(ext)")
        return NSImage(contentsOf: imagePath)
    }
    
    private func loadCursors(from path: URL) async throws -> [String: NSCursor] {
        // TODO: Implement .cur file parsing and conversion
        return [:]
    }
    
    private func parseMetadata(from path: URL) async throws -> SkinMetadata {
        // TODO: Parse skin metadata from readme.txt or skin.ini if present
        return SkinMetadata(
            name: path.lastPathComponent,
            author: nil,
            version: nil,
            comment: nil
        )
    }
    
    private func defaultVisualizationColors() -> [NSColor] {
        // Return default Winamp visualization colors
        return [
            NSColor.black,
            NSColor.blue,
            NSColor.cyan,
            NSColor.green,
            NSColor.yellow,
            NSColor.orange,
            NSColor.red,
            NSColor.magenta
        ]
    }
}