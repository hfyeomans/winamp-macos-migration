import AppKit
import CoreGraphics
import QuartzCore

/// Custom NSWindow implementation for Winamp-style skinned windows
/// Features magnetic docking, custom shapes, and shaded mode
@MainActor
public final class WinampWindow: NSWindow {
    
    // MARK: - Properties
    private var skin: WinampSkin?
    private var isShaded: Bool = false
    private var originalSize: NSSize = .zero
    private var shadedSize: NSSize = NSSize(width: 275, height: 14)
    
    // MARK: - Magnetic Docking
    private let snapDistance: CGFloat = 8.0
    private var isDocking: Bool = false
    private var dockingWindows: [WinampWindow] = []
    
    // MARK: - Window Shape
    private var windowShape: NSBezierPath?
    private var shapeLayer: CAShapeLayer?
    
    // MARK: - Animation
    private var shadeAnimationDuration: TimeInterval = 0.25
    
    public override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .miniaturizable, .resizable], backing: backingStoreType, defer: flag)
        
        setupWindow()
    }
    
    // MARK: - Window Setup
    private func setupWindow() {
        // Configure window properties
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .normal
        acceptsMouseMovedEvents = true
        isMovableByWindowBackground = true
        
        // Set minimum size
        minSize = NSSize(width: 275, height: 116)
        originalSize = contentRect.size
        
        // Setup content view
        let contentView = WinampContentView()
        contentView.wantsLayer = true
        self.contentView = contentView
        
        // Add tracking area for mouse events
        addTrackingArea()
        
        // Register for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }
    
    private func addTrackingArea() {
        guard let contentView = contentView else { return }
        
        let trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
    }
    
    // MARK: - Skin Application
    public func applySkin(_ skin: WinampSkin) {
        self.skin = skin
        
        // Update window shape from skin regions
        updateWindowShape(from: skin)
        
        // Update content view with skin
        if let contentView = contentView as? WinampContentView {
            contentView.applySkin(skin)
        }
        
        // Update window title
        title = skin.name
        
        // Adjust size if needed
        if !isShaded {
            let skinSize = getSkinSize(from: skin)
            setContentSize(skinSize)
            originalSize = skinSize
        }
    }
    
    private func updateWindowShape(from skin: WinampSkin) {
        guard let mainRegion = skin.configuration.regions["main"] else { return }
        
        // Create window shape from region points using marching squares algorithm
        let shape = createSmoothShape(from: mainRegion)
        windowShape = shape
        
        // Apply shape to window
        applyWindowShape(shape)
    }
    
    private func createSmoothShape(from points: [CGPoint]) -> NSBezierPath {
        guard points.count > 2 else {
            // Fallback to rectangle
            return NSBezierPath(rect: frame)
        }
        
        let path = NSBezierPath()
        
        // Use marching squares algorithm for smooth edges
        let smoothedPoints = smoothPointsUsingMarchingSquares(points)
        
        if let firstPoint = smoothedPoints.first {
            path.move(to: firstPoint)
            
            // Create smooth curves between points
            for i in 1..<smoothedPoints.count {
                let currentPoint = smoothedPoints[i]
                let previousPoint = smoothedPoints[i - 1]
                
                // Calculate control points for smooth curves
                let controlPoint1 = CGPoint(
                    x: previousPoint.x + (currentPoint.x - previousPoint.x) * 0.3,
                    y: previousPoint.y + (currentPoint.y - previousPoint.y) * 0.3
                )
                let controlPoint2 = CGPoint(
                    x: currentPoint.x - (currentPoint.x - previousPoint.x) * 0.3,
                    y: currentPoint.y - (currentPoint.y - previousPoint.y) * 0.3
                )
                
                path.curve(to: currentPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
            }
            
            path.close()
        }
        
        return path
    }
    
    private func smoothPointsUsingMarchingSquares(_ points: [CGPoint]) -> [CGPoint] {
        // Simplified marching squares implementation
        var smoothedPoints: [CGPoint] = []
        
        for i in 0..<points.count {
            let current = points[i]
            let next = points[(i + 1) % points.count]
            let previous = points[(i - 1 + points.count) % points.count]
            
            // Calculate smoothed point
            let smoothedX = (previous.x + 2 * current.x + next.x) / 4
            let smoothedY = (previous.y + 2 * current.y + next.y) / 4
            
            smoothedPoints.append(CGPoint(x: smoothedX, y: smoothedY))
        }
        
        return smoothedPoints
    }
    
    private func applyWindowShape(_ shape: NSBezierPath) {
        // Create shape layer for smooth rendering
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = shape.cgPath
        shapeLayer.fillColor = NSColor.black.cgColor
        
        // Apply to window
        if let contentView = contentView {
            contentView.wantsLayer = true
            contentView.layer?.mask = shapeLayer
            self.shapeLayer = shapeLayer
        }
    }
    
    private func getSkinSize(from skin: WinampSkin) -> NSSize {
        guard let mainBitmap = skin.resources.bitmaps["main.bmp"] else {
            return NSSize(width: 275, height: 116) // Default Winamp size
        }
        
        return mainBitmap.size
    }
    
    // MARK: - Shaded Mode
    public func toggleShadedMode() {
        isShaded.toggle()
        
        if isShaded {
            enterShadedMode()
        } else {
            exitShadedMode()
        }
    }
    
    private func enterShadedMode() {
        // Store original size
        originalSize = frame.size
        
        // Animate to shaded size
        let newFrame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y + (frame.height - shadedSize.height),
            width: shadedSize.width,
            height: shadedSize.height
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = shadeAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(newFrame, display: true)
        }
        
        // Update window properties for shaded mode
        styleMask.remove(.resizable)
        
        // Hide non-essential UI elements
        if let contentView = contentView as? WinampContentView {
            contentView.setShadedMode(true)
        }
    }
    
    private func exitShadedMode() {
        // Animate back to original size
        let newFrame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y - (originalSize.height - shadedSize.height),
            width: originalSize.width,
            height: originalSize.height
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = shadeAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(newFrame, display: true)
        }
        
        // Restore window properties
        styleMask.insert(.resizable)
        
        // Show all UI elements
        if let contentView = contentView as? WinampContentView {
            contentView.setShadedMode(false)
        }
    }
    
    // MARK: - Magnetic Docking
    public func addDockingWindow(_ window: WinampWindow) {
        if !dockingWindows.contains(window) {
            dockingWindows.append(window)
        }
    }
    
    public func removeDockingWindow(_ window: WinampWindow) {
        dockingWindows.removeAll { $0 === window }
    }
    
    @objc private func windowDidMove() {
        guard !isDocking else { return }
        
        // Check for magnetic docking with other windows
        checkMagneticDocking()
    }
    
    private func checkMagneticDocking() {
        let windowFrame = frame
        
        for dockingWindow in dockingWindows {
            guard dockingWindow !== self else { continue }
            
            let otherFrame = dockingWindow.frame
            let snapPoint = calculateSnapPoint(from: windowFrame, to: otherFrame)
            
            if let snapPoint = snapPoint {
                isDocking = true
                
                // Animate to snap position
                let newFrame = NSRect(origin: snapPoint, size: windowFrame.size)
                
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.1
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    animator().setFrame(newFrame, display: true)
                } completionHandler: {
                    self.isDocking = false
                }
                
                break
            }
        }
    }
    
    private func calculateSnapPoint(from sourceFrame: NSRect, to targetFrame: NSRect) -> CGPoint? {
        let snapDistance = self.snapDistance
        
        // Check horizontal snapping (left/right edges)
        let leftToRight = abs(sourceFrame.minX - targetFrame.maxX)
        let rightToLeft = abs(sourceFrame.maxX - targetFrame.minX)
        let leftToLeft = abs(sourceFrame.minX - targetFrame.minX)
        let rightToRight = abs(sourceFrame.maxX - targetFrame.maxX)
        
        // Check vertical snapping (top/bottom edges)
        let topToBottom = abs(sourceFrame.maxY - targetFrame.minY)
        let bottomToTop = abs(sourceFrame.minY - targetFrame.maxY)
        let topToTop = abs(sourceFrame.maxY - targetFrame.maxY)
        let bottomToBottom = abs(sourceFrame.minY - targetFrame.minY)
        
        var snapPoint: CGPoint?
        
        // Horizontal snapping
        if leftToRight <= snapDistance {
            snapPoint = CGPoint(x: targetFrame.maxX, y: sourceFrame.origin.y)
        } else if rightToLeft <= snapDistance {
            snapPoint = CGPoint(x: targetFrame.minX - sourceFrame.width, y: sourceFrame.origin.y)
        } else if leftToLeft <= snapDistance {
            snapPoint = CGPoint(x: targetFrame.minX, y: sourceFrame.origin.y)
        } else if rightToRight <= snapDistance {
            snapPoint = CGPoint(x: targetFrame.maxX - sourceFrame.width, y: sourceFrame.origin.y)
        }
        
        // Vertical snapping
        if topToBottom <= snapDistance {
            snapPoint = CGPoint(x: sourceFrame.origin.x, y: targetFrame.minY - sourceFrame.height)
        } else if bottomToTop <= snapDistance {
            snapPoint = CGPoint(x: sourceFrame.origin.x, y: targetFrame.maxY)
        } else if topToTop <= snapDistance {
            snapPoint = CGPoint(x: sourceFrame.origin.x, y: targetFrame.maxY - sourceFrame.height)
        } else if bottomToBottom <= snapDistance {
            snapPoint = CGPoint(x: sourceFrame.origin.x, y: targetFrame.minY)
        }
        
        return snapPoint
    }
    
    // MARK: - Mouse Events
    public override func mouseDown(with event: NSEvent) {
        // Handle double-click for shaded mode toggle
        if event.clickCount == 2 {
            let location = event.locationInWindow
            
            // Check if double-click is in title bar area
            if isTitleBarLocation(location) {
                toggleShadedMode()
                return
            }
        }
        
        super.mouseDown(with: event)
    }
    
    private func isTitleBarLocation(_ location: NSPoint) -> Bool {
        // Title bar is typically the top portion of the window
        let titleBarHeight: CGFloat = 20
        let titleBarRect = NSRect(
            x: 0,
            y: frame.height - titleBarHeight,
            width: frame.width,
            height: titleBarHeight
        )
        
        return titleBarRect.contains(location)
    }
    
    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Custom Content View
@MainActor
private final class WinampContentView: NSView {
    private var skin: WinampSkin?
    private var isShadedMode: Bool = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    func applySkin(_ skin: WinampSkin) {
        self.skin = skin
        needsDisplay = true
    }
    
    func setShadedMode(_ shaded: Bool) {
        isShadedMode = shaded
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let skin = skin else { return }
        
        // Draw appropriate bitmap based on mode
        let bitmapKey = isShadedMode ? "mb.bmp" : "main.bmp"
        
        if let bitmap = skin.resources.bitmaps[bitmapKey] {
            bitmap.draw(in: bounds)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - Window Manager
@MainActor
public final class WinampWindowManager: ObservableObject {
    public static let shared = WinampWindowManager()
    
    @Published public private(set) var windows: [WinampWindow] = []
    private var windowControllers: [NSWindowController] = []
    
    private init() {}
    
    public func createMainWindow(with skin: WinampSkin? = nil) -> WinampWindow {
        let contentRect = NSRect(x: 100, y: 100, width: 275, height: 116)
        let window = WinampWindow(contentRect: contentRect, styleMask: [], backing: .buffered, defer: false)
        
        if let skin = skin {
            window.applySkin(skin)
        }
        
        // Setup window controller
        let controller = NSWindowController(window: window)
        windowControllers.append(controller)
        
        // Add to magnetic docking system
        for existingWindow in windows {
            window.addDockingWindow(existingWindow)
            existingWindow.addDockingWindow(window)
        }
        
        windows.append(window)
        
        return window
    }
    
    public func createEqualizerWindow(with skin: WinampSkin? = nil) -> WinampWindow {
        let contentRect = NSRect(x: 200, y: 200, width: 275, height: 116)
        let window = WinampWindow(contentRect: contentRect, styleMask: [], backing: .buffered, defer: false)
        
        window.title = "Equalizer"
        
        if let skin = skin {
            window.applySkin(skin)
        }
        
        // Setup window controller
        let controller = NSWindowController(window: window)
        windowControllers.append(controller)
        
        // Add to magnetic docking system
        for existingWindow in windows {
            window.addDockingWindow(existingWindow)
            existingWindow.addDockingWindow(window)
        }
        
        windows.append(window)
        
        return window
    }
    
    public func createPlaylistWindow(with skin: WinampSkin? = nil) -> WinampWindow {
        let contentRect = NSRect(x: 300, y: 300, width: 275, height: 232)
        let window = WinampWindow(contentRect: contentRect, styleMask: [], backing: .buffered, defer: false)
        
        window.title = "Playlist"
        
        if let skin = skin {
            window.applySkin(skin)
        }
        
        // Setup window controller
        let controller = NSWindowController(window: window)
        windowControllers.append(controller)
        
        // Add to magnetic docking system
        for existingWindow in windows {
            window.addDockingWindow(existingWindow)
            existingWindow.addDockingWindow(window)
        }
        
        windows.append(window)
        
        return window
    }
    
    public func closeWindow(_ window: WinampWindow) {
        // Remove from docking system
        for otherWindow in windows {
            otherWindow.removeDockingWindow(window)
        }
        
        // Remove from tracking
        windows.removeAll { $0 === window }
        windowControllers.removeAll { $0.window === window }
        
        window.close()
    }
    
    public func closeAllWindows() {
        for window in windows {
            window.close()
        }
        windows.removeAll()
        windowControllers.removeAll()
    }
    
    public func applySkinToAllWindows(_ skin: WinampSkin) {
        for window in windows {
            window.applySkin(skin)
        }
    }
}