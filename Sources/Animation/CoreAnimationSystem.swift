import Foundation
import CoreAnimation
import Metal
import MetalKit
import QuartzCore
import simd

/// Modern Core Animation system for skin animations with Metal integration
/// Optimized for macOS 15.0+ and ProMotion displays up to 120Hz
class CoreAnimationSystem {
    
    // MARK: - Properties
    private var animationLayers: [String: CALayer] = [:]
    private var metalAnimations: [String: MetalAnimation] = [:]
    private var displayLink: CVDisplayLink?
    private var isProMotionDisplay = false
    private var targetFrameRate: Float = 60.0
    
    // Animation timing
    private var lastFrameTime: CFTimeInterval = 0
    private var deltaTime: CFTimeInterval = 0
    private let maxDeltaTime: CFTimeInterval = 1.0 / 30.0 // Cap at 30fps minimum
    
    // Performance monitoring
    private var frameCount: Int = 0
    private var performanceMetrics = AnimationPerformanceMetrics()
    
    // Animation groups for batch operations
    private var animationGroups: [String: CAAnimationGroup] = [:]
    private var activeTimelines: [String: AnimationTimeline] = [:]
    
    init() {
        setupDisplayLink()
        detectDisplayCapabilities()
        configureAnimationSettings()
    }
    
    private func setupDisplayLink() {
        let displayID = CGMainDisplayID()
        CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink)
        
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, Unmanaged.passUnretained(self).toOpaque())
        }
    }
    
    private func detectDisplayCapabilities() {
        if let screen = NSScreen.main {
            let refreshRate = screen.maximumFramesPerSecond
            isProMotionDisplay = refreshRate > 60
            targetFrameRate = Float(min(refreshRate, 120)) // Cap at 120Hz
            
            print("Animation system initialized - Refresh rate: \(refreshRate)Hz, ProMotion: \(isProMotionDisplay)")
        }
    }
    
    private func configureAnimationSettings() {
        // Optimize Core Animation for high refresh rates
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        // Configure layer rendering optimization
        CALayer.setNeedsDisplayOnBoundsChange(true)
    }
    
    // MARK: - Display Link Callback
    
    private let displayLinkCallback: CVDisplayLinkOutputCallback = { (displayLink, now, outputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
        guard let context = displayLinkContext else { return kCVReturnError }
        
        let animationSystem = Unmanaged<CoreAnimationSystem>.fromOpaque(context).takeUnretainedValue()
        
        DispatchQueue.main.async {
            animationSystem.updateAnimations(now)
        }
        
        return kCVReturnSuccess
    }
    
    private func updateAnimations(_ time: UnsafePointer<CVTimeStamp>) {
        let currentTime = CACurrentMediaTime()
        deltaTime = min(currentTime - lastFrameTime, maxDeltaTime)
        lastFrameTime = currentTime
        
        // Update Metal-based animations
        updateMetalAnimations(deltaTime: Float(deltaTime))
        
        // Update timeline-based animations
        updateTimelineAnimations(currentTime: currentTime)
        
        // Performance monitoring
        frameCount += 1
        if frameCount % 60 == 0 {
            updatePerformanceMetrics()
        }
    }
    
    // MARK: - Button Animations
    
    /// Create modern button press animation with haptic-like feedback
    func createButtonPressAnimation(for layer: CALayer, identifier: String) {
        let scaleAnimation = CASpringAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 0.95
        scaleAnimation.autoreverses = true
        scaleAnimation.duration = 0.1
        scaleAnimation.damping = 15.0
        scaleAnimation.stiffness = 300.0
        scaleAnimation.mass = 1.0
        
        let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        shadowAnimation.fromValue = 0.3
        shadowAnimation.toValue = 0.1
        shadowAnimation.autoreverses = true
        shadowAnimation.duration = 0.1
        
        let colorAnimation = CABasicAnimation(keyPath: "backgroundColor")
        colorAnimation.fromValue = NSColor.controlColor.cgColor
        colorAnimation.toValue = NSColor.controlAccentColor.cgColor
        colorAnimation.autoreverses = true
        colorAnimation.duration = 0.05
        
        let group = CAAnimationGroup()
        group.animations = [scaleAnimation, shadowAnimation, colorAnimation]
        group.duration = 0.2
        group.fillMode = .forwards
        group.isRemovedOnCompletion = true
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        layer.add(group, forKey: "buttonPress_\(identifier)")
        animationGroups["buttonPress_\(identifier)"] = group
    }
    
    /// Create smooth hover animation for interactive elements
    func createHoverAnimation(for layer: CALayer, identifier: String, isEntering: Bool) {
        let scaleAnimation = CASpringAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = isEntering ? 1.0 : 1.05
        scaleAnimation.toValue = isEntering ? 1.05 : 1.0
        scaleAnimation.duration = 0.2
        scaleAnimation.damping = 20.0
        scaleAnimation.stiffness = 200.0
        
        let glowAnimation = CABasicAnimation(keyPath: "shadowRadius")
        glowAnimation.fromValue = isEntering ? 2.0 : 6.0
        glowAnimation.toValue = isEntering ? 6.0 : 2.0
        glowAnimation.duration = 0.2
        
        let group = CAAnimationGroup()
        group.animations = [scaleAnimation, glowAnimation]
        group.duration = 0.2
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        
        layer.add(group, forKey: "hover_\(identifier)")
    }
    
    // MARK: - Slider Animations
    
    /// Create physics-based slider animation with momentum
    func createSliderAnimation(for layer: CALayer, from startValue: Float, to endValue: Float, velocity: Float = 0, identifier: String) {
        let timeline = AnimationTimeline()
        timeline.identifier = identifier
        timeline.duration = 0.3
        timeline.startTime = CACurrentMediaTime()
        
        // Calculate spring physics
        let displacement = endValue - startValue
        let springConstant: Float = 300.0
        let damping: Float = 25.0
        
        timeline.updateBlock = { [weak layer] progress in
            guard let layer = layer else { return }
            
            let t = Float(progress)
            let dampedProgress = self.springEasing(t: t, k: springConstant, d: damping)
            let currentValue = startValue + displacement * dampedProgress
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.position.x = CGFloat(currentValue)
            CATransaction.commit()
        }
        
        timeline.completionBlock = {
            print("Slider animation completed for \(identifier)")
        }
        
        activeTimelines[identifier] = timeline
    }
    
    private func springEasing(t: Float, k: Float, d: Float) -> Float {
        // Spring physics calculation
        let w = sqrt(k)
        let zeta = d / (2.0 * sqrt(k))
        
        if zeta < 1.0 {
            // Underdamped
            let wd = w * sqrt(1.0 - zeta * zeta)
            return 1.0 - exp(-zeta * w * t) * cos(wd * t)
        } else {
            // Critically damped or overdamped
            return 1.0 - exp(-w * t) * (1.0 + w * t)
        }
    }
    
    // MARK: - Visualization Animations
    
    /// Create Metal-based spectrum analyzer animation
    func createSpectrumAnimation(with audioData: [Float], metalView: MTKView, identifier: String) {
        let metalAnimation = MetalAnimation()
        metalAnimation.identifier = identifier
        metalAnimation.type = .spectrum
        metalAnimation.audioData = audioData
        metalAnimation.lastUpdateTime = CACurrentMediaTime()
        
        // Configure spectrum-specific parameters
        metalAnimation.parameters = [
            "barCount": 20,
            "smoothing": 0.8,
            "decay": 0.05,
            "peakHold": 1.0,
            "colorLow": simd_float3(0, 1, 0),    // Green
            "colorMid": simd_float3(1, 1, 0),    // Yellow  
            "colorHigh": simd_float3(1, 0, 0)    // Red
        ]
        
        metalAnimations[identifier] = metalAnimation
        
        // Trigger Metal view update
        metalView.needsDisplay = true
    }
    
    /// Create oscilloscope waveform animation
    func createOscilloscopeAnimation(with waveformData: [Float], metalView: MTKView, identifier: String) {
        let metalAnimation = MetalAnimation()
        metalAnimation.identifier = identifier
        metalAnimation.type = .oscilloscope
        metalAnimation.waveformData = waveformData
        metalAnimation.lastUpdateTime = CACurrentMediaTime()
        
        metalAnimation.parameters = [
            "amplitude": 1.0,
            "lineWidth": 2.0,
            "glowRadius": 3.0,
            "color": simd_float3(0, 1, 0),
            "fadeSpeed": 0.1
        ]
        
        metalAnimations[identifier] = metalAnimation
        metalView.needsDisplay = true
    }
    
    // MARK: - Text Animations
    
    /// Create smooth scrolling text animation for song titles
    func createScrollingTextAnimation(for layer: CATextLayer, text: String, containerWidth: CGFloat, identifier: String) {
        let textWidth = layer.preferredFrameSize().width
        
        guard textWidth > containerWidth else {
            // Text fits, no scrolling needed
            return
        }
        
        let scrollDistance = textWidth - containerWidth + 20 // Extra padding
        
        let scrollAnimation = CAKeyframeAnimation(keyPath: "position.x")
        scrollAnimation.values = [
            0,                          // Start position
            0,                          // Pause at start
            -scrollDistance,            // Scroll to end
            -scrollDistance,            // Pause at end
            0                          // Return to start
        ]
        
        scrollAnimation.keyTimes = [0.0, 0.2, 0.7, 0.9, 1.0]
        scrollAnimation.duration = 8.0 // 8-second cycle
        scrollAnimation.repeatCount = .infinity
        scrollAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        layer.add(scrollAnimation, forKey: "textScroll_\(identifier)")
    }
    
    /// Create typewriter effect for text appearance
    func createTypewriterAnimation(for layer: CATextLayer, text: String, speed: TimeInterval = 0.05, identifier: String) {
        let characters = Array(text)
        let timeline = AnimationTimeline()
        timeline.identifier = identifier
        timeline.duration = Double(characters.count) * speed
        timeline.startTime = CACurrentMediaTime()
        
        timeline.updateBlock = { [weak layer] progress in
            guard let layer = layer else { return }
            
            let charIndex = Int(progress * Double(characters.count))
            let visibleText = String(characters.prefix(charIndex))
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.string = visibleText
            CATransaction.commit()
        }
        
        activeTimelines[identifier] = timeline
    }
    
    // MARK: - Metal Animation Updates
    
    private func updateMetalAnimations(deltaTime: Float) {
        for (_, animation) in metalAnimations {
            animation.update(deltaTime: deltaTime)
        }
    }
    
    private func updateTimelineAnimations(currentTime: CFTimeInterval) {
        var completedTimelines: [String] = []
        
        for (identifier, timeline) in activeTimelines {
            let elapsed = currentTime - timeline.startTime
            let progress = min(elapsed / timeline.duration, 1.0)
            
            timeline.updateBlock?(progress)
            
            if progress >= 1.0 {
                timeline.completionBlock?()
                completedTimelines.append(identifier)
            }
        }
        
        // Remove completed timelines
        for identifier in completedTimelines {
            activeTimelines.removeValue(forKey: identifier)
        }
    }
    
    // MARK: - Performance Management
    
    private func updatePerformanceMetrics() {
        performanceMetrics.currentFPS = Float(frameCount) / Float(lastFrameTime - performanceMetrics.lastMeasurementTime)
        performanceMetrics.lastMeasurementTime = lastFrameTime
        performanceMetrics.droppedFrames += frameCount > Int(targetFrameRate) ? 0 : Int(targetFrameRate) - frameCount
        
        // Adaptive performance - reduce animation quality if performance drops
        if performanceMetrics.currentFPS < targetFrameRate * 0.8 {
            adaptAnimationQuality(reduce: true)
        } else if performanceMetrics.currentFPS > targetFrameRate * 0.95 {
            adaptAnimationQuality(reduce: false)
        }
        
        frameCount = 0
    }
    
    private func adaptAnimationQuality(reduce: Bool) {
        let qualityFactor: Float = reduce ? 0.5 : 1.0
        
        // Adjust Metal animation parameters
        for (_, animation) in metalAnimations {
            if let smoothing = animation.parameters["smoothing"] as? Float {
                animation.parameters["smoothing"] = smoothing * qualityFactor
            }
        }
        
        // Adjust Core Animation timing
        CATransaction.begin()
        CATransaction.setAnimationDuration(reduce ? 0.05 : 0.1)
        CATransaction.commit()
    }
    
    // MARK: - Public Controls
    
    func startAnimations() {
        if let displayLink = displayLink {
            CVDisplayLinkStart(displayLink)
        }
    }
    
    func stopAnimations() {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
    
    func pauseAnimation(_ identifier: String) {
        if let timeline = activeTimelines[identifier] {
            timeline.isPaused = true
        }
        
        if let layer = animationLayers[identifier] {
            layer.speed = 0
            layer.timeOffset = layer.convertTime(CACurrentMediaTime(), from: nil)
        }
    }
    
    func resumeAnimation(_ identifier: String) {
        if let timeline = activeTimelines[identifier] {
            timeline.isPaused = false
        }
        
        if let layer = animationLayers[identifier] {
            let pausedTime = layer.timeOffset
            layer.speed = 1.0
            layer.timeOffset = 0.0
            layer.beginTime = 0.0
            let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
            layer.beginTime = timeSincePause
        }
    }
    
    func removeAnimation(_ identifier: String) {
        activeTimelines.removeValue(forKey: identifier)
        animationGroups.removeValue(forKey: identifier)
        metalAnimations.removeValue(forKey: identifier)
        
        if let layer = animationLayers[identifier] {
            layer.removeAllAnimations()
            animationLayers.removeValue(forKey: identifier)
        }
    }
    
    func removeAllAnimations() {
        activeTimelines.removeAll()
        animationGroups.removeAll()
        metalAnimations.removeAll()
        
        for layer in animationLayers.values {
            layer.removeAllAnimations()
        }
        animationLayers.removeAll()
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopAnimations()
        if let displayLink = displayLink {
            CVDisplayLinkRelease(displayLink)
        }
        removeAllAnimations()
    }
}

// MARK: - Supporting Classes

class MetalAnimation {
    var identifier: String = ""
    var type: MetalAnimationType = .spectrum
    var audioData: [Float] = []
    var waveformData: [Float] = []
    var parameters: [String: Any] = [:]
    var lastUpdateTime: CFTimeInterval = 0
    var isActive: Bool = true
    
    func update(deltaTime: Float) {
        guard isActive else { return }
        
        switch type {
        case .spectrum:
            updateSpectrumAnimation(deltaTime: deltaTime)
        case .oscilloscope:
            updateOscilloscopeAnimation(deltaTime: deltaTime)
        case .particle:
            updateParticleAnimation(deltaTime: deltaTime)
        }
        
        lastUpdateTime = CACurrentMediaTime()
    }
    
    private func updateSpectrumAnimation(deltaTime: Float) {
        guard let smoothing = parameters["smoothing"] as? Float,
              let decay = parameters["decay"] as? Float else { return }
        
        // Apply smoothing and decay to audio data
        for i in 0..<audioData.count {
            audioData[i] = audioData[i] * (1.0 - smoothing) + audioData[i] * smoothing
            audioData[i] = max(0, audioData[i] - decay * deltaTime)
        }
    }
    
    private func updateOscilloscopeAnimation(deltaTime: Float) {
        guard let fadeSpeed = parameters["fadeSpeed"] as? Float else { return }
        
        // Apply fade effect to waveform data
        for i in 0..<waveformData.count {
            waveformData[i] *= (1.0 - fadeSpeed * deltaTime)
        }
    }
    
    private func updateParticleAnimation(deltaTime: Float) {
        // Placeholder for particle system updates
    }
}

enum MetalAnimationType {
    case spectrum
    case oscilloscope
    case particle
}

class AnimationTimeline {
    var identifier: String = ""
    var duration: TimeInterval = 0
    var startTime: CFTimeInterval = 0
    var isPaused: Bool = false
    var updateBlock: ((Double) -> Void)?
    var completionBlock: (() -> Void)?
}

struct AnimationPerformanceMetrics {
    var currentFPS: Float = 0
    var averageFPS: Float = 0
    var droppedFrames: Int = 0
    var lastMeasurementTime: CFTimeInterval = 0
    var totalFrames: Int = 0
}

// MARK: - Animation Presets

extension CoreAnimationSystem {
    
    /// Create a set of preset animations for common UI elements
    func loadAnimationPresets() {
        // Button press presets
        registerAnimationPreset(name: "standardButtonPress") { layer, identifier in
            self.createButtonPressAnimation(for: layer, identifier: identifier)
        }
        
        // Slider presets
        registerAnimationPreset(name: "smoothSlider") { layer, identifier in
            // Configure for smooth slider movement
        }
        
        // Visualization presets
        registerAnimationPreset(name: "classicSpectrum") { _, identifier in
            // Classic Winamp-style spectrum analyzer
        }
    }
    
    private func registerAnimationPreset(name: String, animation: @escaping (CALayer, String) -> Void) {
        // Store animation presets for reuse
    }
}