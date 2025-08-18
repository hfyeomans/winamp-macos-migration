import Cocoa
import UniformTypeIdentifiers

// MARK: - Theme Engine for Dynamic Skin Loading
class WinampThemeEngine {
    
    // MARK: - Theme Data Structures
    struct Theme {
        let metadata: ThemeMetadata
        let assets: ThemeAssets
        let configuration: ThemeConfiguration
        let colorScheme: ColorScheme
    }
    
    struct ThemeMetadata {
        let name: String
        let author: String
        let version: String
        let description: String
        let previewImage: NSImage?
    }
    
    struct ThemeAssets {
        // Main components
        let mainWindow: NSImage?
        let equalizer: NSImage?
        let playlist: NSImage?
        let titlebar: NSImage?
        
        // Controls
        let controlButtons: NSImage?
        let volumeSlider: NSImage?
        let balanceSlider: NSImage?
        let positionSlider: NSImage?
        let numbers: NSImage?
        
        // UI Elements
        let text: NSImage?
        let monostereo: NSImage?
        let playpause: NSImage?
        
        // Cursors
        let cursors: [String: NSData]
        
        // Raw asset data for custom parsing
        let rawAssets: [String: Data]
    }
    
    struct ThemeConfiguration {
        let windowRegions: [String: CGRect]
        let buttonMappings: [String: ButtonMapping]
        let sliderConfigs: [String: SliderConfig]
        let textRegions: [String: TextRegion]
        let animations: [String: AnimationConfig]
    }
    
    struct ButtonMapping {
        let normalRect: CGRect
        let pressedRect: CGRect
        let disabledRect: CGRect?
        let hotspot: CGPoint
        let action: String
    }
    
    struct SliderConfig {
        let trackRect: CGRect
        let thumbRect: CGRect
        let range: ClosedRange<Float>
        let orientation: SliderOrientation
    }
    
    enum SliderOrientation {
        case horizontal, vertical
    }
    
    struct TextRegion {
        let rect: CGRect
        let font: NSFont
        let color: NSColor
        let alignment: NSTextAlignment
        let scrolling: Bool
    }
    
    struct AnimationConfig {
        let frames: [CGRect]
        let duration: TimeInterval
        let repeatCount: Int
    }
    
    // MARK: - Color Management
    struct ColorScheme {
        let primary: NSColor
        let secondary: NSColor
        let background: NSColor
        let text: NSColor
        let accent: NSColor
        let visualization: NSColor
        
        // Winamp-specific colors
        let normalbg: NSColor      // Normal background
        let normalfg: NSColor      // Normal foreground
        let selectbg: NSColor      // Selected background
        let selectfg: NSColor      // Selected foreground
        let windowbg: NSColor      // Window background
        let buttontext: NSColor    // Button text
        let scrollbar: NSColor     // Scrollbar color
        let listviewbg: NSColor    // List view background
        let listviewfg: NSColor    // List view foreground
        let editbg: NSColor        // Edit field background
        let editfg: NSColor        // Edit field foreground
    }
    
    // MARK: - WSZ File Parser
    class WSZParser {
        static func parseWSZ(from url: URL) throws -> Theme {
            let data = try Data(contentsOf: url)
            return try parseWSZData(data)
        }
        
        static func parseWSZData(_ data: Data) throws -> Theme {
            // Extract ZIP archive
            let tempDir = createTempDirectory()
            defer { try? FileManager.default.removeItem(at: tempDir) }
            
            let extractedAssets = try extractZipToDirectory(data, destination: tempDir)
            
            // Parse components
            let metadata = try parseMetadata(from: extractedAssets)
            let assets = try parseAssets(from: extractedAssets)
            let configuration = try parseConfiguration(from: extractedAssets)
            let colorScheme = try parseColorScheme(from: extractedAssets)
            
            return Theme(metadata: metadata, assets: assets, 
                        configuration: configuration, colorScheme: colorScheme)
        }
        
        private static func createTempDirectory() -> URL {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("winamp_skin_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            return tempDir
        }
        
        private static func extractZipToDirectory(_ data: Data, destination: URL) throws -> [String: Data] {
            let zipPath = destination.appendingPathComponent("skin.wsz")
            try data.write(to: zipPath)
            
            // Use system unzip command
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", "-o", zipPath.path, "-d", destination.path]
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw ThemeError.extractionFailed
            }
            
            // Read all extracted files
            var assets: [String: Data] = [:]
            let enumerator = FileManager.default.enumerator(at: destination, includingPropertiesForKeys: nil)
            
            while let fileURL = enumerator?.nextObject() as? URL {
                guard !fileURL.hasDirectoryPath else { continue }
                
                let relativePath = fileURL.path.replacingOccurrences(of: destination.path + "/", with: "")
                    .lowercased() // Normalize case for cross-platform compatibility
                
                if let fileData = try? Data(contentsOf: fileURL) {
                    assets[relativePath] = fileData
                }
            }
            
            return assets
        }
        
        private static func parseMetadata(from assets: [String: Data]) throws -> ThemeMetadata {
            var name = "Unknown Skin"
            var author = "Unknown"
            var version = "1.0"
            var description = ""
            var previewImage: NSImage?
            
            // Look for metadata files
            for (filename, data) in assets {
                if filename.contains("readme") || filename.contains("skin") || filename.contains("info") {
                    if let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                        let metadata = parseMetadataFromText(content)
                        name = metadata.name
                        author = metadata.author
                        version = metadata.version
                        description = metadata.description
                    }
                }
                
                // Look for preview image
                if filename.contains("preview") || filename.contains("thumb") {
                    previewImage = NSImage(data: data)
                }
            }
            
            return ThemeMetadata(name: name, author: author, version: version, 
                               description: description, previewImage: previewImage)
        }
        
        private static func parseMetadataFromText(_ text: String) -> (name: String, author: String, version: String, description: String) {
            var name = "Unknown Skin"
            var author = "Unknown"
            var version = "1.0"
            var description = ""
            
            let lines = text.components(separatedBy: .newlines)
            
            for line in lines {
                let lowercased = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                if lowercased.contains("skin name") || lowercased.contains("title") {
                    name = extractValue(from: line) ?? name
                } else if lowercased.contains("author") || lowercased.contains("created by") || lowercased.contains("by:") {
                    author = extractValue(from: line) ?? author
                } else if lowercased.contains("version") {
                    version = extractValue(from: line) ?? version
                } else if lowercased.contains("description") {
                    description = extractValue(from: line) ?? description
                }
            }
            
            return (name, author, version, description)
        }
        
        private static func extractValue(from line: String) -> String? {
            if let colonRange = line.range(of: ":") {
                return String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }
        
        private static func parseAssets(from rawAssets: [String: Data]) throws -> ThemeAssets {
            var cursors: [String: NSData] = [:]
            
            // Extract cursor files
            for (filename, data) in rawAssets {
                if filename.hasSuffix(".cur") {
                    cursors[filename] = data as NSData
                }
            }
            
            return ThemeAssets(
                mainWindow: imageFromAssets(rawAssets, named: "main"),
                equalizer: imageFromAssets(rawAssets, named: "eqmain"),
                playlist: imageFromAssets(rawAssets, named: "pledit"),
                titlebar: imageFromAssets(rawAssets, named: "titlebar"),
                controlButtons: imageFromAssets(rawAssets, named: "cbuttons"),
                volumeSlider: imageFromAssets(rawAssets, named: "volume"),
                balanceSlider: imageFromAssets(rawAssets, named: "balance"),
                positionSlider: imageFromAssets(rawAssets, named: "posbar"),
                numbers: imageFromAssets(rawAssets, named: "numbers"),
                text: imageFromAssets(rawAssets, named: "text"),
                monostereo: imageFromAssets(rawAssets, named: "monoster"),
                playpause: imageFromAssets(rawAssets, named: "playpaus"),
                cursors: cursors,
                rawAssets: rawAssets
            )
        }
        
        private static func imageFromAssets(_ assets: [String: Data], named: String) -> NSImage? {
            // Try different extensions
            let extensions = ["bmp", "png", "gif"]
            
            for ext in extensions {
                let filename = "\(named.lowercased()).\(ext)"
                if let data = assets[filename] {
                    return NSImage(data: data)
                }
            }
            
            return nil
        }
        
        private static func parseConfiguration(from assets: [String: Data]) throws -> ThemeConfiguration {
            var windowRegions: [String: CGRect] = [:]
            var buttonMappings: [String: ButtonMapping] = [:]
            var sliderConfigs: [String: SliderConfig] = [:]
            var textRegions: [String: TextRegion] = [:]
            var animations: [String: AnimationConfig] = [:]
            
            // Parse region.txt if it exists
            if let regionData = assets["region.txt"],
               let regionText = String(data: regionData, encoding: .utf8) {
                windowRegions = parseRegionFile(regionText)
            }
            
            // Parse other configuration files
            if let configData = assets["skin.txt"] ?? assets["config.txt"],
               let configText = String(data: configData, encoding: .utf8) {
                (buttonMappings, sliderConfigs, textRegions) = parseConfigFile(configText)
            }
            
            return ThemeConfiguration(
                windowRegions: windowRegions,
                buttonMappings: buttonMappings,
                sliderConfigs: sliderConfigs,
                textRegions: textRegions,
                animations: animations
            )
        }
        
        private static func parseRegionFile(_ content: String) -> [String: CGRect] {
            var regions: [String: CGRect] = [:]
            
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                // Parse format: "regionname=x,y,width,height"
                if let equalRange = line.range(of: "=") {
                    let name = String(line[..<equalRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let coords = String(line[equalRange.upperBound...])
                        .components(separatedBy: ",")
                        .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    
                    if coords.count == 4 {
                        regions[name] = CGRect(x: coords[0], y: coords[1], width: coords[2], height: coords[3])
                    }
                }
            }
            
            return regions
        }
        
        private static func parseConfigFile(_ content: String) -> ([String: ButtonMapping], [String: SliderConfig], [String: TextRegion]) {
            var buttons: [String: ButtonMapping] = [:]
            var sliders: [String: SliderConfig] = [:]
            var textRegions: [String: TextRegion] = [:]
            
            // This would contain more sophisticated parsing logic
            // For now, return empty collections
            
            return (buttons, sliders, textRegions)
        }
        
        private static func parseColorScheme(from assets: [String: Data]) throws -> ColorScheme {
            var colors: [String: NSColor] = [:]
            
            // Look for color definition files
            for (filename, data) in assets {
                if filename.contains("color") || filename.contains("pledit") {
                    if let content = String(data: data, encoding: .utf8) {
                        let parsedColors = parseColorDefinitions(content)
                        colors.merge(parsedColors) { _, new in new }
                    }
                }
            }
            
            // Create color scheme with defaults
            return ColorScheme(
                primary: colors["primary"] ?? NSColor.controlAccentColor,
                secondary: colors["secondary"] ?? NSColor.secondaryLabelColor,
                background: colors["background"] ?? NSColor.windowBackgroundColor,
                text: colors["text"] ?? NSColor.labelColor,
                accent: colors["accent"] ?? NSColor.controlAccentColor,
                visualization: colors["visualization"] ?? NSColor.systemGreen,
                normalbg: colors["normalbg"] ?? NSColor.controlBackgroundColor,
                normalfg: colors["normalfg"] ?? NSColor.controlTextColor,
                selectbg: colors["selectbg"] ?? NSColor.selectedControlColor,
                selectfg: colors["selectfg"] ?? NSColor.selectedControlTextColor,
                windowbg: colors["windowbg"] ?? NSColor.windowBackgroundColor,
                buttontext: colors["buttontext"] ?? NSColor.controlTextColor,
                scrollbar: colors["scrollbar"] ?? NSColor.scrollBarColor,
                listviewbg: colors["listviewbg"] ?? NSColor.controlBackgroundColor,
                listviewfg: colors["listviewfg"] ?? NSColor.controlTextColor,
                editbg: colors["editbg"] ?? NSColor.textBackgroundColor,
                editfg: colors["editfg"] ?? NSColor.textColor
            )
        }
        
        private static func parseColorDefinitions(_ content: String) -> [String: NSColor] {
            var colors: [String: NSColor] = [:]
            
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                // Parse format: "ColorName=#RRGGBB" or "ColorName=RGB(r,g,b)"
                if let equalRange = line.range(of: "=") {
                    let name = String(line[..<equalRange.lowerBound])
                        .trimmingCharacters(in: .whitespaces)
                        .lowercased()
                    
                    let value = String(line[equalRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    
                    if let color = parseColorValue(value) {
                        colors[name] = color
                    }
                }
            }
            
            return colors
        }
        
        private static func parseColorValue(_ value: String) -> NSColor? {
            if value.hasPrefix("#") {
                // Hex color: #RRGGBB
                let hex = String(value.dropFirst())
                guard hex.count == 6, let colorValue = UInt32(hex, radix: 16) else { return nil }
                
                let r = CGFloat((colorValue >> 16) & 0xFF) / 255.0
                let g = CGFloat((colorValue >> 8) & 0xFF) / 255.0
                let b = CGFloat(colorValue & 0xFF) / 255.0
                
                return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
                
            } else if value.hasPrefix("RGB(") && value.hasSuffix(")") {
                // RGB color: RGB(r,g,b)
                let rgbString = String(value.dropFirst(4).dropLast())
                let components = rgbString.components(separatedBy: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                
                guard components.count == 3 else { return nil }
                
                return NSColor(srgbRed: CGFloat(components[0]) / 255.0,
                              green: CGFloat(components[1]) / 255.0,
                              blue: CGFloat(components[2]) / 255.0,
                              alpha: 1.0)
            }
            
            return nil
        }
    }
    
    // MARK: - Theme Manager
    class ThemeManager {
        static let shared = ThemeManager()
        private var currentTheme: Theme?
        private var themeChangeObservers: [(Theme) -> Void] = []
        
        private init() {}
        
        func loadTheme(from url: URL) throws {
            let theme = try WSZParser.parseWSZ(from: url)
            applyTheme(theme)
        }
        
        func loadTheme(from data: Data) throws {
            let theme = try WSZParser.parseWSZData(data)
            applyTheme(theme)
        }
        
        private func applyTheme(_ theme: Theme) {
            currentTheme = theme
            
            // Notify observers
            for observer in themeChangeObservers {
                observer(theme)
            }
            
            // Post notification
            NotificationCenter.default.post(name: .themeDidChange, object: theme)
        }
        
        func observeThemeChanges(_ observer: @escaping (Theme) -> Void) {
            themeChangeObservers.append(observer)
        }
        
        var current: Theme? {
            return currentTheme
        }
        
        // Color utilities
        func color(for key: String) -> NSColor? {
            return currentTheme?.colorScheme.normalbg // Simplified - would map keys properly
        }
        
        func asset(named: String) -> NSImage? {
            // Return appropriate asset from current theme
            switch name.lowercased() {
            case "main":
                return currentTheme?.assets.mainWindow
            case "eqmain":
                return currentTheme?.assets.equalizer
            case "pledit":
                return currentTheme?.assets.playlist
            case "cbuttons":
                return currentTheme?.assets.controlButtons
            case "numbers":
                return currentTheme?.assets.numbers
            default:
                return nil
            }
        }
    }
    
    // MARK: - Error Types
    enum ThemeError: Error {
        case extractionFailed
        case invalidFormat
        case missingAssets
        case corruptedData
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChange")
}

// MARK: - Theme-Aware Components
protocol ThemeAware {
    func themeDidChange(_ theme: WinampThemeEngine.Theme)
}

// Example theme-aware view
class ThemedWinampView: NSView, ThemeAware {
    override func awakeFromNib() {
        super.awakeFromNib()
        WinampThemeEngine.ThemeManager.shared.observeThemeChanges { [weak self] theme in
            self?.themeDidChange(theme)
        }
    }
    
    func themeDidChange(_ theme: WinampThemeEngine.Theme) {
        // Update appearance based on new theme
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Use current theme colors and assets
        if let bgColor = WinampThemeEngine.ThemeManager.shared.current?.colorScheme.background {
            bgColor.setFill()
            dirtyRect.fill()
        }
    }
}