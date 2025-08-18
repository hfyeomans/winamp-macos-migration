import Cocoa
import Metal
import CoreGraphics
import IOKit.ps

// MARK: - Adaptive Display Management for Winamp macOS
// Handles Retina scaling, ProMotion displays, multi-monitor setups, and power states

class WinampAdaptiveDisplayManager: NSObject {
    
    // MARK: - Display Detection & Configuration
    
    struct DisplayCapabilities {
        let backingScaleFactor: CGFloat
        let maxRefreshRate: Int
        let supportsProMotion: Bool
        let supportsWideColorGamut: Bool
        let screenSize: CGSize
        let isMainDisplay: Bool
        let displayID: CGDirectDisplayID
    }
    
    struct AdaptiveConfiguration {
        let scalingFactor: CGFloat
        let targetRefreshRate: Int
        let qualityLevel: QualityLevel
        let colorSpace: CGColorSpace?
        let enableHighDPI: Bool
        let enableProMotion: Bool
    }
    
    enum QualityLevel {
        case minimal        // Battery saving, basic functionality
        case reduced        // Reduced quality, better performance  
        case standard       // Default quality
        case enhanced       // High quality for capable hardware
        case maximum        // Ultra quality, all features enabled
        
        var skinAssetScale: CGFloat {
            switch self {
            case .minimal: return 0.5
            case .reduced: return 0.75
            case .standard: return 1.0
            case .enhanced: return 1.5
            case .maximum: return 2.0
            }
        }
        
        var visualizationFPS: Int {
            switch self {
            case .minimal: return 15
            case .reduced: return 30
            case .standard: return 60
            case .enhanced: return 90
            case .maximum: return 120
            }
        }
        
        var enableAnimations: Bool {
            switch self {
            case .minimal, .reduced: return false
            default: return true
            }
        }
    }
    
    // MARK: - Properties
    
    private var displayConfigurations: [CGDirectDisplayID: AdaptiveConfiguration] = [:]
    private var currentPowerState: PowerState = .pluggedIn
    private var performanceMonitor: PerformanceMonitor
    private var powerStateObserver: PowerStateObserver
    
    // MARK: - Initialization
    
    override init() {
        self.performanceMonitor = PerformanceMonitor()
        self.powerStateObserver = PowerStateObserver()
        super.init()
        
        setupDisplayNotifications()
        setupPowerStateMonitoring()
        detectAllDisplays()
    }
    
    // MARK: - Display Detection
    
    private func setupDisplayNotifications() {
        // Monitor display configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func displayConfigurationChanged() {
        // Reconfigure for new display setup
        detectAllDisplays()
        updateAllWindowConfigurations()
    }
    
    private func detectAllDisplays() {
        for screen in NSScreen.screens {
            let capabilities = detectDisplayCapabilities(for: screen)
            let configuration = createOptimalConfiguration(for: capabilities)
            
            if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                displayConfigurations[displayID] = configuration
            }
        }
    }
    
    private func detectDisplayCapabilities(for screen: NSScreen) -> DisplayCapabilities {
        let deviceDescription = screen.deviceDescription
        let displayID = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
        
        // Detect refresh rate capabilities
        let maxRefreshRate = Int(screen.maximumFramesPerSecond)
        let supportsProMotion = maxRefreshRate > 60
        
        // Detect color capabilities
        let supportsWideColorGamut = screen.colorSpace?.name == CGColorSpace.displayP3
        
        return DisplayCapabilities(
            backingScaleFactor: screen.backingScaleFactor,
            maxRefreshRate: maxRefreshRate,
            supportsProMotion: supportsProMotion,
            supportsWideColorGamut: supportsWideColorGamut,
            screenSize: screen.frame.size,
            isMainDisplay: screen == NSScreen.main,
            displayID: displayID
        )
    }
    
    private func createOptimalConfiguration(for capabilities: DisplayCapabilities) -> AdaptiveConfiguration {
        let baseQuality: QualityLevel
        
        // Determine base quality level based on display capabilities
        if capabilities.supportsProMotion && capabilities.backingScaleFactor >= 2.0 {
            baseQuality = .enhanced
        } else if capabilities.backingScaleFactor >= 2.0 {
            baseQuality = .standard
        } else {
            baseQuality = .reduced
        }
        
        // Adjust for power state
        let adjustedQuality = adjustQualityForPowerState(baseQuality)
        
        return AdaptiveConfiguration(
            scalingFactor: capabilities.backingScaleFactor,
            targetRefreshRate: calculateOptimalRefreshRate(capabilities, quality: adjustedQuality),
            qualityLevel: adjustedQuality,
            colorSpace: capabilities.supportsWideColorGamut ? CGColorSpace(name: CGColorSpace.displayP3) : nil,
            enableHighDPI: capabilities.backingScaleFactor > 1.0,
            enableProMotion: capabilities.supportsProMotion && adjustedQuality.visualizationFPS > 60
        )
    }
    
    private func calculateOptimalRefreshRate(_ capabilities: DisplayCapabilities, quality: QualityLevel) -> Int {
        let maxAllowed = quality.visualizationFPS
        return min(capabilities.maxRefreshRate, maxAllowed)
    }
    
    // MARK: - Window Configuration
    
    func configureWindow(_ window: NSWindow, for displayID: CGDirectDisplayID) {
        guard let configuration = displayConfigurations[displayID] else { return }
        
        // Configure Metal view if present
        if let metalView = findMetalView(in: window) {
            configureMetalView(metalView, with: configuration)
        }
        
        // Configure content scaling
        configureContentScaling(window, with: configuration)
        
        // Configure animations
        configureAnimations(window, with: configuration)
        
        // Update skin asset quality
        updateSkinAssetQuality(window, with: configuration)
    }
    
    private func findMetalView(in window: NSWindow) -> MTKView? {
        return window.contentView?.subviews.first { $0 is MTKView } as? MTKView
    }
    
    private func configureMetalView(_ metalView: MTKView, with configuration: AdaptiveConfiguration) {
        // Set appropriate frame rate
        metalView.preferredFramesPerSecond = configuration.targetRefreshRate
        
        // Configure pixel format based on display capabilities
        if configuration.colorSpace != nil {
            metalView.colorPixelFormat = .rgba16Float  // Wide color support
        } else {
            metalView.colorPixelFormat = .bgra8Unorm   // Standard color
        }
        
        // Configure scaling
        metalView.layer?.contentsScale = configuration.scalingFactor
        
        // Configure for power efficiency
        if currentPowerState == .batteryLow || currentPowerState == .batteryCritical {
            metalView.isPaused = true
            metalView.enableSetNeedsDisplay = true
        } else {
            metalView.isPaused = false
        }
    }
    
    private func configureContentScaling(_ window: NSWindow, with configuration: AdaptiveConfiguration) {
        guard let contentView = window.contentView else { return }
        
        // Apply backing scale factor
        contentView.layer?.contentsScale = configuration.scalingFactor
        
        // Update all sublayers
        updateLayerScaling(contentView.layer, scale: configuration.scalingFactor)
    }
    
    private func updateLayerScaling(_ layer: CALayer?, scale: CGFloat) {
        guard let layer = layer else { return }
        
        layer.contentsScale = scale
        
        // Update all sublayers recursively
        layer.sublayers?.forEach { sublayer in
            updateLayerScaling(sublayer, scale: scale)
        }
    }
    
    private func configureAnimations(_ window: NSWindow, with configuration: AdaptiveConfiguration) {
        let enableAnimations = configuration.qualityLevel.enableAnimations
        
        // Configure Core Animation settings
        CATransaction.begin()
        CATransaction.setDisableActions(!enableAnimations)
        
        if enableAnimations {
            // Enable smooth animations for high-quality displays
            window.animationBehavior = .documentWindow
        } else {
            // Disable animations for power saving
            window.animationBehavior = .none
        }
        
        CATransaction.commit()
    }
    
    private func updateSkinAssetQuality(_ window: NSWindow, with configuration: AdaptiveConfiguration) {
        let assetScale = configuration.qualityLevel.skinAssetScale
        
        // Notify skin loader of quality change
        NotificationCenter.default.post(
            name: NSNotification.Name("WinampSkinQualityChanged"),
            object: window,
            userInfo: [
                "assetScale": assetScale,
                "displayID": configuration
            ]
        )
    }
    
    // MARK: - Multi-Monitor Support
    
    func getOptimalWindowPlacement(for windowType: WindowType) -> WindowPlacement {
        let screens = NSScreen.screens
        
        switch windowType {
        case .mainPlayer:
            // Always place main player on primary display
            return WindowPlacement(
                screen: NSScreen.main ?? screens.first!,
                position: .center,
                priority: .high
            )
            
        case .playlist:
            // Prefer secondary display if available
            let targetScreen = screens.count > 1 ? screens[1] : NSScreen.main!
            return WindowPlacement(
                screen: targetScreen,
                position: .rightSide,
                priority: .medium
            )
            
        case .equalizer:
            // Keep with main player for audio control consistency
            return WindowPlacement(
                screen: NSScreen.main ?? screens.first!,
                position: .nearMainPlayer,
                priority: .medium
            )
            
        case .visualizer:
            // Use largest/highest quality display for visualizations
            let bestScreen = findBestVisualizationDisplay(screens)
            return WindowPlacement(
                screen: bestScreen,
                position: .fullscreen,
                priority: .low
            )
        }
    }
    
    private func findBestVisualizationDisplay(_ screens: [NSScreen]) -> NSScreen {
        return screens.max { screen1, screen2 in
            let area1 = screen1.frame.width * screen1.frame.height
            let area2 = screen2.frame.width * screen2.frame.height
            
            // Prefer larger screens
            if area1 != area2 {
                return area1 < area2
            }
            
            // Prefer higher refresh rate
            return screen1.maximumFramesPerSecond < screen2.maximumFramesPerSecond
        } ?? screens.first!
    }
    
    // MARK: - Power State Management
    
    enum PowerState {
        case pluggedIn
        case batteryFull        // >80%
        case batteryMedium      // 40-80%
        case batteryLow         // 20-40%
        case batteryCritical    // <20%
        case powerSaverMode     // System power saver enabled
    }
    
    private func setupPowerStateMonitoring() {
        powerStateObserver.onPowerStateChanged = { [weak self] newState in
            self?.handlePowerStateChange(newState)
        }
        powerStateObserver.startMonitoring()
    }
    
    private func handlePowerStateChange(_ newState: PowerState) {
        currentPowerState = newState
        
        // Reconfigure all displays for new power state
        detectAllDisplays()
        updateAllWindowConfigurations()
        
        // Notify components of power state change
        NotificationCenter.default.post(
            name: NSNotification.Name("WinampPowerStateChanged"),
            object: nil,
            userInfo: ["powerState": newState]
        )
    }
    
    private func adjustQualityForPowerState(_ baseQuality: QualityLevel) -> QualityLevel {
        switch currentPowerState {
        case .pluggedIn, .batteryFull:
            return baseQuality
            
        case .batteryMedium:
            // Slight reduction in quality
            switch baseQuality {
            case .maximum: return .enhanced
            case .enhanced: return .standard
            default: return baseQuality
            }
            
        case .batteryLow:
            // Significant quality reduction
            switch baseQuality {
            case .maximum, .enhanced: return .standard
            case .standard: return .reduced
            default: return baseQuality
            }
            
        case .batteryCritical, .powerSaverMode:
            // Minimal quality for maximum battery life
            return .minimal
        }
    }
    
    // MARK: - Performance Adaptation
    
    private func updateAllWindowConfigurations() {
        for window in NSApp.windows {
            if let screen = window.screen,
               let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                configureWindow(window, for: displayID)
            }
        }
    }
    
    func adaptToPerformance(_ metrics: PerformanceMetrics) {
        if metrics.averageFPS < 30 {
            // Performance is poor, reduce quality
            reduceQualityLevel()
        } else if metrics.averageFPS > 55 && metrics.memoryUsage < 0.7 {
            // Performance is good, can increase quality
            increaseQualityLevel()
        }
    }
    
    private func reduceQualityLevel() {
        for (displayID, var configuration) in displayConfigurations {
            let newQuality: QualityLevel
            
            switch configuration.qualityLevel {
            case .maximum: newQuality = .enhanced
            case .enhanced: newQuality = .standard
            case .standard: newQuality = .reduced
            case .reduced: newQuality = .minimal
            case .minimal: continue  // Already at minimum
            }
            
            configuration.qualityLevel = newQuality
            configuration.targetRefreshRate = newQuality.visualizationFPS
            displayConfigurations[displayID] = configuration
        }
        
        updateAllWindowConfigurations()
    }
    
    private func increaseQualityLevel() {
        // Only increase if not in power saving mode
        guard currentPowerState == .pluggedIn || currentPowerState == .batteryFull else { return }
        
        for (displayID, var configuration) in displayConfigurations {
            let newQuality: QualityLevel
            
            switch configuration.qualityLevel {
            case .minimal: newQuality = .reduced
            case .reduced: newQuality = .standard
            case .standard: newQuality = .enhanced
            case .enhanced: newQuality = .maximum
            case .maximum: continue  // Already at maximum
            }
            
            configuration.qualityLevel = newQuality
            configuration.targetRefreshRate = min(
                newQuality.visualizationFPS,
                NSScreen.main?.maximumFramesPerSecond ?? 60
            )
            displayConfigurations[displayID] = configuration
        }
        
        updateAllWindowConfigurations()
    }
}

// MARK: - Supporting Types

enum WindowType {
    case mainPlayer
    case playlist
    case equalizer
    case visualizer
}

struct WindowPlacement {
    let screen: NSScreen
    let position: Position
    let priority: Priority
    
    enum Position {
        case center
        case rightSide
        case nearMainPlayer
        case fullscreen
    }
    
    enum Priority {
        case high, medium, low
    }
}

struct PerformanceMetrics {
    let averageFPS: Double
    let memoryUsage: Double  // 0.0 - 1.0
    let cpuUsage: Double     // 0.0 - 1.0
    let gpuUsage: Double     // 0.0 - 1.0
}

// MARK: - Performance Monitor

class PerformanceMonitor {
    private var fpsHistory: [Double] = []
    private let maxHistoryCount = 60
    
    func recordFrame() {
        let currentTime = CACurrentMediaTime()
        static var lastTime: CFTimeInterval = 0
        
        if lastTime > 0 {
            let frameTime = currentTime - lastTime
            let fps = 1.0 / frameTime
            
            fpsHistory.append(fps)
            if fpsHistory.count > maxHistoryCount {
                fpsHistory.removeFirst()
            }
        }
        
        lastTime = currentTime
    }
    
    func getCurrentMetrics() -> PerformanceMetrics {
        let averageFPS = fpsHistory.isEmpty ? 60.0 : fpsHistory.reduce(0, +) / Double(fpsHistory.count)
        
        return PerformanceMetrics(
            averageFPS: averageFPS,
            memoryUsage: getCurrentMemoryUsage(),
            cpuUsage: getCurrentCPUUsage(),
            gpuUsage: getCurrentGPUUsage()
        )
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            return usedMemory / totalMemory
        }
        
        return 0.0
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage calculation
        return 0.0  // TODO: Implement actual CPU monitoring
    }
    
    private func getCurrentGPUUsage() -> Double {
        // Simplified GPU usage calculation
        return 0.0  // TODO: Implement actual GPU monitoring
    }
}

// MARK: - Power State Observer

class PowerStateObserver {
    var onPowerStateChanged: ((WinampAdaptiveDisplayManager.PowerState) -> Void)?
    private var powerSourceRunLoopSource: CFRunLoopSource?
    
    func startMonitoring() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        powerSourceRunLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let observer = Unmanaged<PowerStateObserver>.fromOpaque(context).takeUnretainedValue()
            observer.powerSourceChanged()
        }, context).takeRetainedValue()
        
        if let source = powerSourceRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
        
        // Initial state check
        powerSourceChanged()
    }
    
    private func powerSourceChanged() {
        let currentState = detectCurrentPowerState()
        onPowerStateChanged?(currentState)
    }
    
    private func detectCurrentPowerState() -> WinampAdaptiveDisplayManager.PowerState {
        let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let powerSources = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeRetainedValue() as? [CFTypeRef]
        
        var isPluggedIn = false
        var batteryLevel: Int = 100
        
        if let sources = powerSources {
            for source in sources {
                if let info = IOPSGetPowerSourceDescription(powerSourceInfo, source)?.takeUnretainedValue() as? [String: Any] {
                    
                    if let powerSourceState = info[kIOPSPowerSourceStateKey] as? String {
                        isPluggedIn = powerSourceState == kIOPSACPowerValue
                    }
                    
                    if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
                        batteryLevel = capacity
                    }
                }
            }
        }
        
        // Check for Low Power Mode
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return .powerSaverMode
        }
        
        if isPluggedIn {
            return .pluggedIn
        }
        
        switch batteryLevel {
        case 80...100:
            return .batteryFull
        case 40..<80:
            return .batteryMedium
        case 20..<40:
            return .batteryLow
        default:
            return .batteryCritical
        }
    }
    
    deinit {
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }
}