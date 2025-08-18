import Foundation
import CoreVideo
import QuartzCore
import Metal
import MetalKit
import os.signpost

/// Adaptive frame rate management system for optimal performance and battery life
/// Dynamically adjusts frame rate based on content complexity, performance metrics, and power state
@MainActor
public final class AdaptiveFrameRateManager: ObservableObject {
    
    // MARK: - Frame Rate Modes
    public enum FrameRateMode: String, CaseIterable, Sendable {
        case powerSaver = "Power Saver"        // 30Hz, minimal effects
        case balanced = "Balanced"             // 60Hz, moderate effects
        case performance = "Performance"       // 120Hz, full effects
        case adaptive = "Adaptive"             // Dynamic based on conditions
    }
    
    public enum ContentComplexity: Int, Comparable, Sendable {
        case minimal = 1    // Static UI, no visualization
        case low = 2        // Simple spectrum analyzer
        case medium = 3     // Complex visualizations
        case high = 4       // 3D effects, particles
        case extreme = 5    // Maximum complexity
        
        public static func < (lhs: ContentComplexity, rhs: ContentComplexity) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Performance Metrics
    public struct FrameRateMetrics: Sendable {
        let currentFrameRate: Double
        let targetFrameRate: Double
        let cpuUsage: Double
        let gpuUsage: Double
        let memoryPressure: Double
        let thermalState: ProcessInfo.ThermalState
        let batteryLevel: Double
        let isPluggedIn: Bool
        let contentComplexity: ContentComplexity
        let frameDropRate: Double
        let adaptationReason: String
    }
    
    // MARK: - Motion Prediction
    private struct MotionPredictor {
        private var velocityHistory: [Double] = []
        private var accelerationHistory: [Double] = []
        private let historyLimit = 10
        
        mutating func addVelocity(_ velocity: Double) {
            velocityHistory.append(velocity)
            if velocityHistory.count > historyLimit {
                velocityHistory.removeFirst()
            }
            
            // Calculate acceleration
            if velocityHistory.count >= 2 {
                let acceleration = velocityHistory.last! - velocityHistory[velocityHistory.count - 2]
                accelerationHistory.append(acceleration)
                if accelerationHistory.count > historyLimit {
                    accelerationHistory.removeFirst()
                }
            }
        }
        
        func predictMotion(timeAhead: TimeInterval) -> Double {
            guard !velocityHistory.isEmpty else { return 0 }
            
            let currentVelocity = velocityHistory.last!
            let currentAcceleration = accelerationHistory.isEmpty ? 0 : accelerationHistory.last!
            
            // Simple kinematic prediction: v = v0 + at
            return currentVelocity + currentAcceleration * timeAhead
        }
        
        var averageVelocity: Double {
            guard !velocityHistory.isEmpty else { return 0 }
            return velocityHistory.reduce(0, +) / Double(velocityHistory.count)
        }
        
        var isMotionStable: Bool {
            guard accelerationHistory.count >= 3 else { return false }
            
            let recentAccelerations = Array(accelerationHistory.suffix(3))
            let variance = calculateVariance(recentAccelerations)
            
            return variance < 0.1 // Low variance indicates stable motion
        }
        
        private func calculateVariance(_ values: [Double]) -> Double {
            guard values.count > 1 else { return 0 }
            
            let mean = values.reduce(0, +) / Double(values.count)
            let sumSquares = values.map { pow($0 - mean, 2) }.reduce(0, +)
            
            return sumSquares / Double(values.count - 1)
        }
        
        mutating func reset() {
            velocityHistory.removeAll()
            accelerationHistory.removeAll()
        }
    }
    
    // MARK: - Properties
    private let device: MTLDevice
    private var displayLink: CVDisplayLink?
    private var currentMode: FrameRateMode = .adaptive
    private var currentFrameRate: Double = 60.0
    private var targetFrameRate: Double = 60.0
    
    // Performance monitoring
    private var frameTimeHistory: [TimeInterval] = []
    private var cpuUsageHistory: [Double] = []
    private var gpuUsageHistory: [Double] = []
    private var frameDropHistory: [Bool] = []
    
    // Motion prediction
    private var motionPredictor = MotionPredictor()
    private var lastMousePosition: CGPoint = .zero
    private var mouseVelocity: Double = 0.0
    
    // Power management
    private var batteryMonitor: BatteryMonitor?
    private var thermalMonitor: ThermalMonitor?
    
    // Adaptation parameters
    private var adaptationCooldown: TimeInterval = 2.0
    private var lastAdaptationTime: TimeInterval = 0
    private var currentContentComplexity: ContentComplexity = .minimal
    
    // Performance thresholds
    private let performanceThresholds = PerformanceThresholds(
        highCPUThreshold: 80.0,
        highGPUThreshold: 85.0,
        highMemoryThreshold: 0.8,
        frameDropThreshold: 0.05,
        batteryLowThreshold: 0.2,
        thermalThrottleTemperature: ProcessInfo.ThermalState.critical
    )
    
    // Signposting
    private let performanceLogger = OSLog(subsystem: "com.winamp.macos", category: "AdaptiveFrameRate")
    private let signpostID: OSSignpostID
    
    // Published properties for UI binding
    @Published public private(set) var currentMetrics: FrameRateMetrics
    @Published public private(set) var isAdaptationEnabled = true
    @Published public private(set) var adaptationHistory: [AdaptationEvent] = []
    
    public init(device: MTLDevice) throws {
        self.device = device
        self.signpostID = OSSignpostID(log: performanceLogger)
        
        // Initialize with default metrics
        self.currentMetrics = FrameRateMetrics(
            currentFrameRate: 60.0,
            targetFrameRate: 60.0,
            cpuUsage: 0.0,
            gpuUsage: 0.0,
            memoryPressure: 0.0,
            thermalState: .nominal,
            batteryLevel: 1.0,
            isPluggedIn: true,
            contentComplexity: .minimal,
            frameDropRate: 0.0,
            adaptationReason: "Initial state"
        )
        
        setupMonitoring()
        setupDisplayLink()
    }
    
    deinit {
        stopAdaptation()
    }
    
    // MARK: - Setup
    private func setupMonitoring() {
        batteryMonitor = BatteryMonitor { [weak self] batteryInfo in
            Task { @MainActor in
                self?.updateBatteryInfo(batteryInfo)
            }
        }
        
        thermalMonitor = ThermalMonitor { [weak self] thermalState in
            Task { @MainActor in
                self?.updateThermalState(thermalState)
            }
        }
    }
    
    private func setupDisplayLink() {
        var displayLink: CVDisplayLink?
        let displayLinkOutputCallback: CVDisplayLinkOutputCallback = { 
            (displayLink, now, outputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
            
            let manager = Unmanaged<AdaptiveFrameRateManager>.fromOpaque(displayLinkContext!).takeUnretainedValue()
            
            Task { @MainActor in
                manager.processFrame(now: now.pointee, outputTime: outputTime.pointee)
            }
            
            return kCVReturnSuccess
        }
        
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, displayLinkOutputCallback, 
                                         Unmanaged.passUnretained(self).toOpaque())
            self.displayLink = displayLink
        }
    }
    
    // MARK: - Frame Processing
    private func processFrame(now: CVTimeStamp, outputTime: CVTimeStamp) {
        let currentTime = CACurrentMediaTime()
        
        // Calculate frame timing
        if !frameTimeHistory.isEmpty {
            let frameTime = currentTime - frameTimeHistory.last!
            let targetFrameTime = 1.0 / targetFrameRate
            
            // Record frame drop if significantly over target
            let frameDropped = frameTime > targetFrameTime * 1.5
            frameDropHistory.append(frameDropped)
            
            // Limit history size
            if frameDropHistory.count > 300 { // 5 seconds at 60Hz
                frameDropHistory.removeFirst()
            }
        }
        
        frameTimeHistory.append(currentTime)
        if frameTimeHistory.count > 300 {
            frameTimeHistory.removeFirst()
        }
        
        // Update motion prediction
        updateMotionPrediction()
        
        // Check if adaptation is needed
        if shouldAdapt() {
            performAdaptation()
        }
        
        // Update metrics
        updateMetrics()
    }
    
    private func updateMotionPrediction() {
        // Get current mouse position
        let mouseLocation = NSEvent.mouseLocation
        let velocity = distance(from: lastMousePosition, to: mouseLocation)
        
        motionPredictor.addVelocity(velocity)
        mouseVelocity = velocity
        lastMousePosition = mouseLocation
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> Double {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // MARK: - Adaptation Logic
    private func shouldAdapt() -> Bool {
        guard isAdaptationEnabled && currentMode == .adaptive else { return false }
        
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastAdaptationTime > adaptationCooldown else { return false }
        
        // Check various conditions that trigger adaptation
        return checkPerformanceThresholds() || 
               checkPowerConditions() || 
               checkContentComplexityChange() ||
               checkMotionRequirements()
    }
    
    private func checkPerformanceThresholds() -> Bool {
        let metrics = getCurrentSystemMetrics()
        
        return metrics.cpuUsage > performanceThresholds.highCPUThreshold ||
               metrics.gpuUsage > performanceThresholds.highGPUThreshold ||
               metrics.memoryPressure > performanceThresholds.highMemoryThreshold ||
               metrics.frameDropRate > performanceThresholds.frameDropThreshold
    }
    
    private func checkPowerConditions() -> Bool {
        let batteryInfo = getBatteryInfo()
        let thermalState = ProcessInfo.processInfo.thermalState
        
        return (!batteryInfo.isPluggedIn && batteryInfo.level < performanceThresholds.batteryLowThreshold) ||
               thermalState.rawValue >= performanceThresholds.thermalThrottleTemperature.rawValue
    }
    
    private func checkContentComplexityChange() -> Bool {
        // This would be set by the visualization system
        return false // Placeholder
    }
    
    private func checkMotionRequirements() -> Bool {
        // High velocity motion might benefit from higher frame rates
        let predictedMotion = motionPredictor.predictMotion(timeAhead: 0.1)
        let highMotion = predictedMotion > 50.0 // pixels per second
        
        // If we're at low frame rate but detecting high motion, we should adapt
        return highMotion && currentFrameRate < 120.0
    }
    
    private func performAdaptation() {
        let metrics = getCurrentSystemMetrics()
        let newFrameRate = calculateOptimalFrameRate(metrics: metrics)
        let reason = determineAdaptationReason(metrics: metrics)
        
        if abs(newFrameRate - currentFrameRate) > 5.0 { // Only adapt if significant change
            setFrameRate(newFrameRate, reason: reason)
            
            lastAdaptationTime = CACurrentMediaTime()
            
            // Record adaptation event
            let event = AdaptationEvent(
                timestamp: Date(),
                fromFrameRate: currentFrameRate,
                toFrameRate: newFrameRate,
                reason: reason,
                metrics: metrics
            )
            adaptationHistory.append(event)
            
            // Limit history
            if adaptationHistory.count > 100 {
                adaptationHistory.removeFirst()
            }
            
            os_signpost(.event, log: performanceLogger, name: "FrameRateAdaptation",
                       "From: %{public}.0f, To: %{public}.0f, Reason: %{public}s",
                       currentFrameRate, newFrameRate, reason)
        }
    }
    
    private func calculateOptimalFrameRate(metrics: SystemMetrics) -> Double {
        var optimalRate: Double = 60.0
        
        // Start with power considerations
        let batteryInfo = getBatteryInfo()
        if !batteryInfo.isPluggedIn {
            if batteryInfo.level < 0.2 {
                optimalRate = 30.0 // Very low battery
            } else if batteryInfo.level < 0.5 {
                optimalRate = 60.0 // Medium battery
            }
        }
        
        // Adjust for thermal state
        switch metrics.thermalState {
        case .critical:
            optimalRate = min(optimalRate, 30.0)
        case .serious:
            optimalRate = min(optimalRate, 60.0)
        case .fair:
            optimalRate = min(optimalRate, 90.0)
        case .nominal:
            // No thermal constraints
            break
        @unknown default:
            optimalRate = min(optimalRate, 60.0)
        }
        
        // Adjust for performance metrics
        if metrics.cpuUsage > 80.0 || metrics.gpuUsage > 85.0 {
            optimalRate = min(optimalRate, 60.0)
        } else if metrics.cpuUsage < 50.0 && metrics.gpuUsage < 60.0 {
            // System has headroom, can increase frame rate
            optimalRate = min(optimalRate * 1.5, 120.0)
        }
        
        // Adjust for content complexity
        switch currentContentComplexity {
        case .minimal:
            optimalRate = min(optimalRate, 60.0)
        case .low:
            optimalRate = min(optimalRate, 90.0)
        case .medium, .high, .extreme:
            // Complex content benefits from high frame rates if system can handle it
            if metrics.cpuUsage < 70.0 && metrics.gpuUsage < 75.0 {
                optimalRate = min(optimalRate, 120.0)
            }
        }
        
        // Consider motion prediction
        let predictedMotion = motionPredictor.predictMotion(timeAhead: 0.1)
        if predictedMotion > 100.0 && metrics.cpuUsage < 60.0 {
            optimalRate = min(optimalRate * 1.2, 120.0)
        }
        
        // Quantize to common frame rates
        return quantizeFrameRate(optimalRate)
    }
    
    private func quantizeFrameRate(_ rate: Double) -> Double {
        let commonRates: [Double] = [30.0, 48.0, 60.0, 72.0, 90.0, 120.0]
        
        var closestRate = commonRates[0]
        var minDifference = abs(rate - closestRate)
        
        for commonRate in commonRates {
            let difference = abs(rate - commonRate)
            if difference < minDifference {
                minDifference = difference
                closestRate = commonRate
            }
        }
        
        return closestRate
    }
    
    private func determineAdaptationReason(metrics: SystemMetrics) -> String {
        var reasons: [String] = []
        
        if metrics.cpuUsage > performanceThresholds.highCPUThreshold {
            reasons.append("High CPU usage (\(Int(metrics.cpuUsage))%)")
        }
        
        if metrics.gpuUsage > performanceThresholds.highGPUThreshold {
            reasons.append("High GPU usage (\(Int(metrics.gpuUsage))%)")
        }
        
        if metrics.frameDropRate > performanceThresholds.frameDropThreshold {
            reasons.append("Frame drops (\(String(format: "%.1f", metrics.frameDropRate * 100))%)")
        }
        
        let batteryInfo = getBatteryInfo()
        if !batteryInfo.isPluggedIn && batteryInfo.level < performanceThresholds.batteryLowThreshold {
            reasons.append("Low battery (\(Int(batteryInfo.level * 100))%)")
        }
        
        if metrics.thermalState.rawValue >= ProcessInfo.ThermalState.fair.rawValue {
            reasons.append("Thermal throttling (\(metrics.thermalState))")
        }
        
        let predictedMotion = motionPredictor.predictMotion(timeAhead: 0.1)
        if predictedMotion > 100.0 {
            reasons.append("High motion detected")
        }
        
        return reasons.isEmpty ? "Optimization" : reasons.joined(separator: ", ")
    }
    
    // MARK: - Public Interface
    public func setMode(_ mode: FrameRateMode) {
        let previousMode = currentMode
        currentMode = mode
        
        let newFrameRate: Double
        switch mode {
        case .powerSaver:
            newFrameRate = 30.0
        case .balanced:
            newFrameRate = 60.0
        case .performance:
            newFrameRate = 120.0
        case .adaptive:
            newFrameRate = calculateOptimalFrameRate(metrics: getCurrentSystemMetrics())
        }
        
        setFrameRate(newFrameRate, reason: "Mode changed from \(previousMode.rawValue) to \(mode.rawValue)")
    }
    
    public func setContentComplexity(_ complexity: ContentComplexity) {
        let previousComplexity = currentContentComplexity
        currentContentComplexity = complexity
        
        if currentMode == .adaptive && complexity != previousComplexity {
            // Trigger re-evaluation
            if shouldAdapt() {
                performAdaptation()
            }
        }
    }
    
    public func enableAdaptation(_ enabled: Bool) {
        isAdaptationEnabled = enabled
        
        if enabled && currentMode == .adaptive {
            startAdaptation()
        } else {
            stopAdaptation()
        }
    }
    
    public func startAdaptation() {
        guard currentMode == .adaptive && isAdaptationEnabled else { return }
        
        if let displayLink = displayLink {
            CVDisplayLinkStart(displayLink)
        }
        
        batteryMonitor?.start()
        thermalMonitor?.start()
        
        os_signpost(.begin, log: performanceLogger, name: "AdaptiveFrameRate")
    }
    
    public func stopAdaptation() {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
        
        batteryMonitor?.stop()
        thermalMonitor?.stop()
        
        os_signpost(.end, log: performanceLogger, name: "AdaptiveFrameRate")
    }
    
    private func setFrameRate(_ frameRate: Double, reason: String) {
        currentFrameRate = frameRate
        targetFrameRate = frameRate
        
        // Update display link timing if needed
        if let displayLink = displayLink {
            CVDisplayLinkSetNominalOutputVideoRefreshPeriod(displayLink, 
                CVTime(timeValue: Int64(1), timeScale: Int32(frameRate)))
        }
        
        updateMetrics()
    }
    
    // MARK: - Metrics and Monitoring
    private func updateMetrics() {
        let systemMetrics = getCurrentSystemMetrics()
        let batteryInfo = getBatteryInfo()
        
        currentMetrics = FrameRateMetrics(
            currentFrameRate: currentFrameRate,
            targetFrameRate: targetFrameRate,
            cpuUsage: systemMetrics.cpuUsage,
            gpuUsage: systemMetrics.gpuUsage,
            memoryPressure: systemMetrics.memoryPressure,
            thermalState: systemMetrics.thermalState,
            batteryLevel: batteryInfo.level,
            isPluggedIn: batteryInfo.isPluggedIn,
            contentComplexity: currentContentComplexity,
            frameDropRate: systemMetrics.frameDropRate,
            adaptationReason: "Current state"
        )
    }
    
    private func getCurrentSystemMetrics() -> SystemMetrics {
        let cpuUsage = getCurrentCPUUsage()
        let gpuUsage = 0.0 // Would need Metal performance counters
        let memoryPressure = getCurrentMemoryPressure()
        let frameDropRate = calculateFrameDropRate()
        
        return SystemMetrics(
            cpuUsage: cpuUsage,
            gpuUsage: gpuUsage,
            memoryPressure: memoryPressure,
            thermalState: ProcessInfo.processInfo.thermalState,
            frameDropRate: frameDropRate
        )
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Implementation similar to ProMotionPerformanceTester
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
            return Double(info.resident_size) / (1024 * 1024) // Convert to MB
        }
        return 0.0
    }
    
    private func getCurrentMemoryPressure() -> Double {
        let pageSize = vm_kernel_page_size
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.count)
        
        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let totalPages = vmStat.free_count + vmStat.active_count + vmStat.inactive_count + vmStat.wire_count
            let usedPages = vmStat.active_count + vmStat.inactive_count + vmStat.wire_count
            return Double(usedPages) / Double(totalPages)
        }
        
        return 0.0
    }
    
    private func calculateFrameDropRate() -> Double {
        guard !frameDropHistory.isEmpty else { return 0.0 }
        
        let droppedFrames = frameDropHistory.filter { $0 }.count
        return Double(droppedFrames) / Double(frameDropHistory.count)
    }
    
    private func getBatteryInfo() -> BatteryInfo {
        // Placeholder implementation - would use IOKit for real battery monitoring
        return BatteryInfo(level: 0.8, isPluggedIn: true)
    }
    
    private func updateBatteryInfo(_ info: BatteryInfo) {
        // Handle battery state changes
        if currentMode == .adaptive {
            // Trigger re-evaluation if battery state changed significantly
            if shouldAdapt() {
                performAdaptation()
            }
        }
    }
    
    private func updateThermalState(_ state: ProcessInfo.ThermalState) {
        // Handle thermal state changes
        if currentMode == .adaptive {
            if shouldAdapt() {
                performAdaptation()
            }
        }
    }
}

// MARK: - Supporting Types
public struct AdaptationEvent: Sendable {
    let timestamp: Date
    let fromFrameRate: Double
    let toFrameRate: Double
    let reason: String
    let metrics: SystemMetrics
}

private struct SystemMetrics: Sendable {
    let cpuUsage: Double
    let gpuUsage: Double
    let memoryPressure: Double
    let thermalState: ProcessInfo.ThermalState
    let frameDropRate: Double
}

private struct PerformanceThresholds {
    let highCPUThreshold: Double
    let highGPUThreshold: Double
    let highMemoryThreshold: Double
    let frameDropThreshold: Double
    let batteryLowThreshold: Double
    let thermalThrottleTemperature: ProcessInfo.ThermalState
}

private struct BatteryInfo: Sendable {
    let level: Double
    let isPluggedIn: Bool
}

// MARK: - Battery and Thermal Monitoring
private class BatteryMonitor {
    private let callback: (BatteryInfo) -> Void
    private var timer: Timer?
    
    init(callback: @escaping (BatteryInfo) -> Void) {
        self.callback = callback
    }
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            // Mock implementation - would use IOKit for real monitoring
            let info = BatteryInfo(level: 0.8, isPluggedIn: true)
            self.callback(info)
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

private class ThermalMonitor {
    private let callback: (ProcessInfo.ThermalState) -> Void
    private var observer: NSObjectProtocol?
    
    init(callback: @escaping (ProcessInfo.ThermalState) -> Void) {
        self.callback = callback
    }
    
    func start() {
        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.callback(ProcessInfo.processInfo.thermalState)
        }
    }
    
    func stop() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}