import Cocoa
import CoreAnimation
import QuartzCore

// MARK: - Winamp macOS Interaction Pattern Specifications
// Implementation guide for preserving Winamp behaviors while respecting macOS conventions

/// Core interaction behaviors that define the Winamp experience on macOS
protocol WinampInteractionBehavior {
    func configureWindowDocking()
    func setupShadedModeTransitions()
    func implementPlaylistDragDrop()
    func configureSkinSwitching()
    func setupAccessibilityLayer()
}

// MARK: - Window Docking & Magnetic Snapping

class WinampWindowDockingManager: NSObject {
    
    private let magneticThreshold: CGFloat = 8.0
    private let snapAnimationDuration: TimeInterval = 0.15
    private var dockedWindows: Set<NSWindow> = []
    private var dockingGuides: [CALayer] = []
    
    enum DockingEdge {
        case left, right, top, bottom
        case window(NSWindow)
    }
    
    struct DockingConfiguration {
        let enableVisualGuides: Bool = true
        let enableHapticFeedback: Bool = true
        let enableSnapSound: Bool = false  // Respects system sound settings
        let preserveGrouping: Bool = true
    }
    
    /// Initialize docking behavior for a Winamp window
    func setupDocking(for window: NSWindow, configuration: DockingConfiguration = DockingConfiguration()) {
        // Add window to docking system
        dockedWindows.insert(window)
        
        // Setup mouse tracking for magnetic behavior
        setupMagneticTracking(for: window)
        
        // Configure visual feedback
        if configuration.enableVisualGuides {
            setupDockingGuides(for: window)
        }
    }
    
    private func setupMagneticTracking(for window: NSWindow) {
        // Monitor window dragging for magnetic snap zones
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: window
        )
    }
    
    @objc private func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        let currentFrame = window.frame
        let snapTargets = findSnapTargets(for: window)
        
        if let snapTarget = findClosestSnapTarget(currentFrame, targets: snapTargets) {
            showDockingGuide(for: snapTarget)
            
            // Apply magnetic pull if within threshold
            if distanceToSnapTarget(currentFrame, target: snapTarget) <= magneticThreshold {
                performMagneticSnap(window: window, to: snapTarget)
            }
        } else {
            hideDockingGuides()
        }
    }
    
    private func findSnapTargets(for window: NSWindow) -> [DockingTarget] {
        var targets: [DockingTarget] = []
        
        // Screen edges
        if let screen = window.screen {
            let screenFrame = screen.visibleFrame
            targets.append(contentsOf: [
                DockingTarget(type: .screenEdge(.left), frame: screenFrame),
                DockingTarget(type: .screenEdge(.right), frame: screenFrame),
                DockingTarget(type: .screenEdge(.top), frame: screenFrame),
                DockingTarget(type: .screenEdge(.bottom), frame: screenFrame)
            ])
        }
        
        // Other Winamp windows
        for otherWindow in dockedWindows where otherWindow != window {
            targets.append(DockingTarget(type: .window(otherWindow), frame: otherWindow.frame))
        }
        
        return targets
    }
    
    private func performMagneticSnap(window: NSWindow, to target: DockingTarget) {
        let snapFrame = calculateSnapFrame(for: window, to: target)
        
        // Animate to snap position
        NSAnimationContext.runAnimationGroup { context in
            context.duration = snapAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            window.animator().setFrame(snapFrame, display: true)
        }
        
        // Provide haptic feedback if available
        if #available(macOS 10.11, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .now
            )
        }
    }
    
    private func showDockingGuide(for target: DockingTarget) {
        // Create visual guide showing snap position
        let guideLayer = CALayer()
        guideLayer.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        guideLayer.frame = target.guideFrame
        guideLayer.cornerRadius = 2.0
        
        // Add with fade-in animation
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        
        if let screenWindow = NSApp.keyWindow?.screen?.windows.first {
            screenWindow.contentView?.layer?.addSublayer(guideLayer)
            dockingGuides.append(guideLayer)
        }
        
        CATransaction.commit()
    }
    
    private func hideDockingGuides() {
        dockingGuides.forEach { guide in
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.1)
            guide.opacity = 0.0
            CATransaction.setCompletionBlock {
                guide.removeFromSuperlayer()
            }
            CATransaction.commit()
        }
        dockingGuides.removeAll()
    }
}

struct DockingTarget {
    enum TargetType {
        case screenEdge(DockingEdge)
        case window(NSWindow)
    }
    
    let type: TargetType
    let frame: NSRect
    
    var guideFrame: NSRect {
        // Calculate visual guide position based on target type
        switch type {
        case .screenEdge(let edge):
            return calculateScreenEdgeGuide(edge: edge)
        case .window(let window):
            return calculateWindowEdgeGuide(window: window)
        }
    }
    
    private func calculateScreenEdgeGuide(edge: DockingEdge) -> NSRect {
        // Implementation for screen edge guides
        return frame
    }
    
    private func calculateWindowEdgeGuide(window: NSWindow) -> NSRect {
        // Implementation for window edge guides
        return window.frame
    }
}

// MARK: - Shaded Mode Transitions

class WinampShadedModeManager {
    
    private let collapseDuration: TimeInterval = 0.15
    private let expandDuration: TimeInterval = 0.15
    private var originalWindowFrame: NSRect = .zero
    private var shadedWindowFrame: NSRect = .zero
    
    enum ShadedModeState {
        case normal
        case shaded
        case transitioning
    }
    
    private var currentState: ShadedModeState = .normal
    
    /// Configure shaded mode for a Winamp window
    func setupShadedMode(for window: NSWindow) {
        // Store original frame
        originalWindowFrame = window.frame
        
        // Calculate shaded frame (preserve width, minimal height)
        shadedWindowFrame = NSRect(
            x: originalWindowFrame.origin.x,
            y: originalWindowFrame.origin.y + originalWindowFrame.height - 35,  // Collapse to 35px height
            width: originalWindowFrame.width,
            height: 35
        )
        
        // Setup double-click gesture on title bar
        setupTitleBarGesture(for: window)
        
        // Setup keyboard shortcut
        setupKeyboardShortcut(for: window)
    }
    
    private func setupTitleBarGesture(for window: NSWindow) {
        // Add click tracking to title bar area
        let titleBarTracker = NSTrackingArea(
            rect: NSRect(x: 0, y: window.frame.height - 25, width: window.frame.width, height: 25),
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: ["window": window]
        )
        
        window.contentView?.addTrackingArea(titleBarTracker)
    }
    
    private func setupKeyboardShortcut(for window: NSWindow) {
        // Register Cmd+Shift+W for shade toggle
        let shortcut = NSMenuItem()
        shortcut.keyEquivalent = "w"
        shortcut.keyEquivalentModifierMask = [.command, .shift]
        shortcut.target = self
        shortcut.action = #selector(toggleShadedMode(_:))
        shortcut.representedObject = window
        
        NSApp.mainMenu?.addItem(shortcut)
    }
    
    @objc func toggleShadedMode(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let window = menuItem.representedObject as? NSWindow else { return }
        
        switch currentState {
        case .normal:
            enterShadedMode(window: window)
        case .shaded:
            exitShadedMode(window: window)
        case .transitioning:
            return  // Ignore requests during animation
        }
    }
    
    private func enterShadedMode(window: NSWindow) {
        currentState = .transitioning
        
        // Store current frame
        originalWindowFrame = window.frame
        
        // Animate to shaded size
        NSAnimationContext.runAnimationGroup { context in
            context.duration = collapseDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            // Respect Reduce Motion accessibility setting
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                context.duration = 0.0
            }
            
            window.animator().setFrame(shadedWindowFrame, display: true)
            
        } completionHandler: {
            self.currentState = .shaded
            self.configureShadedInterface(window: window)
        }
    }
    
    private func exitShadedMode(window: NSWindow) {
        currentState = .transitioning
        
        // Restore full interface
        restoreFullInterface(window: window)
        
        // Animate to full size
        NSAnimationContext.runAnimationGroup { context in
            context.duration = expandDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                context.duration = 0.0
            }
            
            window.animator().setFrame(originalWindowFrame, display: true)
            
        } completionHandler: {
            self.currentState = .normal
        }
    }
    
    private func configureShadedInterface(window: NSWindow) {
        // Hide non-essential UI elements
        // Keep only: play/pause, position slider, volume, title
        guard let contentView = window.contentView else { return }
        
        for subview in contentView.subviews {
            if !isEssentialControl(subview) {
                subview.isHidden = true
            } else {
                // Reposition essential controls for compact layout
                repositionForShadedMode(subview)
            }
        }
    }
    
    private func restoreFullInterface(window: NSWindow) {
        // Show all UI elements
        guard let contentView = window.contentView else { return }
        
        for subview in contentView.subviews {
            subview.isHidden = false
            // Restore original positions
            restoreOriginalPosition(subview)
        }
    }
    
    private func isEssentialControl(_ view: NSView) -> Bool {
        // Define which controls remain visible in shaded mode
        let essentialTags = [
            100, // Play/pause button
            101, // Position slider
            102, // Volume control
            103  // Title display
        ]
        
        return essentialTags.contains(view.tag)
    }
    
    private func repositionForShadedMode(_ view: NSView) {
        // Compact layout positioning logic
        switch view.tag {
        case 100: // Play/pause button
            view.frame = NSRect(x: 10, y: 5, width: 25, height: 25)
        case 101: // Position slider
            view.frame = NSRect(x: 45, y: 10, width: 150, height: 15)
        case 102: // Volume control
            view.frame = NSRect(x: 205, y: 10, width: 50, height: 15)
        case 103: // Title display
            view.frame = NSRect(x: 10, y: 17, width: 245, height: 12)
        default:
            break
        }
    }
    
    private func restoreOriginalPosition(_ view: NSView) {
        // Restore to full-size layout positions
        // Implementation would restore original frames stored during setup
    }
}

// MARK: - Playlist Drag & Drop Management

class WinampPlaylistDragDropManager: NSObject {
    
    private weak var playlistView: NSTableView?
    private var dragFeedbackLayer: CALayer?
    
    override init() {
        super.init()
    }
    
    func setupDragDrop(for playlistView: NSTableView) {
        self.playlistView = playlistView
        
        // Register for file drops
        playlistView.registerForDraggedTypes([
            .fileURL,
            .string,
            NSPasteboard.PasteboardType("public.audio")
        ])
        
        playlistView.setDraggingSourceOperationMask(.copy, forLocal: false)
        playlistView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
    }
    
    // MARK: - Drop Validation
    
    func validateDrop(_ info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        
        let pasteboard = info.draggingPasteboard
        
        // Check for audio files
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            let audioURLs = urls.filter { isAudioFile($0) }
            if !audioURLs.isEmpty {
                // Show insertion line at drop location
                showDropIndicator(at: row, operation: dropOperation)
                return .copy
            }
        }
        
        // Check for playlist files
        if let strings = pasteboard.readObjects(forClasses: [NSString.self]) as? [String] {
            if strings.contains(where: { isPlaylistFormat($0) }) {
                return .copy
            }
        }
        
        hideDropIndicator()
        return []
    }
    
    private func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = ["mp3", "flac", "aac", "wav", "m4a", "ogg", "wma"]
        return audioExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func isPlaylistFormat(_ string: String) -> Bool {
        return string.hasPrefix("#EXTM3U") || string.contains(".pls")
    }
    
    // MARK: - Visual Feedback
    
    private func showDropIndicator(at row: Int, operation: NSTableView.DropOperation) {
        guard let playlistView = playlistView else { return }
        
        // Remove existing indicator
        hideDropIndicator()
        
        // Create new drop indicator
        let indicatorLayer = CALayer()
        indicatorLayer.backgroundColor = NSColor.systemBlue.cgColor
        
        let rowRect = playlistView.rect(ofRow: row)
        
        switch operation {
        case .above:
            indicatorLayer.frame = NSRect(
                x: 0,
                y: rowRect.minY - 1,
                width: playlistView.bounds.width,
                height: 2
            )
        case .on:
            indicatorLayer.frame = rowRect
            indicatorLayer.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2).cgColor
        @unknown default:
            break
        }
        
        playlistView.layer?.addSublayer(indicatorLayer)
        dragFeedbackLayer = indicatorLayer
        
        // Animate appearance
        indicatorLayer.opacity = 0.0
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        indicatorLayer.opacity = 1.0
        CATransaction.commit()
    }
    
    private func hideDropIndicator() {
        dragFeedbackLayer?.removeFromSuperlayer()
        dragFeedbackLayer = nil
    }
    
    // MARK: - Drop Handling
    
    func acceptDrop(_ info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        hideDropIndicator()
        
        let pasteboard = info.draggingPasteboard
        
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            return handleAudioFilesDrop(urls, at: row, operation: dropOperation)
        }
        
        if let strings = pasteboard.readObjects(forClasses: [NSString.self]) as? [String] {
            return handlePlaylistDrop(strings, at: row)
        }
        
        return false
    }
    
    private func handleAudioFilesDrop(_ urls: [URL], at row: Int, operation: NSTableView.DropOperation) -> Bool {
        let audioURLs = urls.filter { isAudioFile($0) }
        
        // Expand directories
        let expandedURLs = expandDirectories(audioURLs)
        
        // Create playlist items
        let playlistItems = expandedURLs.compactMap { createPlaylistItem(from: $0) }
        
        // Insert into playlist
        switch operation {
        case .above:
            insertPlaylistItems(playlistItems, at: row)
        case .on:
            replacePlaylistItem(at: row, with: playlistItems)
        @unknown default:
            appendPlaylistItems(playlistItems)
        }
        
        return true
    }
    
    private func expandDirectories(_ urls: [URL]) -> [URL] {
        var expandedURLs: [URL] = []
        
        for url in urls {
            if url.hasDirectoryPath {
                // Recursively scan directory for audio files
                if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
                    for case let fileURL as URL in enumerator {
                        if isAudioFile(fileURL) {
                            expandedURLs.append(fileURL)
                        }
                    }
                }
            } else {
                expandedURLs.append(url)
            }
        }
        
        return expandedURLs.sorted { $0.path < $1.path }
    }
    
    private func createPlaylistItem(from url: URL) -> PlaylistItem? {
        // Extract metadata and create playlist item
        return PlaylistItem(url: url)
    }
    
    private func insertPlaylistItems(_ items: [PlaylistItem], at row: Int) {
        // Implementation to insert items into playlist model
    }
    
    private func replacePlaylistItem(at row: Int, with items: [PlaylistItem]) {
        // Implementation to replace playlist item
    }
    
    private func appendPlaylistItems(_ items: [PlaylistItem]) {
        // Implementation to append items to playlist
    }
}

struct PlaylistItem {
    let url: URL
    let title: String
    let artist: String?
    let duration: TimeInterval?
    
    init(url: URL) {
        self.url = url
        // Extract metadata using AVFoundation
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = nil  // TODO: Extract from metadata
        self.duration = nil  // TODO: Extract from metadata
    }
}

// MARK: - Accessibility Layer Implementation

class WinampAccessibilityManager: NSObject {
    
    private var accessibilityOverlays: [NSView: NSView] = [:]
    
    /// Create accessibility layer for skinned button
    func createAccessibleButton(for skinView: NSView, role: NSAccessibility.Role, label: String, action: Selector?, target: Any?) -> NSView {
        
        let accessibilityButton = NSButton()
        accessibilityButton.title = ""  // No visible title
        accessibilityButton.isBordered = false
        accessibilityButton.isTransparent = true
        accessibilityButton.frame = skinView.bounds
        
        // Configure accessibility
        accessibilityButton.setAccessibilityRole(role)
        accessibilityButton.setAccessibilityLabel(label)
        accessibilityButton.setAccessibilityEnabled(true)
        
        if let action = action, let target = target {
            accessibilityButton.target = target
            accessibilityButton.action = action
        }
        
        // Position over skin element
        skinView.addSubview(accessibilityButton)
        accessibilityOverlays[skinView] = accessibilityButton
        
        return accessibilityButton
    }
    
    /// Configure VoiceOver navigation order
    func configureNavigationOrder(for window: NSWindow) {
        guard let contentView = window.contentView else { return }
        
        let accessibilityElements = collectAccessibilityElements(in: contentView)
        let orderedElements = orderElementsLogically(accessibilityElements)
        
        contentView.setAccessibilityChildren(orderedElements)
    }
    
    private func collectAccessibilityElements(in view: NSView) -> [NSView] {
        var elements: [NSView] = []
        
        for subview in view.subviews {
            if subview.accessibilityRole() != nil {
                elements.append(subview)
            }
            elements.append(contentsOf: collectAccessibilityElements(in: subview))
        }
        
        return elements
    }
    
    private func orderElementsLogically(_ elements: [NSView]) -> [NSView] {
        // Order elements in logical reading order:
        // 1. Playback controls (play, pause, stop, prev, next)
        // 2. Position/time controls
        // 3. Volume controls
        // 4. Secondary controls (EQ, playlist, etc.)
        
        return elements.sorted { (view1, view2) in
            let priority1 = getAccessibilityPriority(view1)
            let priority2 = getAccessibilityPriority(view2)
            
            if priority1 == priority2 {
                // Same priority, sort by position (left to right, top to bottom)
                if view1.frame.minY == view2.frame.minY {
                    return view1.frame.minX < view2.frame.minX
                }
                return view1.frame.minY > view2.frame.minY
            }
            
            return priority1 < priority2
        }
    }
    
    private func getAccessibilityPriority(_ view: NSView) -> Int {
        // Assign priority based on control type
        switch view.tag {
        case 100...104: return 1  // Playback controls
        case 105...109: return 2  // Position/time controls
        case 110...114: return 3  // Volume controls
        case 115...119: return 4  // Secondary controls
        default: return 99
        }
    }
    
    /// Setup custom accessibility actions
    func setupCustomActions(for window: NSWindow) {
        let customActions = [
            NSAccessibilityCustomAction(name: "Toggle Shaded Mode") { _ in
                // Trigger shaded mode toggle
                return true
            },
            NSAccessibilityCustomAction(name: "Next Skin") { _ in
                // Cycle to next skin
                return true
            },
            NSAccessibilityCustomAction(name: "Show Equalizer") { _ in
                // Show equalizer window
                return true
            },
            NSAccessibilityCustomAction(name: "Show Playlist") { _ in
                // Show playlist window
                return true
            }
        ]
        
        window.setAccessibilityCustomActions(customActions)
    }
}

// MARK: - Performance Monitoring

class WinampPerformanceMonitor {
    
    private var frameTimeHistory: [TimeInterval] = []
    private let maxHistoryCount = 60  // Track last 60 frames
    private var lastFrameTime: CFTimeInterval = 0
    
    enum PerformanceLevel {
        case excellent  // >55 fps
        case good      // 45-55 fps
        case acceptable // 30-45 fps
        case poor      // 15-30 fps
        case critical  // <15 fps
    }
    
    func recordFrameTime() {
        let currentTime = CACurrentMediaTime()
        
        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            frameTimeHistory.append(frameTime)
            
            if frameTimeHistory.count > maxHistoryCount {
                frameTimeHistory.removeFirst()
            }
        }
        
        lastFrameTime = currentTime
    }
    
    func getCurrentPerformanceLevel() -> PerformanceLevel {
        guard !frameTimeHistory.isEmpty else { return .excellent }
        
        let averageFrameTime = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        let fps = 1.0 / averageFrameTime
        
        switch fps {
        case 55...:
            return .excellent
        case 45..<55:
            return .good
        case 30..<45:
            return .acceptable
        case 15..<30:
            return .poor
        default:
            return .critical
        }
    }
    
    func recommendOptimizations(for level: PerformanceLevel) -> [PerformanceOptimization] {
        switch level {
        case .excellent, .good:
            return []
        case .acceptable:
            return [.reduceVisualizationQuality, .limitAnimations]
        case .poor:
            return [.disableVisualizations, .disableAnimations, .reduceSkinQuality]
        case .critical:
            return [.disableVisualizations, .disableAnimations, .reduceSkinQuality, .enablePowerSaving]
        }
    }
}

enum PerformanceOptimization {
    case reduceVisualizationQuality
    case limitAnimations
    case disableVisualizations
    case disableAnimations
    case reduceSkinQuality
    case enablePowerSaving
}