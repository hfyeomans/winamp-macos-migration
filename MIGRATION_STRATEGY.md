# Winamp Skins Migration Strategy for macOS

## 1. Asset Migration Strategy from BMP/PNG Sprites to macOS Rendering

### Core Asset Processing Pipeline

```swift
// Asset Manager for Sprite Processing
class WinampAssetManager {
    enum AssetType {
        case main, equalizer, playlist, controls, buttons, numbers, titlebar, cursor
    }
    
    struct SpriteSheet {
        let image: NSImage
        let frameSize: CGSize
        let columns: Int
        let rows: Int
        let padding: CGSize
    }
    
    // Convert BMP/PNG sprites to NSImage arrays
    func extractSprites(from sheet: SpriteSheet) -> [NSImage] {
        var sprites: [NSImage] = []
        let cgImage = sheet.image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        
        for row in 0..<sheet.rows {
            for col in 0..<sheet.columns {
                let rect = CGRect(
                    x: CGFloat(col) * (sheet.frameSize.width + sheet.padding.width),
                    y: CGFloat(row) * (sheet.frameSize.height + sheet.padding.height),
                    width: sheet.frameSize.width,
                    height: sheet.frameSize.height
                )
                
                if let croppedImage = cgImage.cropping(to: rect) {
                    sprites.append(NSImage(cgImage: croppedImage, size: sheet.frameSize))
                }
            }
        }
        return sprites
    }
}
```

### Sprite Definition System

```swift
struct WinampSpriteDefinition {
    let fileName: String
    let frameSize: CGSize
    let states: [String: CGRect] // State name to sprite position
    let isNineSlice: Bool
    let sliceInsets: NSEdgeInsets?
}

// Pre-defined sprite maps for common Winamp components
extension WinampSpriteDefinition {
    static let playButton = WinampSpriteDefinition(
        fileName: "cbuttons.bmp",
        frameSize: CGSize(width: 23, height: 18),
        states: [
            "normal": CGRect(x: 0, y: 0, width: 23, height: 18),
            "pressed": CGRect(x: 0, y: 18, width: 23, height: 18),
            "disabled": CGRect(x: 0, y: 36, width: 23, height: 18)
        ],
        isNineSlice: false,
        sliceInsets: nil
    )
    
    static let titlebar = WinampSpriteDefinition(
        fileName: "titlebar.bmp",
        frameSize: CGSize(width: 275, height: 14),
        states: [
            "active": CGRect(x: 0, y: 0, width: 275, height: 14),
            "inactive": CGRect(x: 0, y: 15, width: 275, height: 14)
        ],
        isNineSlice: true,
        sliceInsets: NSEdgeInsets(top: 0, left: 25, bottom: 0, right: 25)
    )
}
```

## 2. Unique Winamp Window Shapes and Transparency

### Custom Window Implementation

```swift
class WinampWindow: NSWindow {
    private var skinMask: NSImage?
    private var transparencyMask: CGImage?
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, 
                  backing backingType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, 
                  styleMask: [.borderless, .nonactivatingPanel], 
                  backing: backingType, 
                  defer: flag)
        
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
        self.level = .floating
    }
    
    func applySkinMask(_ maskImage: NSImage) {
        self.skinMask = maskImage
        
        // Create transparency mask from alpha channel
        guard let cgImage = maskImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Extract alpha channel to create mask
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(data: nil, width: width, height: height, 
                               bitsPerComponent: 8, bytesPerRow: width, 
                               space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        if let maskCGImage = context.makeImage() {
            self.transparencyMask = maskCGImage
            self.invalidateShadow()
        }
    }
}

// Custom content view for masked rendering
class WinampContentView: NSView {
    var backgroundImage: NSImage?
    var maskImage: NSImage?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Apply clipping mask
        if let mask = maskImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.clip(to: bounds, mask: mask)
        }
        
        // Draw background
        backgroundImage?.draw(in: bounds)
    }
    
    override var isOpaque: Bool { return false }
}
```

### Region-Based Hit Testing

```swift
extension WinampWindow {
    // Custom hit testing for irregular window shapes
    override func mouseLocationOutsideOfEventStream() -> NSPoint {
        let mouseLocation = super.mouseLocationOutsideOfEventStream()
        
        // Check if mouse is within the skin's visible area
        if let mask = transparencyMask, 
           let data = CFDataGetBytePtr(mask.dataProvider?.data) {
            
            let point = convert(mouseLocation, from: nil)
            let x = Int(point.x)
            let y = Int(mask.height) - Int(point.y) // Flip Y coordinate
            
            if x >= 0 && x < mask.width && y >= 0 && y < mask.height {
                let index = y * mask.width + x
                let alpha = data[index]
                
                // Only allow interaction in non-transparent areas
                if alpha > 128 {
                    return mouseLocation
                }
            }
        }
        
        return NSPoint(x: -1, y: -1) // Outside window
    }
}
```

## 3. Shaded Mode Implementation

### Window State Management

```swift
enum WinampWindowMode {
    case normal
    case shaded
    case doubleSize
}

class WinampPlayerWindow: WinampWindow {
    private var currentMode: WinampWindowMode = .normal
    private var normalSize: NSSize = NSSize(width: 275, height: 116)
    private var shadedSize: NSSize = NSSize(width: 275, height: 14)
    
    func toggleShadeMode() {
        let newMode: WinampWindowMode = (currentMode == .shaded) ? .normal : .shaded
        transitionToMode(newMode)
    }
    
    private func transitionToMode(_ mode: WinampWindowMode) {
        let targetSize = (mode == .shaded) ? shadedSize : normalSize
        let currentFrame = frame
        
        // Maintain top-left corner position during resize
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y + (currentFrame.height - targetSize.height),
            width: targetSize.width,
            height: targetSize.height
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(newFrame, display: true)
        }
        
        currentMode = mode
        updateContentForMode(mode)
    }
    
    private func updateContentForMode(_ mode: WinampWindowMode) {
        guard let contentView = contentView as? WinampContentView else { return }
        
        switch mode {
        case .shaded:
            contentView.backgroundImage = shadedModeImage
            contentView.maskImage = shadedModeMask
        case .normal:
            contentView.backgroundImage = normalModeImage
            contentView.maskImage = normalModeMask
        case .doubleSize:
            // Handle 2x scaling
            break
        }
        
        contentView.needsDisplay = true
    }
}
```

## 4. Pixel-Perfect Retina Display Scaling

### Multi-Resolution Asset Management

```swift
class RetinaAssetManager {
    private var assetCache: [String: [CGFloat: NSImage]] = [:]
    
    func image(named: String, scale: CGFloat) -> NSImage? {
        if let scaledImage = assetCache[named]?[scale] {
            return scaledImage
        }
        
        guard let baseImage = loadBaseImage(named: named) else { return nil }
        
        let scaledImage: NSImage
        
        if scale == 1.0 {
            scaledImage = baseImage
        } else {
            // Use nearest neighbor for pixel art
            scaledImage = scaleImagePixelPerfect(baseImage, scale: scale)
        }
        
        // Cache the result
        if assetCache[named] == nil {
            assetCache[named] = [:]
        }
        assetCache[named]?[scale] = scaledImage
        
        return scaledImage
    }
    
    private func scaleImagePixelPerfect(_ image: NSImage, scale: CGFloat) -> NSImage {
        let originalSize = image.size
        let newSize = NSSize(width: originalSize.width * scale, 
                            height: originalSize.height * scale)
        
        let scaledImage = NSImage(size: newSize)
        scaledImage.lockFocus()
        
        // Use nearest neighbor interpolation for crisp pixel art
        NSGraphicsContext.current?.imageInterpolation = .none
        
        image.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: originalSize),
                  operation: .copy,
                  fraction: 1.0)
        
        scaledImage.unlockFocus()
        return scaledImage
    }
}

// Auto-detect display scale
extension NSView {
    var displayScale: CGFloat {
        return window?.backingScaleFactor ?? 1.0
    }
    
    func pixelPerfectRect(_ rect: NSRect) -> NSRect {
        let scale = displayScale
        return NSRect(
            x: round(rect.origin.x * scale) / scale,
            y: round(rect.origin.y * scale) / scale,
            width: round(rect.width * scale) / scale,
            height: round(rect.height * scale) / scale
        )
    }
}
```

## 5. Classic Winamp Visualization Effects

### OpenGL-Based Visualization Engine

```swift
import OpenGL.GL3

class WinampVisualization: NSOpenGLView {
    private var shaderProgram: GLuint = 0
    private var vertexBuffer: GLuint = 0
    private var audioData: [Float] = Array(repeating: 0, count: 512)
    
    // Visualization modes
    enum VisualizationMode {
        case spectrum, oscilloscope, none
    }
    
    private var currentMode: VisualizationMode = .spectrum
    
    override func prepareOpenGL() {
        super.prepareOpenGL()
        
        // Set up OpenGL context
        let attributes: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFADepthSize), 24,
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
            0
        ]
        
        guard let pixelFormat = NSOpenGLPixelFormat(attributes: attributes) else { return }
        openGLContext = NSOpenGLContext(format: pixelFormat, share: nil)
        
        setupShaders()
        setupBuffers()
    }
    
    private func setupShaders() {
        let vertexShader = """
        #version 330 core
        layout (location = 0) in vec2 position;
        layout (location = 1) in float amplitude;
        
        uniform float time;
        uniform int mode;
        
        void main() {
            vec2 pos = position;
            
            if (mode == 0) { // Spectrum
                pos.y = amplitude * 0.8;
            } else if (mode == 1) { // Oscilloscope
                pos.y = amplitude * position.x;
            }
            
            gl_Position = vec4(pos, 0.0, 1.0);
        }
        """
        
        let fragmentShader = """
        #version 330 core
        out vec4 FragColor;
        
        uniform vec3 color;
        uniform float time;
        
        void main() {
            FragColor = vec4(color, 1.0);
        }
        """
        
        // Compile and link shaders (implementation details omitted for brevity)
        shaderProgram = compileShaderProgram(vertex: vertexShader, fragment: fragmentShader)
    }
    
    func updateAudioData(_ data: [Float]) {
        audioData = data
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        openGLContext?.makeCurrentContext()
        
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        glUseProgram(shaderProgram)
        
        // Update uniforms
        let timeLocation = glGetUniformLocation(shaderProgram, "time")
        let modeLocation = glGetUniformLocation(shaderProgram, "mode")
        let colorLocation = glGetUniformLocation(shaderProgram, "color")
        
        glUniform1f(timeLocation, Float(CACurrentMediaTime()))
        glUniform1i(modeLocation, currentMode == .spectrum ? 0 : 1)
        glUniform3f(colorLocation, 0.0, 1.0, 0.0) // Classic green
        
        // Render visualization based on audio data
        renderVisualization()
        
        openGLContext?.flushBuffer()
    }
    
    private func renderVisualization() {
        // Implementation would render bars/waveform based on audioData
        // This is a simplified version
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glDrawArrays(GLenum(GL_LINE_STRIP), 0, GLsizei(audioData.count))
    }
}
```

## 6. Color Management Between Windows and macOS

### Color Space Conversion

```swift
class WinampColorManager {
    // Windows GDI uses sRGB, macOS prefers Display P3
    static func convertWindowsColor(_ windowsColor: UInt32) -> NSColor {
        let r = CGFloat((windowsColor >> 16) & 0xFF) / 255.0
        let g = CGFloat((windowsColor >> 8) & 0xFF) / 255.0
        let b = CGFloat(windowsColor & 0xFF) / 255.0
        
        // Create color in sRGB space first
        let srgbColor = NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
        
        // Convert to current display color space
        return srgbColor.usingColorSpace(.displayP3) ?? srgbColor
    }
    
    // Parse Winamp color definitions from pledit.txt or region.txt
    static func parseColorDefinition(_ definition: String) -> NSColor? {
        // Format: "Normal=#00FF00" or "RGB(0,255,0)"
        if definition.hasPrefix("#") {
            let hex = String(definition.dropFirst())
            guard let colorValue = UInt32(hex, radix: 16) else { return nil }
            return convertWindowsColor(colorValue)
        } else if definition.hasPrefix("RGB(") {
            // Parse RGB(r,g,b) format
            let components = definition
                .replacingOccurrences(of: "RGB(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            
            guard components.count == 3 else { return nil }
            
            return NSColor(srgbRed: CGFloat(components[0]) / 255.0,
                          green: CGFloat(components[1]) / 255.0,
                          blue: CGFloat(components[2]) / 255.0,
                          alpha: 1.0)
        }
        
        return nil
    }
    
    // Gamma correction for better color matching
    static func applyGammaCorrection(_ color: NSColor, gamma: CGFloat = 2.2) -> NSColor {
        guard let rgbColor = color.usingColorSpace(.sRGB) else { return color }
        
        let correctedR = pow(rgbColor.redComponent, 1.0 / gamma)
        let correctedG = pow(rgbColor.greenComponent, 1.0 / gamma)
        let correctedB = pow(rgbColor.blueComponent, 1.0 / gamma)
        
        return NSColor(srgbRed: correctedR, green: correctedG, blue: correctedB, alpha: rgbColor.alphaComponent)
    }
}
```

## 7. Animation and Transition Recommendations

### Smooth Animations with Core Animation

```swift
class WinampAnimationManager {
    // Standard timing curves for Winamp-style animations
    static let quickSnap = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
    static let smoothEase = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
    
    // Button press animation
    static func animateButtonPress(_ view: NSView, completion: @escaping () -> Void) {
        let scaleDown = CABasicAnimation(keyPath: "transform.scale")
        scaleDown.fromValue = 1.0
        scaleDown.toValue = 0.95
        scaleDown.duration = 0.05
        scaleDown.timingFunction = quickSnap
        
        let scaleUp = CABasicAnimation(keyPath: "transform.scale")
        scaleUp.fromValue = 0.95
        scaleUp.toValue = 1.0
        scaleUp.duration = 0.1
        scaleUp.beginTime = CACurrentMediaTime() + 0.05
        scaleUp.timingFunction = smoothEase
        
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        
        view.layer?.add(scaleDown, forKey: "scaleDown")
        view.layer?.add(scaleUp, forKey: "scaleUp")
        
        CATransaction.commit()
    }
    
    // Spectrum bar animation
    static func animateSpectrumBar(_ layer: CALayer, toHeight height: CGFloat) {
        let animation = CABasicAnimation(keyPath: "bounds.size.height")
        animation.fromValue = layer.bounds.height
        animation.toValue = height
        animation.duration = 0.1
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        
        layer.add(animation, forKey: "heightChange")
        layer.bounds.size.height = height
    }
    
    // Window slide transitions
    static func slideWindow(_ window: NSWindow, to newFrame: NSRect, duration: TimeInterval = 0.2) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = smoothEase
            window.animator().setFrame(newFrame, display: true)
        }
    }
}
```

## 8. Dynamic .wsz File Loading System

### WSZ Archive Parser

```swift
import Compression

class WSZSkinLoader {
    struct SkinPackage {
        let metadata: SkinMetadata
        let assets: [String: Data]
        let configuration: SkinConfiguration
    }
    
    struct SkinMetadata {
        let name: String
        let author: String
        let version: String
        let description: String
    }
    
    struct SkinConfiguration {
        let colors: [String: NSColor]
        let fonts: [String: NSFont]
        let regions: [String: CGRect]
        let animations: [String: AnimationConfig]
    }
    
    static func loadSkin(from url: URL) throws -> SkinPackage {
        let data = try Data(contentsOf: url)
        
        // WSZ files are ZIP archives
        let assets = try extractZipArchive(data)
        
        // Parse skin.txt or similar configuration file
        let metadata = try parseSkinMetadata(from: assets)
        let configuration = try parseSkinConfiguration(from: assets)
        
        return SkinPackage(metadata: metadata, assets: assets, configuration: configuration)
    }
    
    private static func extractZipArchive(_ data: Data) throws -> [String: Data] {
        var assets: [String: Data] = [:]
        
        // Use NSFileManager to extract ZIP
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let zipPath = tempDir.appendingPathComponent("skin.wsz")
        try data.write(to: zipPath)
        
        // Extract using Archive framework or shell command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipPath.path, "-d", tempDir.path]
        try process.run()
        process.waitUntilExit()
        
        // Read extracted files
        let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.hasDirectoryPath { continue }
            
            let relativePath = fileURL.path.replacingOccurrences(of: tempDir.path + "/", with: "")
            assets[relativePath] = try Data(contentsOf: fileURL)
        }
        
        return assets
    }
    
    private static func parseSkinMetadata(from assets: [String: Data]) throws -> SkinMetadata {
        // Look for skin.txt, readme.txt, or similar
        for (filename, data) in assets {
            if filename.lowercased().contains("readme") || filename.lowercased().contains("skin") {
                if let content = String(data: data, encoding: .utf8) {
                    return extractMetadataFromText(content)
                }
            }
        }
        
        return SkinMetadata(name: "Unknown", author: "Unknown", version: "1.0", description: "")
    }
    
    private static func extractMetadataFromText(_ text: String) -> SkinMetadata {
        var name = "Unknown"
        var author = "Unknown"
        var version = "1.0"
        var description = ""
        
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.contains("name") || lowercased.contains("title") {
                name = extractValue(from: line)
            } else if lowercased.contains("author") || lowercased.contains("by") {
                author = extractValue(from: line)
            } else if lowercased.contains("version") {
                version = extractValue(from: line)
            }
        }
        
        return SkinMetadata(name: name, author: author, version: version, description: description)
    }
    
    private static func extractValue(from line: String) -> String {
        if let colonRange = line.range(of: ":") {
            return String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

## 9. Cursor Replacement Strategy for macOS

### Custom Cursor Management

```swift
class WinampCursorManager {
    private static var cursorCache: [String: NSCursor] = [:]
    
    enum CursorType: String, CaseIterable {
        case normal = "normal.cur"
        case pointing = "pointing.cur"  // Hand cursor
        case working = "working.cur"    // Busy cursor
        case resize = "resize.cur"      // Size cursor
        case move = "move.cur"          // Move cursor
        case text = "text.cur"          // Text selection
    }
    
    static func loadCursors(from skinAssets: [String: Data]) {
        for cursorType in CursorType.allCases {
            if let cursorData = skinAssets[cursorType.rawValue] {
                let cursor = createCursorFromWindowsFormat(cursorData)
                cursorCache[cursorType.rawValue] = cursor
            }
        }
    }
    
    private static func createCursorFromWindowsFormat(_ data: Data) -> NSCursor {
        // Parse .cur file format
        // Windows cursor format has header followed by image data
        
        // For now, convert to NSImage and create cursor
        // In production, you'd want to properly parse the .cur format
        
        if let image = NSImage(data: data) {
            // Cursor hotspot is usually center for most Winamp cursors
            let hotspot = NSPoint(x: image.size.width / 2, y: image.size.height / 2)
            return NSCursor(image: image, hotSpot: hotspot)
        }
        
        // Fallback to system cursors
        return NSCursor.arrow
    }
    
    static func setCursor(_ type: CursorType) {
        if let cursor = cursorCache[type.rawValue] {
            cursor.set()
        } else {
            // Fallback to appropriate system cursor
            switch type {
            case .normal:
                NSCursor.arrow.set()
            case .pointing:
                NSCursor.pointingHand.set()
            case .working:
                NSCursor.operationNotAllowed.set()
            case .resize:
                NSCursor.resizeLeftRight.set()
            case .move:
                NSCursor.closedHand.set()
            case .text:
                NSCursor.iBeam.set()
            }
        }
    }
    
    // Cursor tracking for different UI regions
    static func setupCursorTracking(for view: NSView, cursor: CursorType) {
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.activeInKeyWindow, .cursorUpdate],
            owner: view,
            userInfo: ["cursor": cursor.rawValue]
        )
        view.addTrackingArea(trackingArea)
    }
}

// Extension for NSView to handle cursor updates
extension NSView {
    override func cursorUpdate(with event: NSEvent) {
        if let cursor = trackingAreas.first?.userInfo?["cursor"] as? String,
           let cursorType = WinampCursorManager.CursorType(rawValue: cursor) {
            WinampCursorManager.setCursor(cursorType)
        } else {
            super.cursorUpdate(with: event)
        }
    }
}
```

## 10. Dark Mode Considerations

### Skin-Override Approach

```swift
class WinampAppearanceManager {
    enum AppearanceMode {
        case followSystem
        case forceSkin
        case adaptiveSkin
    }
    
    private static var currentMode: AppearanceMode = .forceSkin
    
    static func configureAppearance(mode: AppearanceMode) {
        currentMode = mode
        
        switch mode {
        case .followSystem:
            // Let system appearance affect window chrome
            NSApplication.shared.appearance = nil
            
        case .forceSkin:
            // Skin completely overrides system appearance
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
            
        case .adaptiveSkin:
            // Blend skin with system dark mode
            if NSApp.effectiveAppearance.name == .darkAqua {
                applyDarkModeAdaptations()
            }
            NSApplication.shared.appearance = nil
        }
    }
    
    private static func applyDarkModeAdaptations() {
        // Slightly darken skin colors in dark mode
        // Adjust window shadow and backdrop
        // Make transparent areas more prominent
        
        NotificationCenter.default.post(name: .skinShouldAdaptToDarkMode, object: nil)
    }
    
    // Window styling for different modes
    static func styleWindow(_ window: NSWindow, for mode: AppearanceMode) {
        switch mode {
        case .followSystem:
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
            
        case .forceSkin, .adaptiveSkin:
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask = [.borderless, .miniaturizable, .closable]
        }
    }
}

extension Notification.Name {
    static let skinShouldAdaptToDarkMode = Notification.Name("skinShouldAdaptToDarkMode")
}
```

### Implementation Summary

This comprehensive strategy provides:

1. **Sprite Processing**: Efficient extraction and caching of Winamp sprite assets
2. **Custom Windows**: Irregular shapes with proper hit-testing and transparency
3. **Shaded Mode**: Smooth transitions between window states
4. **Retina Support**: Pixel-perfect scaling with nearest-neighbor interpolation
5. **Visualizations**: OpenGL-based spectrum and oscilloscope effects
6. **Color Management**: Proper conversion between Windows and macOS color spaces
7. **Animations**: Core Animation-based smooth transitions
8. **Dynamic Loading**: Complete .wsz file parsing and asset management
9. **Cursor Support**: Windows cursor conversion with fallback to system cursors
10. **Appearance Management**: Flexible dark mode handling that respects skin design

The key is maintaining visual fidelity while leveraging macOS-native technologies for performance and integration. Each component is designed to be modular and extensible for different skin styles and requirements.