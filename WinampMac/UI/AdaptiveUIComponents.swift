//
//  AdaptiveUIComponents.swift
//  WinampMac
//
//  Adaptive UI components that respond to themes, system settings, and accessibility needs
//  Optimized for macOS 15+ with ProMotion, Dark Mode, and High Contrast support
//

import Foundation
import AppKit
import Metal
import QuartzCore
import Accessibility

// MARK: - Adaptive Component Protocol

protocol AdaptiveUIComponent: AnyObject {
    func adaptToTheme(_ theme: WinampThemeEngine.Theme)
    func adaptToSystemAppearance(_ appearance: NSAppearance)
    func adaptToAccessibilitySettings()
    func adaptToDisplayScale(_ scale: CGFloat)
    func invalidateVisualState()
}

// MARK: - Adaptive Main Window

@available(macOS 15.0, *)
public final class AdaptiveMainWindow: NSWindow, AdaptiveUIComponent {
    
    // MARK: - Properties
    private var currentTheme: WinampThemeEngine.Theme?
    private var visualSpecifications = WinampVisualSpecifications.self
    private var isInShadeMode = false
    private var adaptiveContentView: AdaptiveContentView?
    private var windowEffects: WindowEffects?
    
    // Animation properties
    private var shadeAnimation: NSAnimation?
    private var glowLayer: CALayer?
    
    // MARK: - Initialization
    
    public override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, 
                        backing backingType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, 
                  styleMask: [.borderless, .miniaturizable, .closable, .resizable], 
                  backing: backingType, 
                  defer: flag)
        
        setupAdaptiveWindow()
        registerForNotifications()
    }
    
    private func setupAdaptiveWindow() {
        // Configure window properties
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .normal
        isMovableByWindowBackground = true
        
        // Enable layer backing for effects
        contentView?.wantsLayer = true
        contentView?.layer?.masksToBounds = false
        
        // Setup adaptive content view
        let contentFrame = contentRect(forFrameRect: frame)
        adaptiveContentView = AdaptiveContentView(frame: contentFrame)
        contentView = adaptiveContentView
        
        // Setup window effects
        windowEffects = WindowEffects(window: self)
        
        // Initial adaptation
        adaptToSystemAppearance(effectiveAppearance)
        adaptToAccessibilitySettings()
        adaptToDisplayScale(backingScaleFactor)
    }
    
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange(_:)),
            name: .themeDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: NSNotification.Name.NSApplicationDidChangeAccessibilityPreferences,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayScaleChanged),
            name: NSWindow.didChangeBackingPropertiesNotification,
            object: self
        )
    }
    
    // MARK: - Adaptive Implementation
    
    public func adaptToTheme(_ theme: WinampThemeEngine.Theme) {
        currentTheme = theme
        
        // Apply theme colors and assets
        if let mainAsset = theme.assets.mainWindow {
            adaptiveContentView?.setBackgroundImage(mainAsset)
            
            // Resize window to match theme
            let newSize = mainAsset.size
            let newFrame = NSRect(origin: frame.origin, size: newSize)
            setFrame(newFrame, display: true, animate: true)
        }
        
        // Apply color scheme
        windowEffects?.updateColors(theme.colorScheme)
        adaptiveContentView?.adaptToTheme(theme)
        
        invalidateVisualState()
    }
    
    public func adaptToSystemAppearance(_ appearance: NSAppearance) {
        guard let contentView = adaptiveContentView else { return }
        
        // Adapt to dark/light mode
        contentView.appearance = appearance
        
        // Adjust window effects for appearance
        if appearance.name == .darkAqua {
            windowEffects?.enableDarkModeEffects()
        } else {
            windowEffects?.enableLightModeEffects()
        }
        
        // Update shadow and glow effects
        updateShadowEffects(for: appearance)
    }
    
    public func adaptToAccessibilitySettings() {
        let highContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        
        adaptiveContentView?.setHighContrastMode(highContrast)
        adaptiveContentView?.setReduceMotionMode(reduceMotion)
        
        if reduceTransparency {
            windowEffects?.disableTransparencyEffects()
        } else {
            windowEffects?.enableTransparencyEffects()
        }
        
        // Adjust focus indicators
        if highContrast {
            setupHighContrastFocusIndicators()
        }
    }
    
    public func adaptToDisplayScale(_ scale: CGFloat) {
        adaptiveContentView?.updateForDisplayScale(scale)
        windowEffects?.updateForDisplayScale(scale)
        
        // Adjust rendering quality based on scale
        if scale >= 3.0 {
            // Super Retina display - use highest quality
            enableSuperRetinaOptimizations()
        } else if scale >= 2.0 {
            // Retina display - use high quality
            enableRetinaOptimizations()
        } else {
            // Standard display
            enableStandardOptimizations()
        }
    }
    
    public func invalidateVisualState() {
        adaptiveContentView?.needsDisplay = true
        windowEffects?.invalidateEffects()
    }
    
    // MARK: - Window Shade Animation
    
    public func toggleShadeMode(animated: Bool = true) {
        let targetHeight: CGFloat = isInShadeMode ? 
            visualSpecifications.MainPlayerWindow.baseSize.height :
            visualSpecifications.MainPlayerWindow.Titlebar.height
        
        if animated {
            animateToShadeMode(!isInShadeMode, targetHeight: targetHeight)
        } else {
            setShadeMode(!isInShadeMode, height: targetHeight)
        }
    }
    
    private func animateToShadeMode(_ shaded: Bool, targetHeight: CGFloat) {
        // Cancel existing animation
        shadeAnimation?.stop()
        
        let startFrame = frame
        let targetFrame = NSRect(x: startFrame.origin.x, 
                                y: startFrame.origin.y + (startFrame.height - targetHeight),
                                width: startFrame.width, 
                                height: targetHeight)
        
        // Create custom animation
        shadeAnimation = WindowShadeAnimation(
            window: self,
            startFrame: startFrame,
            endFrame: targetFrame,
            duration: visualSpecifications.AnimationSystem.WindowShade.duration
        )
        
        shadeAnimation?.animationDidEnd = { [weak self] in
            self?.isInShadeMode = shaded
            self?.adaptiveContentView?.setShadeMode(shaded)
        }
        
        shadeAnimation?.start()
    }
    
    private func setShadeMode(_ shaded: Bool, height: CGFloat) {
        let newFrame = NSRect(x: frame.origin.x,
                             y: frame.origin.y + (frame.height - height),
                             width: frame.width,
                             height: height)
        setFrame(newFrame, display: true)
        isInShadeMode = shaded
        adaptiveContentView?.setShadeMode(shaded)
    }
    
    // MARK: - Visual Effects
    
    private func updateShadowEffects(for appearance: NSAppearance) {
        let specs = visualSpecifications.MainPlayerWindow.self
        
        shadow = NSShadow()
        shadow?.shadowOffset = specs.shadowOffset
        shadow?.shadowBlurRadius = specs.shadowRadius
        
        if appearance.name == .darkAqua {
            shadow?.shadowColor = NSColor.black.withAlphaComponent(0.5)
        } else {
            shadow?.shadowColor = NSColor.black.withAlphaComponent(CGFloat(specs.shadowOpacity))
        }
        
        invalidateShadow()
    }
    
    private func setupHighContrastFocusIndicators() {
        let focusSpec = visualSpecifications.AccessibilitySpecs.HighContrast.self
        
        // Create focus ring layer if needed
        if glowLayer == nil {
            glowLayer = CALayer()
            glowLayer?.borderWidth = focusSpec.focusRingWidth
            glowLayer?.borderColor = focusSpec.focusRingColor.cgColor
            glowLayer?.cornerRadius = visualSpecifications.MainPlayerWindow.cornerRadius
            contentView?.layer?.addSublayer(glowLayer!)
        }
    }
    
    private func enableSuperRetinaOptimizations() {
        // Enable highest quality rendering for 3x displays
        adaptiveContentView?.enableSuperRetinaMode()
        windowEffects?.setSuperRetinaQuality()
    }
    
    private func enableRetinaOptimizations() {
        // Enable high quality rendering for 2x displays
        adaptiveContentView?.enableRetinaMode()
        windowEffects?.setRetinaQuality()
    }
    
    private func enableStandardOptimizations() {
        // Optimize for standard displays
        adaptiveContentView?.enableStandardMode()
        windowEffects?.setStandardQuality()
    }
    
    // MARK: - Notification Handlers
    
    @objc private func themeDidChange(_ notification: Notification) {
        guard let theme = notification.object as? WinampThemeEngine.Theme else { return }
        adaptToTheme(theme)
    }
    
    @objc private func accessibilitySettingsChanged() {
        adaptToAccessibilitySettings()
    }
    
    @objc private func displayScaleChanged() {
        adaptToDisplayScale(backingScaleFactor)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        shadeAnimation?.stop()
    }
}

// MARK: - Adaptive Content View

private final class AdaptiveContentView: NSView, AdaptiveUIComponent {
    
    private var backgroundImage: NSImage?
    private var controlComponents: [AdaptiveUIComponent] = []
    private var displayQuality: DisplayQuality = .standard
    private var isHighContrastMode = false
    private var isReduceMotionMode = false
    private var isShadeMode = false
    
    private enum DisplayQuality {
        case standard
        case retina
        case superRetina
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAdaptiveView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAdaptiveView() {
        wantsLayer = true
        layer?.masksToBounds = false
        
        // Setup control components
        setupControlComponents()
    }
    
    private func setupControlComponents() {
        // Create adaptive UI components
        let visualizationView = AdaptiveVisualizationView(frame: WinampVisualSpecifications.MainPlayerWindow.VisualizationWindow.frame)
        let displayArea = AdaptiveDisplayArea(frame: WinampVisualSpecifications.MainPlayerWindow.DisplayArea.frame)
        let controlPanel = AdaptiveControlPanel()
        
        // Add to subviews and track for adaptation
        addSubview(visualizationView)
        addSubview(displayArea)
        addSubview(controlPanel)
        
        controlComponents = [visualizationView, displayArea, controlPanel]
    }
    
    func setBackgroundImage(_ image: NSImage) {
        backgroundImage = image
        needsDisplay = true
    }
    
    func setShadeMode(_ shaded: Bool) {
        isShadeMode = shaded
        
        // Hide/show components based on shade mode
        for component in controlComponents {
            if let view = component as? NSView {
                view.isHidden = shaded
            }
        }
        
        needsDisplay = true
    }
    
    func setHighContrastMode(_ enabled: Bool) {
        isHighContrastMode = enabled
        
        // Apply high contrast adaptations
        for component in controlComponents {
            component.adaptToAccessibilitySettings()
        }
        
        needsDisplay = true
    }
    
    func setReduceMotionMode(_ enabled: Bool) {
        isReduceMotionMode = enabled
        
        // Disable animations if reduce motion is enabled
        if enabled {
            layer?.removeAllAnimations()
        }
        
        for component in controlComponents {
            component.adaptToAccessibilitySettings()
        }
    }
    
    func updateForDisplayScale(_ scale: CGFloat) {
        if scale >= 3.0 {
            displayQuality = .superRetina
        } else if scale >= 2.0 {
            displayQuality = .retina
        } else {
            displayQuality = .standard
        }
        
        for component in controlComponents {
            component.adaptToDisplayScale(scale)
        }
        
        needsDisplay = true
    }
    
    func enableSuperRetinaMode() {
        displayQuality = .superRetina
        layer?.contentsScale = 3.0
    }
    
    func enableRetinaMode() {
        displayQuality = .retina
        layer?.contentsScale = 2.0
    }
    
    func enableStandardMode() {
        displayQuality = .standard
        layer?.contentsScale = 1.0
    }
    
    // MARK: - AdaptiveUIComponent Implementation
    
    func adaptToTheme(_ theme: WinampThemeEngine.Theme) {
        setBackgroundImage(theme.assets.mainWindow)
        
        for component in controlComponents {
            component.adaptToTheme(theme)
        }
    }
    
    func adaptToSystemAppearance(_ appearance: NSAppearance) {
        self.appearance = appearance
        
        for component in controlComponents {
            component.adaptToSystemAppearance(appearance)
        }
    }
    
    func adaptToAccessibilitySettings() {
        for component in controlComponents {
            component.adaptToAccessibilitySettings()
        }
    }
    
    func adaptToDisplayScale(_ scale: CGFloat) {
        updateForDisplayScale(scale)
    }
    
    func invalidateVisualState() {
        needsDisplay = true
        
        for component in controlComponents {
            component.invalidateVisualState()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw background image with appropriate quality
        if let bgImage = backgroundImage {
            let imageRect = bounds
            
            // Use appropriate interpolation based on display quality
            switch displayQuality {
            case .standard:
                context.interpolationQuality = .none  // Pixel perfect for standard displays
            case .retina, .superRetina:
                context.interpolationQuality = .high  // Smooth scaling for high-DPI
            }
            
            bgImage.draw(in: imageRect, from: .zero, operation: .copy, fraction: 1.0)
        }
        
        // Apply high contrast modifications if needed
        if isHighContrastMode {
            drawHighContrastOverlay(in: dirtyRect, context: context)
        }
    }
    
    private func drawHighContrastOverlay(in rect: NSRect, context: CGContext) {
        // Add high contrast border
        let borderSpec = WinampVisualSpecifications.AccessibilitySpecs.HighContrast.self
        
        context.setStrokeColor(borderSpec.focusRingColor.cgColor)
        context.setLineWidth(borderSpec.borderWidthIncrease)
        context.stroke(bounds.insetBy(dx: 1, dy: 1))
    }
}

// MARK: - Window Effects Manager

private final class WindowEffects {
    private weak var window: NSWindow?
    private var blurEffect: NSVisualEffectView?
    private var currentColorScheme: WinampThemeEngine.ColorScheme?
    
    init(window: NSWindow) {
        self.window = window
        setupEffects()
    }
    
    private func setupEffects() {
        // Setup blur effect for glassmorphism
        blurEffect = NSVisualEffectView()
        blurEffect?.blendingMode = .behindWindow
        blurEffect?.material = .hudWindow
        blurEffect?.state = .active
        
        if let contentView = window?.contentView {
            blurEffect?.frame = contentView.bounds
            blurEffect?.autoresizingMask = [.width, .height]
            contentView.addSubview(blurEffect!, positioned: .below, relativeTo: nil)
        }
    }
    
    func updateColors(_ colorScheme: WinampThemeEngine.ColorScheme) {
        currentColorScheme = colorScheme
        
        // Update blur effect tint
        blurEffect?.appearance = NSAppearance(named: .vibrantDark)
    }
    
    func enableDarkModeEffects() {
        blurEffect?.appearance = NSAppearance(named: .vibrantDark)
        blurEffect?.material = .hudWindow
    }
    
    func enableLightModeEffects() {
        blurEffect?.appearance = NSAppearance(named: .vibrantLight)
        blurEffect?.material = .popover
    }
    
    func enableTransparencyEffects() {
        blurEffect?.isHidden = false
    }
    
    func disableTransparencyEffects() {
        blurEffect?.isHidden = true
    }
    
    func updateForDisplayScale(_ scale: CGFloat) {
        // Adjust effect quality based on display scale
        if scale >= 2.0 {
            blurEffect?.layer?.shouldRasterize = false
        } else {
            blurEffect?.layer?.shouldRasterize = true
            blurEffect?.layer?.rasterizationScale = scale
        }
    }
    
    func setSuperRetinaQuality() {
        blurEffect?.layer?.shouldRasterize = false
    }
    
    func setRetinaQuality() {
        blurEffect?.layer?.shouldRasterize = false
    }
    
    func setStandardQuality() {
        blurEffect?.layer?.shouldRasterize = true
        blurEffect?.layer?.rasterizationScale = 1.0
    }
    
    func invalidateEffects() {
        blurEffect?.needsDisplay = true
    }
}

// MARK: - Window Shade Animation

private final class WindowShadeAnimation: NSAnimation {
    private weak var window: NSWindow?
    private let startFrame: NSRect
    private let endFrame: NSRect
    
    var animationDidEnd: (() -> Void)?
    
    init(window: NSWindow, startFrame: NSRect, endFrame: NSRect, duration: TimeInterval) {
        self.window = window
        self.startFrame = startFrame
        self.endFrame = endFrame
        
        super.init(duration: duration, animationCurve: .easeInOut)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var currentProgress: NSAnimation.Progress {
        didSet {
            updateWindowFrame()
        }
    }
    
    private func updateWindowFrame() {
        guard let window = window else { return }
        
        let progress = CGFloat(currentProgress)
        let currentFrame = NSRect(
            x: startFrame.origin.x + (endFrame.origin.x - startFrame.origin.x) * progress,
            y: startFrame.origin.y + (endFrame.origin.y - startFrame.origin.y) * progress,
            width: startFrame.width + (endFrame.width - startFrame.width) * progress,
            height: startFrame.height + (endFrame.height - startFrame.height) * progress
        )
        
        window.setFrame(currentFrame, display: true)
    }
    
    override func animationDidEnd() {
        super.animationDidEnd()
        animationDidEnd?()
    }
}

// MARK: - Default Implementations for Testing

private final class AdaptiveVisualizationView: NSView, AdaptiveUIComponent {
    func adaptToTheme(_ theme: WinampThemeEngine.Theme) {}
    func adaptToSystemAppearance(_ appearance: NSAppearance) {}
    func adaptToAccessibilitySettings() {}
    func adaptToDisplayScale(_ scale: CGFloat) {}
    func invalidateVisualState() { needsDisplay = true }
}

private final class AdaptiveDisplayArea: NSView, AdaptiveUIComponent {
    func adaptToTheme(_ theme: WinampThemeEngine.Theme) {}
    func adaptToSystemAppearance(_ appearance: NSAppearance) {}
    func adaptToAccessibilitySettings() {}
    func adaptToDisplayScale(_ scale: CGFloat) {}
    func invalidateVisualState() { needsDisplay = true }
}

private final class AdaptiveControlPanel: NSView, AdaptiveUIComponent {
    func adaptToTheme(_ theme: WinampThemeEngine.Theme) {}
    func adaptToSystemAppearance(_ appearance: NSAppearance) {}
    func adaptToAccessibilitySettings() {}
    func adaptToDisplayScale(_ scale: CGFloat) {}
    func invalidateVisualState() { needsDisplay = true }
}