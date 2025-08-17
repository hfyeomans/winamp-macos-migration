import Cocoa
import Metal
import MetalKit
import CoreAnimation
import QuartzCore

/// Modern custom window implementation using NSBezierPath for non-rectangular shapes
/// Optimized for macOS 15.0+ with ProMotion display support
class CustomSkinWindow: NSWindow {
    
    // MARK: - Properties
    private var skinRenderer: MetalSkinRenderer?
    private var metalView: MTKView!
    private var skinShape: NSBezierPath?
    private var shadowLayer: CALayer?
    private var isResizing = false
    
    // Display optimization
    private var displayLink: CVDisplayLink?
    private var isProMotionDisplay = false
    private var preferredFrameRate: Int = 60
    
    // Animation support
    private var animationLayers: [CALayer] = []
    private var skinAnimator: SkinAnimator?
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: backingStoreType, defer: flag)
        
        setupWindow()
        setupMetalView()
        setupDisplayLink()
        configureForSkinRendering()
    }
    
    private func setupWindow() {
        // Configure window for custom skin rendering
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Enable layer backing for performance
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Configure for high DPI displays
        contentView?.layer?.contentsScale = backingScaleFactor
        
        // Detect ProMotion displays
        detectDisplayCapabilities()
    }
    
    private func setupMetalView() {
        do {
            skinRenderer = try MetalSkinRenderer()
            
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal not supported on this device")
            }
            
            metalView = MTKView(frame: contentView?.bounds ?? .zero, device: device)
            metalView.delegate = self
            metalView.framebufferOnly = false
            metalView.colorPixelFormat = .bgra8Unorm
            metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            metalView.isPaused = true // Use on-demand rendering
            metalView.enableSetNeedsDisplay = true
            
            // Configure for Retina displays
            metalView.layer?.contentsScale = backingScaleFactor
            
            // Optimize for ProMotion displays
            if isProMotionDisplay {
                metalView.preferredFramesPerSecond = 120
            } else {
                metalView.preferredFramesPerSecond = 60
            }
            
            contentView?.addSubview(metalView)
            metalView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                metalView.topAnchor.constraint(equalTo: contentView!.topAnchor),
                metalView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
                metalView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
                metalView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor)
            ])
            
        } catch {
            fatalError("Failed to initialize Metal renderer: \(error)")
        }
    }
    
    private func detectDisplayCapabilities() {
        if let screen = screen {
            let refreshRate = screen.maximumFramesPerSecond
            isProMotionDisplay = refreshRate > 60
            preferredFrameRate = isProMotionDisplay ? 120 : 60
            
            print("Window display capabilities - Refresh rate: \(refreshRate)Hz, ProMotion: \(isProMotionDisplay)")
        }
    }
    
    private func setupDisplayLink() {
        guard let screen = screen else { return }
        
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
        
        CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink)
        
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, { (displayLink, now, outputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
                
                if let context = displayLinkContext {
                    let window = Unmanaged<CustomSkinWindow>.fromOpaque(context).takeUnretainedValue()
                    DispatchQueue.main.async {
                        window.displayLinkCallback()
                    }
                }
                
                return kCVReturnSuccess
            }, Unmanaged.passUnretained(self).toOpaque())
        }
    }
    
    private func displayLinkCallback() {
        guard !isResizing else { return }
        
        // Only update if renderer indicates we shouldn't limit frame rate
        if let renderer = skinRenderer, !renderer.shouldLimitFrameRate() {
            metalView.needsDisplay = true
            
            // Update animations
            skinAnimator?.updateAnimations()
        }
    }
    
    private func configureForSkinRendering() {
        // Initialize animation system
        skinAnimator = SkinAnimator()
        
        // Configure shadow layer for custom shapes
        setupShadowLayer()
    }
    
    private func setupShadowLayer() {
        shadowLayer = CALayer()
        shadowLayer?.shadowColor = NSColor.black.cgColor
        shadowLayer?.shadowOpacity = 0.3
        shadowLayer?.shadowOffset = CGSize(width: 0, height: -2)
        shadowLayer?.shadowRadius = 4
        
        contentView?.layer?.insertSublayer(shadowLayer!, at: 0)
    }
    
    // MARK: - Skin Shape Management
    
    /// Apply custom shape to window using NSBezierPath for non-rectangular skins
    func applySkinShape(_ shape: NSBezierPath, animated: Bool = true) {
        skinShape = shape
        
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.3)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        }
        
        // Update window frame to match shape bounds
        let shapeBounds = shape.bounds
        let newFrame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: shapeBounds.width,
            height: shapeBounds.height
        )
        
        setFrame(newFrame, display: true, animate: animated)
        
        // Update metal view to match new bounds
        metalView.frame = contentView?.bounds ?? .zero
        
        // Create mask for the custom shape
        createShapeMask(from: shape)
        
        // Update shadow to match new shape
        updateShadowPath(shape)
        
        if animated {
            CATransaction.commit()
        }
    }
    
    private func createShapeMask(from shape: NSBezierPath) {
        let maskLayer = CAShapeLayer()
        maskLayer.path = shape.cgPath
        maskLayer.fillColor = NSColor.white.cgColor
        
        // Apply mask to content view
        contentView?.layer?.mask = maskLayer
        
        // Ensure metal view respects the mask
        metalView.layer?.mask = maskLayer.copy() as? CALayer
    }
    
    private func updateShadowPath(_ shape: NSBezierPath) {
        shadowLayer?.shadowPath = shape.cgPath
    }
    
    // MARK: - Hit Testing for Non-Rectangular Windows
    
    override func mouseLocationOutsideOfEventStream() -> NSPoint {
        let location = super.mouseLocationOutsideOfEventStream()
        return contentView?.convert(location, from: nil) ?? location
    }
    
    override func contains(_ point: NSPoint) -> Bool {
        guard let shape = skinShape else {
            return super.contains(point)
        }
        
        let windowPoint = contentView?.convert(point, from: nil) ?? point
        return shape.contains(windowPoint)
    }
    
    // Efficient hit testing using shape bounds first, then precise path testing
    private func isPointInSkinShape(_ point: NSPoint) -> Bool {
        guard let shape = skinShape else { return true }
        
        // Quick bounds check first
        if !shape.bounds.contains(point) {
            return false
        }
        
        // Precise shape testing
        return shape.contains(point)
    }
    
    // MARK: - Retina Display Handling
    
    override func backingPropertiesChanged() {
        super.backingPropertiesChanged()
        
        let newScale = backingScaleFactor
        
        // Update Metal view for new scale
        metalView.layer?.contentsScale = newScale
        contentView?.layer?.contentsScale = newScale
        
        // Update shadow layer scale
        shadowLayer?.contentsScale = newScale
        
        // Notify renderer of scale change
        metalView.needsDisplay = true
    }
    
    // MARK: - Window Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupWindow()
    }
    
    override func close() {
        // Stop display link
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
        
        // Clean up animation system
        skinAnimator?.cleanup()
        
        super.close()
    }
    
    // MARK: - Animation Support
    
    func addAnimationLayer(_ layer: CALayer) {
        animationLayers.append(layer)
        contentView?.layer?.addSublayer(layer)
    }
    
    func removeAnimationLayer(_ layer: CALayer) {
        if let index = animationLayers.firstIndex(of: layer) {
            animationLayers.remove(at: index)
            layer.removeFromSuperlayer()
        }
    }
    
    // MARK: - Performance Optimization
    
    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        isResizing = animateFlag
        
        super.setFrame(frameRect, display: displayFlag, animate: animateFlag)
        
        if !animateFlag {
            isResizing = false
        }
    }
    
    func startDisplayUpdates() {
        if let displayLink = displayLink {
            CVDisplayLinkStart(displayLink)
        }
    }
    
    func stopDisplayUpdates() {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
}

// MARK: - MTKViewDelegate

extension CustomSkinWindow: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle drawable size changes for window resizing
        print("Metal view size changed to: \(size)")
    }
    
    func draw(in view: MTKView) {
        guard let renderer = skinRenderer,
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        // Create projection matrix for the view
        let viewSize = view.bounds.size
        let projectionMatrix = createOrthographicMatrix(
            left: 0,
            right: Float(viewSize.width),
            bottom: Float(viewSize.height),
            top: 0,
            near: -1,
            far: 1
        )
        
        // Get sprites from skin system (would be injected from skin loader)
        let sprites: [SkinSprite] = [] // TODO: Connect to skin loading system
        
        do {
            try renderer.render(
                sprites: sprites,
                in: renderPassDescriptor,
                viewMatrix: projectionMatrix
            )
            
            drawable.present()
        } catch {
            print("Rendering error: \(error)")
        }
    }
    
    private func createOrthographicMatrix(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
        let width = right - left
        let height = top - bottom
        let depth = far - near
        
        return simd_float4x4(rows: [
            simd_float4(2.0/width, 0, 0, -(right + left)/width),
            simd_float4(0, 2.0/height, 0, -(top + bottom)/height),
            simd_float4(0, 0, -2.0/depth, -(far + near)/depth),
            simd_float4(0, 0, 0, 1)
        ])
    }
}

// MARK: - Skin Animation System

class SkinAnimator {
    private var animationGroups: [String: CAAnimationGroup] = [:]
    private var isAnimating = false
    
    func addButtonAnimation(for identifier: String, normalState: CALayer, hoverState: CALayer, pressedState: CALayer) {
        // Create smooth transitions between button states
        let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
        fadeOutAnimation.fromValue = 1.0
        fadeOutAnimation.toValue = 0.0
        fadeOutAnimation.duration = 0.1
        
        let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
        fadeInAnimation.fromValue = 0.0
        fadeInAnimation.toValue = 1.0
        fadeInAnimation.duration = 0.1
        fadeInAnimation.beginTime = 0.1
        
        let group = CAAnimationGroup()
        group.animations = [fadeOutAnimation, fadeInAnimation]
        group.duration = 0.2
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        
        animationGroups[identifier] = group
    }
    
    func updateAnimations() {
        // Update any time-based animations
        guard isAnimating else { return }
        
        // Update visualization animations, spectrum displays, etc.
    }
    
    func cleanup() {
        animationGroups.removeAll()
        isAnimating = false
    }
}

// MARK: - Supporting Structures

struct SkinSprite {
    let bounds: CGRect
    let textureCoordinates: CGRect
    let texture: MTLTexture
    let tintColor: simd_float4
    let zOrder: Float
    
    init(bounds: CGRect, textureCoordinates: CGRect, texture: MTLTexture, tintColor: NSColor = .white, zOrder: Float = 0) {
        self.bounds = bounds
        self.textureCoordinates = textureCoordinates
        self.texture = texture
        self.zOrder = zOrder
        
        // Convert NSColor to simd_float4
        let rgbColor = tintColor.usingColorSpace(.sRGB) ?? .white
        self.tintColor = simd_float4(
            Float(rgbColor.redComponent),
            Float(rgbColor.greenComponent),
            Float(rgbColor.blueComponent),
            Float(rgbColor.alphaComponent)
        )
    }
}

// MARK: - NSBezierPath Extensions

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        
        return path
    }
}