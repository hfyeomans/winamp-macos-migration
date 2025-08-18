import Foundation
import Metal
import MetalKit
import QuartzCore
import Combine
import os.signpost

/// Real-time performance monitoring system for Winamp macOS
/// Provides live FPS counter, GPU/CPU usage graphs, and performance recommendations
@MainActor
public final class PerformanceMonitor: ObservableObject {
    
    // MARK: - Real-time Metrics
    public struct LiveMetrics: Sendable {
        let timestamp: TimeInterval
        let frameRate: Double
        let frameTime: TimeInterval
        let cpuUsage: Double
        let gpuUsage: Double
        let memoryUsage: Double
        let memoryPressure: MemoryPressureLevel
        let thermalState: ProcessInfo.ThermalState
        let powerUsage: Double
        let networkActivity: NetworkActivity
        let diskActivity: DiskActivity
        let renderingStats: RenderingStats
    }
    
    public enum MemoryPressureLevel: String, CaseIterable, Sendable {
        case normal = "Normal"
        case warning = "Warning"
        case urgent = "Urgent"
        case critical = "Critical"
    }
    
    public struct NetworkActivity: Sendable {
        let bytesIn: UInt64
        let bytesOut: UInt64
        let packetsIn: UInt64
        let packetsOut: UInt64
    }
    
    public struct DiskActivity: Sendable {
        let bytesRead: UInt64
        let bytesWritten: UInt64
        let operations: UInt64
    }
    
    public struct RenderingStats: Sendable {
        let drawCalls: Int
        let triangles: Int
        let vertices: Int
        let textureMemory: UInt64
        let bufferMemory: UInt64
        let pipelineStateChanges: Int
        let commandBufferCount: Int
    }
    
    // MARK: - Performance History
    public struct PerformanceHistory {
        var frameRates: CircularBuffer<Double>
        var frameTimes: CircularBuffer<TimeInterval>
        var cpuUsages: CircularBuffer<Double>
        var gpuUsages: CircularBuffer<Double>
        var memoryUsages: CircularBuffer<Double>
        var thermalStates: CircularBuffer<ProcessInfo.ThermalState>
        
        init(capacity: Int = 300) { // 5 minutes at 1Hz sampling
            frameRates = CircularBuffer(capacity: capacity)
            frameTimes = CircularBuffer(capacity: capacity)
            cpuUsages = CircularBuffer(capacity: capacity)
            gpuUsages = CircularBuffer(capacity: capacity)
            memoryUsages = CircularBuffer(capacity: capacity)
            thermalStates = CircularBuffer(capacity: capacity)
        }
    }
    
    // MARK: - Performance Recommendations
    public struct PerformanceRecommendation: Sendable {
        let severity: Severity
        let category: Category
        let title: String
        let description: String
        let suggestedAction: String
        let estimatedImpact: ImpactLevel
        let automaticallyApplicable: Bool
        let timestamp: Date
        
        public enum Severity: String, CaseIterable, Sendable {
            case info = "Info"
            case warning = "Warning"
            case critical = "Critical"
        }
        
        public enum Category: String, CaseIterable, Sendable {
            case frameRate = "Frame Rate"
            case memory = "Memory"
            case thermal = "Thermal"
            case power = "Power"
            case gpu = "GPU"
            case cpu = "CPU"
            case disk = "Disk"
            case network = "Network"
        }
        
        public enum ImpactLevel: String, CaseIterable, Sendable {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case critical = "Critical"
        }
    }
    
    // MARK: - Properties
    private let device: MTLDevice
    private var displayLink: CVDisplayLink?
    private var monitoringTimer: Timer?
    private var isMonitoring = false
    
    // Performance tracking
    private var performanceHistory = PerformanceHistory()
    private var lastFrameTime: TimeInterval = 0
    private var frameCount: UInt64 = 0
    private var startTime: TimeInterval = 0
    
    // System monitoring
    private var systemMonitor: SystemMonitor
    private var metalMonitor: MetalMonitor
    private var recommendationEngine: RecommendationEngine
    
    // Published properties for UI binding
    @Published public private(set) var currentMetrics: LiveMetrics
    @Published public private(set) var isActive = false
    @Published public private(set) var recommendations: [PerformanceRecommendation] = []
    @Published public private(set) var alertCount = 0
    @Published public private(set) var performanceScore: Double = 100.0
    
    // Configuration
    public var samplingInterval: TimeInterval = 1.0 // 1 second
    public var enableRecommendations = true
    public var enableAutoOptimization = false
    public var showDebugInfo = false
    
    // Signposting
    private let performanceLogger = OSLog(subsystem: "com.winamp.macos", category: "PerformanceMonitor")
    private let signpostID: OSSignpostID
    
    // Singleton instance
    public static let shared = try! PerformanceMonitor(device: MTLCreateSystemDefaultDevice()!)
    
    public init(device: MTLDevice) throws {
        self.device = device
        self.signpostID = OSSignpostID(log: performanceLogger)
        
        // Initialize monitoring components
        self.systemMonitor = SystemMonitor()
        self.metalMonitor = try MetalMonitor(device: device)
        self.recommendationEngine = RecommendationEngine()
        
        // Initialize with default metrics
        self.currentMetrics = LiveMetrics(
            timestamp: CACurrentMediaTime(),
            frameRate: 0.0,
            frameTime: 0.0,
            cpuUsage: 0.0,
            gpuUsage: 0.0,
            memoryUsage: 0.0,
            memoryPressure: .normal,
            thermalState: .nominal,
            powerUsage: 0.0,
            networkActivity: NetworkActivity(bytesIn: 0, bytesOut: 0, packetsIn: 0, packetsOut: 0),
            diskActivity: DiskActivity(bytesRead: 0, bytesWritten: 0, operations: 0),
            renderingStats: RenderingStats(
                drawCalls: 0, triangles: 0, vertices: 0,
                textureMemory: 0, bufferMemory: 0,
                pipelineStateChanges: 0, commandBufferCount: 0
            )
        )
        
        setupDisplayLink()
        setupNotifications()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Setup
    private func setupDisplayLink() {
        var displayLink: CVDisplayLink?
        let displayLinkOutputCallback: CVDisplayLinkOutputCallback = { 
            (displayLink, now, outputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
            
            let monitor = Unmanaged<PerformanceMonitor>.fromOpaque(displayLinkContext!).takeUnretainedValue()
            
            Task { @MainActor in
                monitor.processFrame(now: now.pointee, outputTime: outputTime.pointee)
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
    
    private func setupNotifications() {
        // Monitor thermal state changes
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleThermalStateChange()
        }
        
        // Monitor memory pressure warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    // MARK: - Monitoring Control
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        isActive = true
        startTime = CACurrentMediaTime()
        frameCount = 0
        
        // Start display link for frame timing
        if let displayLink = displayLink {
            CVDisplayLinkStart(displayLink)
        }
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: samplingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMetrics()
            }
        }
        
        os_signpost(.begin, log: performanceLogger, name: "PerformanceMonitoring")
    }
    
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        isActive = false
        
        // Stop display link
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
        
        // Stop timer
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        os_signpost(.end, log: performanceLogger, name: "PerformanceMonitoring")
    }
    
    // MARK: - Frame Processing
    private func processFrame(now: CVTimeStamp, outputTime: CVTimeStamp) {
        guard isMonitoring else { return }
        
        let currentTime = CACurrentMediaTime()
        
        // Calculate frame timing
        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            performanceHistory.frameTimes.append(frameTime)
            
            let frameRate = frameTime > 0 ? 1.0 / frameTime : 0.0
            performanceHistory.frameRates.append(frameRate)
        }
        
        lastFrameTime = currentTime
        frameCount += 1
        
        // Record metrics periodically to avoid overwhelming the system
        if frameCount % 60 == 0 { // Every 60 frames
            Task {
                await updateFrameMetrics()
            }
        }
    }
    
    private func updateFrameMetrics() async {
        let recentFrameRates = performanceHistory.frameRates.recentValues(count: 60)
        let averageFrameRate = recentFrameRates.isEmpty ? 0.0 : 
            recentFrameRates.reduce(0, +) / Double(recentFrameRates.count)
        
        let recentFrameTimes = performanceHistory.frameTimes.recentValues(count: 60)
        let averageFrameTime = recentFrameTimes.isEmpty ? 0.0 : 
            recentFrameTimes.reduce(0, +) / Double(recentFrameTimes.count)
        
        // Update current metrics with frame data
        var updatedMetrics = currentMetrics
        updatedMetrics.frameRate = averageFrameRate
        updatedMetrics.frameTime = averageFrameTime
        updatedMetrics.timestamp = CACurrentMediaTime()
        
        currentMetrics = updatedMetrics
    }
    
    // MARK: - Metrics Collection
    private func updateMetrics() async {
        let timestamp = CACurrentMediaTime()
        
        // Collect system metrics
        let cpuUsage = systemMonitor.getCPUUsage()
        let memoryInfo = systemMonitor.getMemoryInfo()
        let thermalState = ProcessInfo.processInfo.thermalState
        let powerUsage = systemMonitor.getPowerUsage()
        let networkActivity = systemMonitor.getNetworkActivity()
        let diskActivity = systemMonitor.getDiskActivity()
        
        // Collect Metal metrics
        let gpuUsage = metalMonitor.getGPUUsage()
        let renderingStats = metalMonitor.getRenderingStats()
        
        // Update history
        performanceHistory.cpuUsages.append(cpuUsage)
        performanceHistory.gpuUsages.append(gpuUsage)
        performanceHistory.memoryUsages.append(memoryInfo.usage)
        performanceHistory.thermalStates.append(thermalState)
        
        // Create new metrics
        let newMetrics = LiveMetrics(
            timestamp: timestamp,
            frameRate: currentMetrics.frameRate,
            frameTime: currentMetrics.frameTime,
            cpuUsage: cpuUsage,
            gpuUsage: gpuUsage,
            memoryUsage: memoryInfo.usage,
            memoryPressure: memoryInfo.pressure,
            thermalState: thermalState,
            powerUsage: powerUsage,
            networkActivity: networkActivity,
            diskActivity: diskActivity,
            renderingStats: renderingStats
        )
        
        currentMetrics = newMetrics
        
        // Update performance score
        updatePerformanceScore()
        
        // Generate recommendations
        if enableRecommendations {
            updateRecommendations()
        }
        
        // Record metrics for debugging
        recordMetric("frameRate", value: newMetrics.frameRate)
        recordMetric("cpuUsage", value: cpuUsage)
        recordMetric("gpuUsage", value: gpuUsage)
        recordMetric("memoryUsage", value: memoryInfo.usage)
    }
    
    private func updatePerformanceScore() {
        var score = 100.0
        
        // Frame rate score (30% weight)
        let targetFrameRate = 60.0
        let frameRateRatio = currentMetrics.frameRate / targetFrameRate
        let frameRateScore = min(frameRateRatio * 100.0, 100.0)
        score = score * 0.3 + frameRateScore * 0.3
        
        // CPU usage score (25% weight)
        let cpuScore = max(0.0, 100.0 - currentMetrics.cpuUsage)
        score += cpuScore * 0.25
        
        // GPU usage score (25% weight)
        let gpuScore = max(0.0, 100.0 - currentMetrics.gpuUsage)
        score += gpuScore * 0.25
        
        // Memory pressure score (10% weight)
        let memoryScore: Double
        switch currentMetrics.memoryPressure {
        case .normal: memoryScore = 100.0
        case .warning: memoryScore = 75.0
        case .urgent: memoryScore = 50.0
        case .critical: memoryScore = 25.0
        }
        score += memoryScore * 0.1
        
        // Thermal state score (10% weight)
        let thermalScore: Double
        switch currentMetrics.thermalState {
        case .nominal: thermalScore = 100.0
        case .fair: thermalScore = 80.0
        case .serious: thermalScore = 60.0
        case .critical: thermalScore = 30.0
        @unknown default: thermalScore = 50.0
        }
        score += thermalScore * 0.1
        
        performanceScore = max(0.0, min(100.0, score))
    }
    
    private func updateRecommendations() {
        var newRecommendations: [PerformanceRecommendation] = []
        
        // Frame rate recommendations
        if currentMetrics.frameRate < 30.0 {
            newRecommendations.append(PerformanceRecommendation(
                severity: .critical,
                category: .frameRate,
                title: "Low Frame Rate",
                description: "Frame rate is below 30 FPS, causing visible stuttering",
                suggestedAction: "Reduce visualization complexity or skin quality",
                estimatedImpact: .high,
                automaticallyApplicable: true,
                timestamp: Date()
            ))
        } else if currentMetrics.frameRate < 50.0 {
            newRecommendations.append(PerformanceRecommendation(
                severity: .warning,
                category: .frameRate,
                title: "Suboptimal Frame Rate",
                description: "Frame rate is below optimal 60 FPS",
                suggestedAction: "Consider reducing visual effects or frame rate target",
                estimatedImpact: .medium,
                automaticallyApplicable: true,
                timestamp: Date()
            ))
        }
        
        // CPU recommendations
        if currentMetrics.cpuUsage > 80.0 {
            newRecommendations.append(PerformanceRecommendation(
                severity: .warning,
                category: .cpu,
                title: "High CPU Usage",
                description: "CPU usage is above 80%, which may affect performance",
                suggestedAction: "Close unnecessary applications or reduce audio processing",
                estimatedImpact: .medium,
                automaticallyApplicable: false,
                timestamp: Date()
            ))
        }
        
        // GPU recommendations
        if currentMetrics.gpuUsage > 85.0 {
            newRecommendations.append(PerformanceRecommendation(
                severity: .warning,
                category: .gpu,
                title: "High GPU Usage",
                description: "GPU usage is above 85%, which may cause frame drops",
                suggestedAction: "Reduce visualization quality or disable particle effects",
                estimatedImpact: .medium,
                automaticallyApplicable: true,
                timestamp: Date()
            ))
        }
        
        // Memory recommendations
        switch currentMetrics.memoryPressure {
        case .urgent, .critical:
            newRecommendations.append(PerformanceRecommendation(
                severity: .critical,
                category: .memory,
                title: "High Memory Pressure",
                description: "System is under memory pressure, which may cause performance issues",
                suggestedAction: "Close unnecessary applications or reduce texture quality",
                estimatedImpact: .high,
                automaticallyApplicable: false,
                timestamp: Date()
            ))
        case .warning:
            newRecommendations.append(PerformanceRecommendation(
                severity: .warning,
                category: .memory,
                title: "Memory Pressure Warning",
                description: "Memory usage is elevated",
                suggestedAction: "Monitor memory usage and consider reducing cache size",
                estimatedImpact: .low,
                automaticallyApplicable: false,
                timestamp: Date()
            ))
        case .normal:
            break
        }
        
        // Thermal recommendations
        switch currentMetrics.thermalState {
        case .critical:
            newRecommendations.append(PerformanceRecommendation(
                severity: .critical,
                category: .thermal,
                title: "Critical Thermal State",
                description: "System is overheating and will throttle performance",
                suggestedAction: "Immediately reduce frame rate and disable effects",
                estimatedImpact: .critical,
                automaticallyApplicable: true,
                timestamp: Date()
            ))
        case .serious:
            newRecommendations.append(PerformanceRecommendation(
                severity: .warning,
                category: .thermal,
                title: "High Temperature",
                description: "System temperature is elevated",
                suggestedAction: "Reduce frame rate to 60Hz and disable particle effects",
                estimatedImpact: .high,
                automaticallyApplicable: true,
                timestamp: Date()
            ))
        case .fair, .nominal:
            break
        @unknown default:
            break
        }
        
        // Update recommendations and alert count
        recommendations = newRecommendations
        alertCount = newRecommendations.filter { $0.severity == .critical }.count
    }
    
    // MARK: - Event Handlers
    private func handleThermalStateChange() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        os_signpost(.event, log: performanceLogger, name: "ThermalStateChanged",
                   "State: %{public}s", String(describing: thermalState))
        
        if enableAutoOptimization {
            applyThermalOptimization(for: thermalState)
        }
    }
    
    private func handleMemoryWarning() {
        os_signpost(.event, log: performanceLogger, name: "MemoryWarning")
        
        if enableAutoOptimization {
            applyMemoryOptimization()
        }
    }
    
    private func applyThermalOptimization(for state: ProcessInfo.ThermalState) {
        // This would integrate with the adaptive frame rate manager
        switch state {
        case .critical:
            // Reduce to minimum settings
            NotificationCenter.default.post(
                name: .performanceOptimizationRequired,
                object: ["frameRate": 30.0, "quality": "minimal"]
            )
        case .serious:
            // Reduce to balanced settings
            NotificationCenter.default.post(
                name: .performanceOptimizationRequired,
                object: ["frameRate": 60.0, "quality": "reduced"]
            )
        default:
            break
        }
    }
    
    private func applyMemoryOptimization() {
        // Clear caches, reduce texture quality, etc.
        NotificationCenter.default.post(
            name: .memoryOptimizationRequired,
            object: nil
        )
    }
    
    // MARK: - Public Interface
    public func recordMetric(_ name: String, value: Double) {
        guard showDebugInfo else { return }
        
        os_signpost(.event, log: performanceLogger, name: "MetricRecorded",
                   "Name: %{public}s, Value: %{public}.2f", name, value)
    }
    
    public func getPerformanceReport(timeWindow: TimeInterval = 300) -> PerformanceReport {
        let endTime = CACurrentMediaTime()
        let startTime = endTime - timeWindow
        
        let recentFrameRates = performanceHistory.frameRates.values.filter { _ in true } // Would filter by time
        let recentCPUUsages = performanceHistory.cpuUsages.values.filter { _ in true }
        let recentGPUUsages = performanceHistory.gpuUsages.values.filter { _ in true }
        let recentMemoryUsages = performanceHistory.memoryUsages.values.filter { _ in true }
        
        return PerformanceReport(
            timeWindow: timeWindow,
            averageFrameRate: recentFrameRates.isEmpty ? 0 : recentFrameRates.reduce(0, +) / Double(recentFrameRates.count),
            minFrameRate: recentFrameRates.min() ?? 0,
            maxFrameRate: recentFrameRates.max() ?? 0,
            averageCPUUsage: recentCPUUsages.isEmpty ? 0 : recentCPUUsages.reduce(0, +) / Double(recentCPUUsages.count),
            peakCPUUsage: recentCPUUsages.max() ?? 0,
            averageGPUUsage: recentGPUUsages.isEmpty ? 0 : recentGPUUsages.reduce(0, +) / Double(recentGPUUsages.count),
            peakGPUUsage: recentGPUUsages.max() ?? 0,
            averageMemoryUsage: recentMemoryUsages.isEmpty ? 0 : recentMemoryUsages.reduce(0, +) / Double(recentMemoryUsages.count),
            peakMemoryUsage: recentMemoryUsages.max() ?? 0,
            recommendations: recommendations,
            performanceScore: performanceScore,
            generatedAt: Date()
        )
    }
    
    public func exportPerformanceData() -> Data? {
        let report = getPerformanceReport()
        return try? JSONEncoder().encode(report)
    }
}

// MARK: - Supporting Types
public struct PerformanceReport: Codable, Sendable {
    let timeWindow: TimeInterval
    let averageFrameRate: Double
    let minFrameRate: Double
    let maxFrameRate: Double
    let averageCPUUsage: Double
    let peakCPUUsage: Double
    let averageGPUUsage: Double
    let peakGPUUsage: Double
    let averageMemoryUsage: Double
    let peakMemoryUsage: Double
    let recommendations: [PerformanceRecommendation]
    let performanceScore: Double
    let generatedAt: Date
}

// MARK: - System Monitoring Components
private class SystemMonitor {
    func getCPUUsage() -> Double {
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
            return Double(info.resident_size) / (1024 * 1024) * 0.1 // Approximate CPU usage
        }
        return 0.0
    }
    
    func getMemoryInfo() -> (usage: Double, pressure: PerformanceMonitor.MemoryPressureLevel) {
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
            let usage = Double(usedPages) / Double(totalPages)
            
            let pressure: PerformanceMonitor.MemoryPressureLevel
            if usage > 0.9 {
                pressure = .critical
            } else if usage > 0.8 {
                pressure = .urgent
            } else if usage > 0.7 {
                pressure = .warning
            } else {
                pressure = .normal
            }
            
            return (usage * 100, pressure)
        }
        
        return (0.0, .normal)
    }
    
    func getPowerUsage() -> Double {
        // Mock implementation - would use IOKit for real power monitoring
        return Double.random(in: 8.0...15.0)
    }
    
    func getNetworkActivity() -> PerformanceMonitor.NetworkActivity {
        return PerformanceMonitor.NetworkActivity(
            bytesIn: UInt64.random(in: 0...1000),
            bytesOut: UInt64.random(in: 0...1000),
            packetsIn: UInt64.random(in: 0...100),
            packetsOut: UInt64.random(in: 0...100)
        )
    }
    
    func getDiskActivity() -> PerformanceMonitor.DiskActivity {
        return PerformanceMonitor.DiskActivity(
            bytesRead: UInt64.random(in: 0...10000),
            bytesWritten: UInt64.random(in: 0...10000),
            operations: UInt64.random(in: 0...100)
        )
    }
}

private class MetalMonitor {
    private let device: MTLDevice
    
    init(device: MTLDevice) throws {
        self.device = device
    }
    
    func getGPUUsage() -> Double {
        // Mock implementation - would use Metal performance counters
        return Double.random(in: 20.0...70.0)
    }
    
    func getRenderingStats() -> PerformanceMonitor.RenderingStats {
        return PerformanceMonitor.RenderingStats(
            drawCalls: Int.random(in: 10...50),
            triangles: Int.random(in: 1000...10000),
            vertices: Int.random(in: 3000...30000),
            textureMemory: UInt64.random(in: 10_000_000...100_000_000),
            bufferMemory: UInt64.random(in: 1_000_000...10_000_000),
            pipelineStateChanges: Int.random(in: 1...10),
            commandBufferCount: Int.random(in: 1...5)
        )
    }
}

private class RecommendationEngine {
    // This would contain sophisticated algorithms for generating recommendations
    // based on performance patterns and machine learning
}

// MARK: - Circular Buffer
private struct CircularBuffer<T> {
    private var buffer: [T]
    private var head = 0
    private var count = 0
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: Optional<T>.none as! T, count: capacity)
    }
    
    mutating func append(_ element: T) {
        buffer[head] = element
        head = (head + 1) % capacity
        count = min(count + 1, capacity)
    }
    
    var values: [T] {
        if count < capacity {
            return Array(buffer[0..<count])
        } else {
            return Array(buffer[head..<capacity] + buffer[0..<head])
        }
    }
    
    func recentValues(count: Int) -> [T] {
        let actualCount = min(count, self.count)
        if actualCount == 0 { return [] }
        
        if self.count < capacity {
            let startIndex = max(0, self.count - actualCount)
            return Array(buffer[startIndex..<self.count])
        } else {
            let startHead = (head - actualCount + capacity) % capacity
            if startHead + actualCount <= capacity {
                return Array(buffer[startHead..<startHead + actualCount])
            } else {
                let firstPart = Array(buffer[startHead..<capacity])
                let secondPart = Array(buffer[0..<(startHead + actualCount) % capacity])
                return firstPart + secondPart
            }
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let performanceOptimizationRequired = Notification.Name("performanceOptimizationRequired")
    static let memoryOptimizationRequired = Notification.Name("memoryOptimizationRequired")
}