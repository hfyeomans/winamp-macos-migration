import Cocoa
import OpenGL.GL3
import AVFoundation

// MARK: - Core Rendering Engine
class WinampRenderer {
    
    // MARK: - Asset Management
    class AssetManager {
        private var spriteCache: [String: [NSImage]] = [:]
        private var scaledCache: [String: [CGFloat: NSImage]] = [:]
        
        struct SkinAsset {
            let baseImage: NSImage
            let frameSize: CGSize
            let frameCount: Int
            let isHorizontal: Bool
        }
        
        func loadSkinAsset(named: String, frameSize: CGSize, frameCount: Int = 1, isHorizontal: Bool = true) -> SkinAsset? {
            guard let image = NSImage(named: named) else {
                print("Failed to load asset: \(named)")
                return nil
            }
            
            return SkinAsset(baseImage: image, frameSize: frameSize, frameCount: frameCount, isHorizontal: isHorizontal)
        }
        
        func extractFrames(from asset: SkinAsset) -> [NSImage] {
            let cacheKey = "\(asset.baseImage.name() ?? "unknown")_\(asset.frameSize)_\(asset.frameCount)"
            
            if let cached = spriteCache[cacheKey] {
                return cached
            }
            
            var frames: [NSImage] = []
            guard let cgImage = asset.baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return frames
            }
            
            for i in 0..<asset.frameCount {
                let rect: CGRect
                if asset.isHorizontal {
                    rect = CGRect(x: CGFloat(i) * asset.frameSize.width, y: 0, 
                                 width: asset.frameSize.width, height: asset.frameSize.height)
                } else {
                    rect = CGRect(x: 0, y: CGFloat(i) * asset.frameSize.height,
                                 width: asset.frameSize.width, height: asset.frameSize.height)
                }
                
                if let croppedImage = cgImage.cropping(to: rect) {
                    let frame = NSImage(cgImage: croppedImage, size: asset.frameSize)
                    frames.append(frame)
                }
            }
            
            spriteCache[cacheKey] = frames
            return frames
        }
        
        func getScaledImage(_ image: NSImage, scale: CGFloat) -> NSImage {
            let cacheKey = image.name() ?? UUID().uuidString
            
            if let cached = scaledCache[cacheKey]?[scale] {
                return cached
            }
            
            let scaledImage = scaleImagePixelPerfect(image, scale: scale)
            
            if scaledCache[cacheKey] == nil {
                scaledCache[cacheKey] = [:]
            }
            scaledCache[cacheKey]?[scale] = scaledImage
            
            return scaledImage
        }
        
        private func scaleImagePixelPerfect(_ image: NSImage, scale: CGFloat) -> NSImage {
            let originalSize = image.size
            let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)
            
            let scaledImage = NSImage(size: newSize)
            scaledImage.lockFocus()
            
            // Critical: Use nearest neighbor for pixel art
            NSGraphicsContext.current?.imageInterpolation = .none
            
            image.draw(in: NSRect(origin: .zero, size: newSize),
                      from: NSRect(origin: .zero, size: originalSize),
                      operation: .copy, fraction: 1.0)
            
            scaledImage.unlockFocus()
            return scaledImage
        }
    }
    
    // MARK: - Button Component
    class WinampButton: NSView {
        enum State {
            case normal, pressed, disabled
        }
        
        private let frames: [NSImage]
        private var currentState: State = .normal
        private let assetManager: AssetManager
        private var action: (() -> Void)?
        
        init(frames: [NSImage], assetManager: AssetManager) {
            self.frames = frames
            self.assetManager = assetManager
            super.init(frame: NSRect(origin: .zero, size: frames.first?.size ?? .zero))
            setupTracking()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func setAction(_ action: @escaping () -> Void) {
            self.action = action
        }
        
        private func setupTracking() {
            let trackingArea = NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .mouseEnteredAndExited, .enabledDuringMouseDrag],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
        }
        
        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            
            guard let image = imageForCurrentState() else { return }
            
            let scale = window?.backingScaleFactor ?? 1.0
            let scaledImage = assetManager.getScaledImage(image, scale: scale)
            
            // Draw with pixel-perfect positioning
            let drawRect = pixelAlignedRect(bounds)
            scaledImage.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
        }
        
        private func imageForCurrentState() -> NSImage? {
            switch currentState {
            case .normal:
                return frames.first
            case .pressed:
                return frames.count > 1 ? frames[1] : frames.first
            case .disabled:
                return frames.count > 2 ? frames[2] : frames.first
            }
        }
        
        private func pixelAlignedRect(_ rect: NSRect) -> NSRect {
            let scale = window?.backingScaleFactor ?? 1.0
            return NSRect(
                x: round(rect.origin.x * scale) / scale,
                y: round(rect.origin.y * scale) / scale,
                width: round(rect.width * scale) / scale,
                height: round(rect.height * scale) / scale
            )
        }
        
        override func mouseDown(with event: NSEvent) {
            currentState = .pressed
            needsDisplay = true
            
            // Visual feedback
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.05
                animator().transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }
        
        override func mouseUp(with event: NSEvent) {
            let wasPressed = currentState == .pressed
            currentState = .normal
            needsDisplay = true
            
            // Reset animation
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                animator().transform = CGAffineTransform.identity
            }
            
            // Execute action if mouse is still inside
            if wasPressed && bounds.contains(convert(event.locationInWindow, from: nil)) {
                action?()
            }
        }
        
        override var isOpaque: Bool { return false }
    }
    
    // MARK: - Display Components
    class WinampDisplay: NSView {
        private let digitFrames: [NSImage]
        private let assetManager: AssetManager
        private var displayText: String = "00:00"
        private let digitWidth: CGFloat
        private let digitHeight: CGFloat
        
        init(digitFrames: [NSImage], assetManager: AssetManager) {
            self.digitFrames = digitFrames
            self.assetManager = assetManager
            self.digitWidth = digitFrames.first?.size.width ?? 0
            self.digitHeight = digitFrames.first?.size.height ?? 0
            
            let frameSize = NSSize(width: digitWidth * 5, height: digitHeight) // "00:00" = 5 chars
            super.init(frame: NSRect(origin: .zero, size: frameSize))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateTime(_ seconds: TimeInterval) {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            displayText = String(format: "%02d:%02d", minutes, secs)
            needsDisplay = true
        }
        
        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            
            let scale = window?.backingScaleFactor ?? 1.0
            var xOffset: CGFloat = 0
            
            for char in displayText {
                let digitIndex = digitIndexForCharacter(char)
                if digitIndex < digitFrames.count {
                    let image = assetManager.getScaledImage(digitFrames[digitIndex], scale: scale)
                    let drawRect = NSRect(x: xOffset, y: 0, width: digitWidth, height: digitHeight)
                    image.draw(in: pixelAlignedRect(drawRect), from: .zero, operation: .copy, fraction: 1.0)
                }
                xOffset += digitWidth
            }
        }
        
        private func digitIndexForCharacter(_ char: Character) -> Int {
            switch char {
            case "0"..."9":
                return Int(char.asciiValue! - 48) // ASCII '0' = 48
            case ":":
                return 10 // Colon sprite index
            case "-":
                return 11 // Minus sprite index
            default:
                return 0 // Default to '0'
            }
        }
        
        private func pixelAlignedRect(_ rect: NSRect) -> NSRect {
            let scale = window?.backingScaleFactor ?? 1.0
            return NSRect(
                x: round(rect.origin.x * scale) / scale,
                y: round(rect.origin.y * scale) / scale,
                width: round(rect.width * scale) / scale,
                height: round(rect.height * scale) / scale
            )
        }
        
        override var isOpaque: Bool { return false }
    }
    
    // MARK: - Visualization Engine
    class VisualizationView: NSOpenGLView {
        private var spectrumData: [Float] = Array(repeating: 0, count: 75) // 75 bars like classic Winamp
        private var shaderProgram: GLuint = 0
        private var barVertexBuffer: GLuint = 0
        private var isSetup = false
        
        override func prepareOpenGL() {
            super.prepareOpenGL()
            setupOpenGL()
        }
        
        private func setupOpenGL() {
            guard !isSetup else { return }
            
            // Enable blending for smooth bars
            glEnable(GLenum(GL_BLEND))
            glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
            
            // Set clear color to transparent
            glClearColor(0.0, 0.0, 0.0, 0.0)
            
            setupShaders()
            setupVertexBuffer()
            
            isSetup = true
        }
        
        private func setupShaders() {
            let vertexShaderSource = """
            #version 330 core
            layout (location = 0) in vec2 position;
            layout (location = 1) in float height;
            
            uniform float barWidth;
            uniform int barIndex;
            
            void main() {
                vec2 pos = position;
                pos.x = (float(barIndex) * barWidth) - 1.0 + (barWidth * 0.5);
                pos.y = pos.y * height;
                gl_Position = vec4(pos, 0.0, 1.0);
            }
            """
            
            let fragmentShaderSource = """
            #version 330 core
            out vec4 FragColor;
            
            uniform vec3 barColor;
            uniform float barHeight;
            
            void main() {
                // Classic green spectrum color with height-based intensity
                vec3 color = barColor * (0.3 + 0.7 * barHeight);
                FragColor = vec4(color, 1.0);
            }
            """
            
            // Compile shaders (simplified - in production you'd want proper error handling)
            let vertexShader = glCreateShader(GLenum(GL_VERTEX_SHADER))
            var source = vertexShaderSource.cString(using: .utf8)
            glShaderSource(vertexShader, 1, &source, nil)
            glCompileShader(vertexShader)
            
            let fragmentShader = glCreateShader(GLenum(GL_FRAGMENT_SHADER))
            source = fragmentShaderSource.cString(using: .utf8)
            glShaderSource(fragmentShader, 1, &source, nil)
            glCompileShader(fragmentShader)
            
            shaderProgram = glCreateProgram()
            glAttachShader(shaderProgram, vertexShader)
            glAttachShader(shaderProgram, fragmentShader)
            glLinkProgram(shaderProgram)
            
            glDeleteShader(vertexShader)
            glDeleteShader(fragmentShader)
        }
        
        private func setupVertexBuffer() {
            // Simple quad vertices for each bar
            let vertices: [Float] = [
                -0.5, 0.0,  // Bottom left
                 0.5, 0.0,  // Bottom right
                 0.5, 1.0,  // Top right
                -0.5, 1.0   // Top left
            ]
            
            glGenBuffers(1, &barVertexBuffer)
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), barVertexBuffer)
            glBufferData(GLenum(GL_ARRAY_BUFFER), vertices.count * MemoryLayout<Float>.size, vertices, GLenum(GL_STATIC_DRAW))
        }
        
        func updateSpectrum(_ data: [Float]) {
            // Ensure we have exactly 75 bars
            if data.count == spectrumData.count {
                spectrumData = data
            } else {
                // Resample data to 75 bars
                spectrumData = resampleAudioData(data, targetCount: 75)
            }
            needsDisplay = true
        }
        
        private func resampleAudioData(_ data: [Float], targetCount: Int) -> [Float] {
            guard data.count > 0 else { return Array(repeating: 0, count: targetCount) }
            
            var resampled: [Float] = []
            let ratio = Float(data.count) / Float(targetCount)
            
            for i in 0..<targetCount {
                let sourceIndex = Int(Float(i) * ratio)
                let clampedIndex = min(sourceIndex, data.count - 1)
                resampled.append(data[clampedIndex])
            }
            
            return resampled
        }
        
        override func draw(_ dirtyRect: NSRect) {
            openGLContext?.makeCurrentContext()
            
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            glUseProgram(shaderProgram)
            
            // Set uniforms
            let barWidthLocation = glGetUniformLocation(shaderProgram, "barWidth")
            let barIndexLocation = glGetUniformLocation(shaderProgram, "barIndex")
            let barColorLocation = glGetUniformLocation(shaderProgram, "barColor")
            let barHeightLocation = glGetUniformLocation(shaderProgram, "barHeight")
            
            let barWidth = 2.0 / Float(spectrumData.count)
            glUniform1f(barWidthLocation, barWidth)
            glUniform3f(barColorLocation, 0.0, 1.0, 0.0) // Classic green
            
            // Bind vertex buffer
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), barVertexBuffer)
            glVertexAttribPointer(0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 2 * Int32(MemoryLayout<Float>.size), nil)
            glEnableVertexAttribArray(0)
            
            // Draw each spectrum bar
            for (index, height) in spectrumData.enumerated() {
                glUniform1i(barIndexLocation, Int32(index))
                glUniform1f(barHeightLocation, height)
                
                glDrawArrays(GLenum(GL_TRIANGLE_FAN), 0, 4)
            }
            
            openGLContext?.flushBuffer()
        }
        
        override var isOpaque: Bool { return false }
    }
    
    // MARK: - Skin Window
    class SkinWindow: NSWindow {
        private var skinImage: NSImage?
        private var maskImage: NSImage?
        
        override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, 
                      backing backingType: NSWindow.BackingStoreType, defer flag: Bool) {
            super.init(contentRect: contentRect, 
                      styleMask: [.borderless, .miniaturizable, .closable], 
                      backing: backingType, 
                      defer: flag)
            
            setupWindow()
        }
        
        private func setupWindow() {
            isOpaque = false
            backgroundColor = .clear
            hasShadow = true
            level = .normal
            isMovableByWindowBackground = true
        }
        
        func applySkin(_ image: NSImage, mask: NSImage? = nil) {
            skinImage = image
            maskImage = mask
            
            // Resize window to match skin
            let newFrame = NSRect(origin: frame.origin, size: image.size)
            setFrame(newFrame, display: true)
            
            // Apply mask if provided
            if let mask = mask {
                applyShapeMask(mask)
            }
            
            contentView?.needsDisplay = true
        }
        
        private func applyShapeMask(_ mask: NSImage) {
            guard let cgImage = mask.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            
            // Create a path from the mask
            // This is simplified - in production you'd want to trace the alpha channel
            let path = NSBezierPath(rect: NSRect(origin: .zero, size: mask.size))
            
            contentView?.layer?.mask = CAShapeLayer()
            (contentView?.layer?.mask as? CAShapeLayer)?.path = path.cgPath
        }
        
        override var canBecomeKey: Bool { return true }
        override var canBecomeMain: Bool { return true }
    }
}

// MARK: - Usage Example
extension WinampRenderer {
    static func createExamplePlayer() -> SkinWindow {
        let assetManager = AssetManager()
        
        // Create window
        let window = SkinWindow(contentRect: NSRect(x: 100, y: 100, width: 275, height: 116),
                               styleMask: [], backing: .buffered, defer: false)
        window.title = "Winamp Player"
        
        // Load main skin image (you'd load this from your assets)
        if let mainSkin = NSImage(named: "main") {
            window.applySkin(mainSkin)
        }
        
        // Create content view
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        window.contentView = contentView
        
        // Add visualization
        let visFrame = NSRect(x: 24, y: 43, width: 76, height: 16) // Classic Winamp vis position
        let visualization = VisualizationView(frame: visFrame)
        contentView.addSubview(visualization)
        
        // Add time display
        if let digitAsset = assetManager.loadSkinAsset(named: "numbers", frameSize: CGSize(width: 9, height: 13), frameCount: 12) {
            let digitFrames = assetManager.extractFrames(from: digitAsset)
            let timeDisplay = WinampDisplay(digitFrames: digitFrames, assetManager: assetManager)
            timeDisplay.frame = NSRect(x: 39, y: 26, width: 59, height: 13)
            contentView.addSubview(timeDisplay)
            
            // Simulate time updates
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                timeDisplay.updateTime(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 3600))
            }
        }
        
        // Add control buttons
        if let buttonAsset = assetManager.loadSkinAsset(named: "cbuttons", frameSize: CGSize(width: 23, height: 18), frameCount: 3) {
            let buttonFrames = assetManager.extractFrames(from: buttonAsset)
            
            let playButton = WinampButton(frames: buttonFrames, assetManager: assetManager)
            playButton.frame = NSRect(x: 26, y: 88, width: 23, height: 18)
            playButton.setAction {
                print("Play button pressed!")
                // Simulate spectrum data
                let randomSpectrum = (0..<75).map { _ in Float.random(in: 0...1) }
                visualization.updateSpectrum(randomSpectrum)
            }
            contentView.addSubview(playButton)
        }
        
        return window
    }
}