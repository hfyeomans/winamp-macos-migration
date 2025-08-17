//
//  ModernSkinWindow.swift
//  WinampMac
//
//  Modern skin window with NSBezierPath hit-testing
//  Replaces pixel-by-pixel alpha checking with efficient path-based testing
//  Compatible with macOS 15.0+ and future-proofed for macOS 26.x
//

import Cocoa
import CoreGraphics
import OSLog

/// Modern skin window with efficient shape-based hit testing
@available(macOS 15.0, *)
public final class ModernSkinWindow: NSWindow {
    
    // MARK: - Logger
    private static let logger = Logger(subsystem: "com.winamp.mac.ui", category: "SkinWindow")
    
    // MARK: - Window Shape and Hit Testing
    private var windowShape: NSBezierPath?
    private var hitTestRegions: [String: HitTestRegion] = [:]
    private var dragRegions: [DragRegion] = []
    private var isShapedWindow = false
    
    // MARK: - Skin Assets
    private var skinImage: NSImage?
    private var maskImage: NSImage?
    private var backgroundLayer: CALayer?
    
    // MARK: - Window Behavior
    private var isDraggable = true
    private var snapDistance: CGFloat = 10.0
    private var snapToScreenEdges = true
    private var snapToOtherWindows = true
    
    // MARK: - Hit Test Structures
    public struct HitTestRegion {
        let path: NSBezierPath
        let action: HitTestAction
        let cursor: NSCursor?
        let tooltip: String?
        
        public enum HitTestAction {
            case none
            case button(String)
            case slider(String)
            case dragWindow
            case resizeWindow(ResizeDirection)
            case custom(String)
        }
        
        public enum ResizeDirection {
            case horizontal
            case vertical
            case both
        }
    }
    
    public struct DragRegion {
        let path: NSBezierPath
        let behavior: DragBehavior
        
        public enum DragBehavior {
            case moveWindow
            case titleBar
            case custom(handler: (NSPoint) -> Void)
        }
    }
    
    // MARK: - Initialization
    public override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, 
                        backing backingType: NSWindow.BackingStoreType, defer flag: Bool) {
        
        // Force borderless style for custom window shape
        let customStyle: NSWindow.StyleMask = [.borderless, .miniaturizable, .closable]
        
        super.init(contentRect: contentRect, styleMask: customStyle, 
                  backing: backingType, defer: flag)
        
        setupModernWindow()
        setupHitTesting()
        setupLayerBackedView()
    }
    
    // MARK: - Window Setup
    private func setupModernWindow() {
        // Basic window properties
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .normal
        
        // Modern window features
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // Enable layer backing for better performance
        contentView?.wantsLayer = true
        contentView?.layer?.masksToBounds = false
        
        // Set up accessibility
        isAccessibilityElement = true
        accessibilityRole = .window
        accessibilityLabel = "Winamp Player"
        
        // Performance optimizations
        useOptimizedDrawing = true
        if #available(macOS 12.0, *) {
            wantsBestResolutionOpenGLSurface = true
        }
    }
    
    private func setupHitTesting() {
        // Set up tracking areas for mouse events
        setupTrackingAreas()
        
        // Configure window to handle mouse events
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
    }
    
    private func setupLayerBackedView() {
        guard let contentView = contentView else { return }
        
        contentView.wantsLayer = true
        
        // Create background layer for skin image
        backgroundLayer = CALayer()
        backgroundLayer?.contentsGravity = .resize
        backgroundLayer?.masksToBounds = true
        
        contentView.layer?.addSublayer(backgroundLayer!)
        
        // Configure for Retina displays
        if let screen = screen {
            backgroundLayer?.contentsScale = screen.backingScaleFactor
        }
    }
    
    private func setupTrackingAreas() {
        guard let contentView = contentView else { return }
        
        // Remove existing tracking areas
        for trackingArea in contentView.trackingAreas {
            contentView.removeTrackingArea(trackingArea)
        }
        
        // Add new tracking area covering the entire content view
        let trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [
                .activeInKeyWindow,
                .mouseEnteredAndExited,
                .mouseMoved,
                .cursorUpdate,
                .enabledDuringMouseDrag
            ],
            owner: self,
            userInfo: nil
        )
        
        contentView.addTrackingArea(trackingArea)
    }
    
    // MARK: - Skin Application
    public func applySkin(_ image: NSImage, maskImage: NSImage? = nil) {
        self.skinImage = image
        self.maskImage = maskImage
        
        // Update window size to match skin
        let newSize = image.size
        let currentOrigin = frame.origin
        let newFrame = NSRect(origin: currentOrigin, size: newSize)
        setFrame(newFrame, display: true, animate: false)
        
        // Update background layer
        backgroundLayer?.contents = image
        backgroundLayer?.frame = NSRect(origin: .zero, size: newSize)
        
        // Apply window shape if mask is provided
        if let mask = maskImage {
            applyWindowShape(from: mask)
        } else {
            // Generate shape from image alpha channel
            generateShapeFromImage(image)
        }
        
        // Update tracking areas after size change
        setupTrackingAreas()
        
        Self.logger.info("Applied skin: \(image.size)")
    }
    
    private func applyWindowShape(from maskImage: NSImage) {
        guard let cgImage = maskImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Self.logger.warning("Failed to get CGImage from mask")
            return
        }
        
        // Create NSBezierPath from mask image alpha channel
        let shapePath = createPathFromAlphaChannel(cgImage)
        setWindowShape(shapePath)
    }
    
    private func generateShapeFromImage(_ image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Self.logger.warning("Failed to get CGImage from skin image")
            return
        }
        
        // Create path from image alpha channel with threshold
        let shapePath = createPathFromAlphaChannel(cgImage, alphaThreshold: 0.1)
        setWindowShape(shapePath)
    }
    
    private func createPathFromAlphaChannel(_ cgImage: CGImage, alphaThreshold: Float = 0.0) -> NSBezierPath {
        let width = cgImage.width
        let height = cgImage.height
        
        // Create bitmap context to read pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Self.logger.error("Failed to create CGContext for shape generation")
            return NSBezierPath(rect: NSRect(origin: .zero, size: NSSize(width: width, height: height)))
        }
        
        // Draw image into context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Create path by tracing alpha channel
        let path = NSBezierPath()
        let threshold = UInt8(alphaThreshold * 255)
        
        // Use marching squares algorithm for better path generation
        let marchingPath = generateMarchingSquaresPath(
            pixelData: pixelData,
            width: width,
            height: height,
            threshold: threshold
        )
        
        // Transform to window coordinates (flip Y)
        var transform = AffineTransform.identity
        transform.scale(x: 1.0, y: -1.0)
        transform.translate(x: 0, y: -CGFloat(height))
        
        marchingPath.transform(using: transform)
        
        return marchingPath
    }
    
    private func generateMarchingSquaresPath(pixelData: [UInt8], width: Int, height: Int, threshold: UInt8) -> NSBezierPath {
        let path = NSBezierPath()
        
        // Simplified marching squares implementation
        // For production, you'd want a more sophisticated algorithm
        
        var isInside = false
        let step = max(1, min(width, height) / 100) // Adaptive step size
        
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let pixelIndex = (y * width + x) * 4 + 3 // Alpha channel
                if pixelIndex < pixelData.count {
                    let alpha = pixelData[pixelIndex]
                    let shouldBeInside = alpha > threshold
                    
                    if shouldBeInside && !isInside {
                        // Entering opaque region
                        if path.isEmpty {
                            path.move(to: NSPoint(x: x, y: y))
                        } else {
                            path.line(to: NSPoint(x: x, y: y))
                        }
                        isInside = true
                    } else if !shouldBeInside && isInside {
                        // Leaving opaque region
                        path.line(to: NSPoint(x: x, y: y))
                        isInside = false
                    }
                }
            }
            
            if isInside {
                // Continue line to next row
                path.line(to: NSPoint(x: width, y: y))
            }
        }
        
        path.close()
        
        // Smooth the path
        return smoothBezierPath(path)
    }
    
    private func smoothBezierPath(_ path: NSBezierPath) -> NSBezierPath {
        // Apply smoothing to reduce jagged edges
        let smoothedPath = NSBezierPath()
        
        if path.elementCount > 0 {
            var points: [NSPoint] = []
            
            // Extract points from path
            for i in 0..<path.elementCount {
                var pointArray = [NSPoint](repeating: NSPoint.zero, count: 3)
                let element = path.element(at: i, associatedPoints: &pointArray)
                
                switch element {
                case .moveTo, .lineTo:
                    points.append(pointArray[0])
                case .curveTo:
                    points.append(pointArray[2])
                case .closePath:
                    break
                @unknown default:
                    break
                }
            }
            
            // Apply smoothing filter
            if points.count > 2 {
                smoothedPath.move(to: points[0])
                
                for i in 1..<(points.count - 1) {
                    let p0 = points[i - 1]
                    let p1 = points[i]
                    let p2 = points[i + 1]
                    
                    // Calculate smooth curve points
                    let cp1 = NSPoint(
                        x: p0.x + (p1.x - p0.x) * 0.3,
                        y: p0.y + (p1.y - p0.y) * 0.3
                    )
                    let cp2 = NSPoint(
                        x: p1.x + (p2.x - p1.x) * 0.3,
                        y: p1.y + (p2.y - p1.y) * 0.3
                    )
                    
                    smoothedPath.curve(to: p1, controlPoint1: cp1, controlPoint2: cp2)
                }
                
                smoothedPath.line(to: points.last!)
                smoothedPath.close()
            }
        }
        
        return smoothedPath.isEmpty ? path : smoothedPath
    }
    
    private func setWindowShape(_ path: NSBezierPath) {
        windowShape = path
        isShapedWindow = true
        
        // Apply shape to window
        if #available(macOS 11.0, *) {
            // Use modern shape API
            contentView?.layer?.mask = createShapeLayer(from: path)
        } else {
            // Fallback for older systems
            invalidateShadow()
        }
        
        Self.logger.debug("Applied window shape with \(path.elementCount) elements")
    }
    
    @available(macOS 11.0, *)
    private func createShapeLayer(from path: NSBezierPath) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillRule = .evenOdd
        return shapeLayer
    }
    
    // MARK: - Hit Testing
    public override func mouseDown(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        
        // Check hit test regions first
        if let hitRegion = hitTestRegion(at: locationInWindow) {
            handleHitTestAction(hitRegion.action, at: locationInWindow, event: event)
            return
        }
        
        // Check drag regions
        if let dragRegion = dragRegion(at: locationInWindow) {
            handleDragAction(dragRegion.behavior, event: event)
            return
        }
        
        // Default behavior
        super.mouseDown(with: event)
    }
    
    private func hitTestRegion(at point: NSPoint) -> HitTestRegion? {
        for (_, region) in hitTestRegions {
            if region.path.contains(point) {
                return region
            }
        }
        return nil
    }
    
    private func dragRegion(at point: NSPoint) -> DragRegion? {
        return dragRegions.first { $0.path.contains(point) }
    }
    
    private func handleHitTestAction(_ action: HitTestRegion.HitTestAction, at point: NSPoint, event: NSEvent) {
        switch action {
        case .none:
            break
            
        case .button(let buttonId):
            NotificationCenter.default.post(
                name: .winampButtonPressed,
                object: self,
                userInfo: ["buttonId": buttonId, "location": point]
            )
            
        case .slider(let sliderId):
            NotificationCenter.default.post(
                name: .winampSliderChanged,
                object: self,
                userInfo: ["sliderId": sliderId, "location": point]
            )
            
        case .dragWindow:
            performDrag(with: event)
            
        case .resizeWindow(let direction):
            performResize(direction: direction, with: event)
            
        case .custom(let customAction):
            NotificationCenter.default.post(
                name: .winampCustomAction,
                object: self,
                userInfo: ["action": customAction, "location": point]
            )
        }
    }
    
    private func handleDragAction(_ behavior: DragRegion.DragBehavior, event: NSEvent) {
        switch behavior {
        case .moveWindow, .titleBar:
            performDrag(with: event)
            
        case .custom(let handler):
            handler(event.locationInWindow)
        }
    }
    
    // MARK: - Window Dragging with Snapping
    public override func mouseDragged(with event: NSEvent) {
        guard isDraggable else {
            super.mouseDragged(with: event)
            return
        }
        
        let currentLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: currentLocation.x - event.locationInWindow.x,
            y: currentLocation.y - event.locationInWindow.y
        )
        
        let snappedOrigin = applySnapping(to: newOrigin)
        setFrameOrigin(snappedOrigin)
    }
    
    private func applySnapping(to origin: NSPoint) -> NSPoint {
        var snappedOrigin = origin
        
        if snapToScreenEdges {
            snappedOrigin = snapToScreen(origin)
        }
        
        if snapToOtherWindows {
            snappedOrigin = snapToWindows(snappedOrigin)
        }
        
        return snappedOrigin
    }
    
    private func snapToScreen(_ origin: NSPoint) -> NSPoint {
        guard let screen = screen else { return origin }
        
        var snappedOrigin = origin
        let screenFrame = screen.visibleFrame
        let windowSize = frame.size
        
        // Snap to left edge
        if abs(origin.x - screenFrame.minX) < snapDistance {
            snappedOrigin.x = screenFrame.minX
        }
        
        // Snap to right edge
        if abs(origin.x + windowSize.width - screenFrame.maxX) < snapDistance {
            snappedOrigin.x = screenFrame.maxX - windowSize.width
        }
        
        // Snap to top edge
        if abs(origin.y + windowSize.height - screenFrame.maxY) < snapDistance {
            snappedOrigin.y = screenFrame.maxY - windowSize.height
        }
        
        // Snap to bottom edge
        if abs(origin.y - screenFrame.minY) < snapDistance {
            snappedOrigin.y = screenFrame.minY
        }
        
        return snappedOrigin
    }
    
    private func snapToWindows(_ origin: NSPoint) -> NSPoint {
        var snappedOrigin = origin
        let windowSize = frame.size
        
        // Check other Winamp windows
        let otherWindows = NSApp.windows.filter { window in
            window !== self && 
            window is ModernSkinWindow &&
            window.isVisible
        }
        
        for otherWindow in otherWindows {
            let otherFrame = otherWindow.frame
            
            // Horizontal snapping
            if abs(origin.x - otherFrame.maxX) < snapDistance {
                snappedOrigin.x = otherFrame.maxX
            } else if abs(origin.x + windowSize.width - otherFrame.minX) < snapDistance {
                snappedOrigin.x = otherFrame.minX - windowSize.width
            }
            
            // Vertical snapping
            if abs(origin.y - otherFrame.maxY) < snapDistance {
                snappedOrigin.y = otherFrame.maxY
            } else if abs(origin.y + windowSize.height - otherFrame.minY) < snapDistance {
                snappedOrigin.y = otherFrame.minY - windowSize.height
            }
        }
        
        return snappedOrigin
    }
    
    // MARK: - Mouse Tracking
    public override func mouseMoved(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        updateCursor(for: locationInWindow)
        updateTooltip(for: locationInWindow)
        super.mouseMoved(with: event)
    }
    
    private func updateCursor(for point: NSPoint) {
        if let region = hitTestRegion(at: point), let cursor = region.cursor {
            cursor.set()
        } else {
            NSCursor.arrow.set()
        }
    }
    
    private func updateTooltip(for point: NSPoint) {
        if let region = hitTestRegion(at: point), let tooltip = region.tooltip {
            // Show tooltip - you'd implement a custom tooltip system here
            showTooltip(tooltip, at: point)
        } else {
            hideTooltip()
        }
    }
    
    private func showTooltip(_ text: String, at point: NSPoint) {
        // Implementation for custom tooltip display
        // This would show a floating tooltip window
    }
    
    private func hideTooltip() {
        // Implementation to hide tooltip
    }
    
    // MARK: - Window State
    public override var canBecomeKey: Bool { return true }
    public override var canBecomeMain: Bool { return true }
    
    // MARK: - Public Configuration
    public func addHitTestRegion(_ region: HitTestRegion, named name: String) {
        hitTestRegions[name] = region
    }
    
    public func removeHitTestRegion(named name: String) {
        hitTestRegions.removeValue(forKey: name)
    }
    
    public func addDragRegion(_ region: DragRegion) {
        dragRegions.append(region)
    }
    
    public func clearDragRegions() {
        dragRegions.removeAll()
    }
    
    public func setSnapDistance(_ distance: CGFloat) {
        snapDistance = distance
    }
    
    public func setSnappingEnabled(toScreenEdges: Bool, toOtherWindows: Bool) {
        snapToScreenEdges = toScreenEdges
        snapToOtherWindows = toOtherWindows
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let winampButtonPressed = Notification.Name("WinampButtonPressed")
    static let winampSliderChanged = Notification.Name("WinampSliderChanged") 
    static let winampCustomAction = Notification.Name("WinampCustomAction")
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