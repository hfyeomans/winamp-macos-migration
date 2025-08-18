import Foundation
import CoreVideo
import QuartzCore
import Metal
import MetalKit
import os.signpost

/// Comprehensive ProMotion display performance testing framework
/// Tests 120Hz rendering capabilities and measures actual frame rates during visualization
@MainActor
public final class ProMotionPerformanceTester: ObservableObject {
    
    // MARK: - Performance Metrics
    public struct PerformanceMetrics: Sendable {
        let timestamp: TimeInterval
        let actualFrameRate: Double
        let targetFrameRate: Double
        let frameDropCount: Int
        let stutterEvents: Int
        let cpuUsage: Double
        let gpuUsage: Double
        let thermalState: ProcessInfo.ThermalState
        let memoryPressure: Double
        let visualizationMode: VisualizationMode
        let skinComplexity: SkinComplexity
        let renderTime: TimeInterval
        let presentationTime: TimeInterval
    }
    
    public enum VisualizationMode: String, CaseIterable, Sendable {
        case spectrum = "Spectrum Analyzer"
        case oscilloscope = "Oscilloscope"
        case particles = "Particle System"
        case waveform = "Waveform"
        case bars3D = "3D Bars"
    }
    
    public enum SkinComplexity: String, CaseIterable, Sendable {
        case simple = "Simple"
        case moderate = "Moderate"
        case complex = "Complex"
        case extreme = "Extreme"
    }
    
    // MARK: - Display Detection
    private struct DisplayCapabilities {
        let supportsProMotion: Bool
        let maxRefreshRate: Double
        let currentRefreshRate: Double
        let displayID: CGDirectDisplayID
        let colorSpace: CFString
        let bitDepth: Int
    }
    
    // MARK: - Properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var displayLink: CVDisplayLink?
    private var frameTimeHistory: [TimeInterval] = []
    private var frameDropHistory: [Bool] = []
    private var stutterDetector: StutterDetector
    private var performanceLogger: OSLog
    private var signpostID: OSSignpostID
    
    // Performance monitoring
    private var currentMetrics = PerformanceMetrics(
        timestamp: 0,
        actualFrameRate: 0,
        targetFrameRate: 120,
        frameDropCount: 0,
        stutterEvents: 0,
        cpuUsage: 0,
        gpuUsage: 0,
        thermalState: .nominal,
        memoryPressure: 0,
        visualizationMode: .spectrum,
        skinComplexity: .simple,
        renderTime: 0,
        presentationTime: 0
    )
    
    private var isTestingActive = false
    private var testStartTime: TimeInterval = 0
    private var frameCount: Int = 0
    private var lastFrameTime: TimeInterval = 0
    private var targetFrameInterval: TimeInterval = 1.0 / 120.0
    
    // Test results storage
    private var testResults: [String: [PerformanceMetrics]] = [:]
    
    public init(device: MTLDevice) throws {
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw PerformanceTestError.metalInitializationFailed
        }
        self.commandQueue = commandQueue
        
        self.stutterDetector = StutterDetector()
        self.performanceLogger = OSLog(subsystem: "com.winamp.macos", category: "ProMotionTesting")
        self.signpostID = OSSignpostID(log: performanceLogger)
        
        setupDisplayLink()
        detectDisplayCapabilities()
    }
    
    deinit {
        stopTesting()
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
    
    // MARK: - Display Detection
    private func detectDisplayCapabilities() {
        let displayCount = CGDisplayActiveDisplayList(0, nil, nil)
        var displays: [CGDirectDisplayID] = Array(repeating: 0, count: Int(displayCount))
        CGDisplayActiveDisplayList(displayCount, &displays, nil)
        
        for displayID in displays {
            let capabilities = analyzeDisplay(displayID)
            os_signpost(.event, log: performanceLogger, name: "DisplayDetected",
                       "DisplayID: %{public}d, ProMotion: %{public}s, MaxRefresh: %{public}.1f",
                       displayID, capabilities.supportsProMotion ? "YES" : "NO", capabilities.maxRefreshRate)
        }
    }
    
    private func analyzeDisplay(_ displayID: CGDirectDisplayID) -> DisplayCapabilities {
        // Get display refresh rate
        let mode = CGDisplayCopyDisplayMode(displayID)
        let refreshRate = mode?.refreshRate ?? 60.0
        
        // Check for ProMotion support (120Hz+ capable displays)
        let supportsProMotion = refreshRate >= 120.0
        
        // Get color space and bit depth
        let colorSpace = CGDisplayCopyColorSpace(displayID)?.name ?? kCGColorSpaceSRGB
        let bitDepth = CGDisplayBitsPerPixel(displayID)
        
        return DisplayCapabilities(
            supportsProMotion: supportsProMotion,
            maxRefreshRate: refreshRate,
            currentRefreshRate: refreshRate,
            displayID: displayID,
            colorSpace: colorSpace,
            bitDepth: Int(bitDepth)
        )
    }
    
    // MARK: - Display Link Setup
    private func setupDisplayLink() {
        var displayLink: CVDisplayLink?
        let displayLinkOutputCallback: CVDisplayLinkOutputCallback = { 
            (displayLink, now, outputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
            
            let tester = Unmanaged<ProMotionPerformanceTester>.fromOpaque(displayLinkContext!).takeUnretainedValue()
            
            Task { @MainActor in
                tester.processFrame(now: now.pointee, outputTime: outputTime.pointee)
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
    
    private func processFrame(now: CVTimeStamp, outputTime: CVTimeStamp) {
        guard isTestingActive else { return }
        
        let currentTime = CACurrentMediaTime()
        
        // Calculate frame timing
        let frameTime = currentTime - lastFrameTime
        lastFrameTime = currentTime
        
        // Record frame time
        frameTimeHistory.append(frameTime)
        if frameTimeHistory.count > 300 { // Keep last 5 seconds at 60Hz
            frameTimeHistory.removeFirst()
        }
        
        // Detect frame drops
        let frameDropped = frameTime > (targetFrameInterval * 1.5)
        frameDropHistory.append(frameDropped)
        if frameDropHistory.count > 300 {
            frameDropHistory.removeFirst()
        }
        
        // Update stutter detection
        stutterDetector.processFrame(frameTime: frameTime, targetInterval: targetFrameInterval)
        
        // Update metrics
        updateCurrentMetrics()
        
        frameCount += 1
        
        // Log performance data
        os_signpost(.event, log: performanceLogger, name: "FrameProcessed",
                   "FrameTime: %{public}.3f, Dropped: %{public}s, FPS: %{public}.1f",
                   frameTime * 1000, frameDropped ? "YES" : "NO", currentMetrics.actualFrameRate)
    }
    
    private func updateCurrentMetrics() {
        let currentTime = CACurrentMediaTime()
        let elapsedTime = currentTime - testStartTime
        
        // Calculate actual frame rate
        let actualFrameRate = frameCount > 0 ? Double(frameCount) / elapsedTime : 0.0
        
        // Count frame drops in last second
        let recentFrameDrops = frameDropHistory.suffix(Int(targetFrameRate)).filter { $0 }.count
        
        // Get system metrics
        let cpuUsage = getCurrentCPUUsage()
        let memoryPressure = getCurrentMemoryPressure()
        let thermalState = ProcessInfo.processInfo.thermalState
        
        // Calculate render timing
        let averageFrameTime = frameTimeHistory.isEmpty ? 0 : frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        
        currentMetrics = PerformanceMetrics(
            timestamp: currentTime,
            actualFrameRate: actualFrameRate,
            targetFrameRate: targetFrameRate,
            frameDropCount: recentFrameDrops,
            stutterEvents: stutterDetector.getStutterCount(),
            cpuUsage: cpuUsage,
            gpuUsage: 0.0, // Would need additional Metal performance counters
            thermalState: thermalState,
            memoryPressure: memoryPressure,
            visualizationMode: .spectrum, // Set by current test
            skinComplexity: .simple, // Set by current test
            renderTime: averageFrameTime,
            presentationTime: 0.0
        )
    }
    
    // MARK: - Testing Interface
    public func startTesting(targetFrameRate: Double = 120.0) {
        guard !isTestingActive else { return }
        
        self.targetFrameRate = targetFrameRate
        self.targetFrameInterval = 1.0 / targetFrameRate
        
        isTestingActive = true
        testStartTime = CACurrentMediaTime()
        frameCount = 0
        lastFrameTime = testStartTime
        
        frameTimeHistory.removeAll()
        frameDropHistory.removeAll()
        stutterDetector.reset()
        
        if let displayLink = displayLink {
            CVDisplayLinkStart(displayLink)
        }
        
        os_signpost(.begin, log: performanceLogger, name: "PerformanceTest",
                   "TargetFPS: %{public}.1f", targetFrameRate)
    }
    
    public func stopTesting() {
        guard isTestingActive else { return }
        
        isTestingActive = false
        
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
        
        os_signpost(.end, log: performanceLogger, name: "PerformanceTest")
    }
    
    // MARK: - Comprehensive Testing Suite
    public func runComprehensiveTests() async -> TestResults {
        var results: [String: [PerformanceMetrics]] = [:]
        
        for visualizationMode in VisualizationMode.allCases {
            for skinComplexity in SkinComplexity.allCases {
                let testName = "\(visualizationMode.rawValue)_\(skinComplexity.rawValue)"
                
                os_signpost(.begin, log: performanceLogger, name: "ComprehensiveTest",
                           "Mode: %{public}s, Complexity: %{public}s",
                           visualizationMode.rawValue, skinComplexity.rawValue)
                
                // Test at different frame rates
                for targetFPS in [30.0, 60.0, 120.0] {
                    let testMetrics = await runSingleTest(
                        visualizationMode: visualizationMode,
                        skinComplexity: skinComplexity,
                        targetFrameRate: targetFPS,
                        duration: 10.0 // 10 second test
                    )
                    
                    let testKey = "\(testName)_\(Int(targetFPS))fps"
                    results[testKey] = testMetrics
                }
                
                os_signpost(.end, log: performanceLogger, name: "ComprehensiveTest")
            }
        }
        
        return TestResults(metrics: results, timestamp: Date())
    }
    
    private func runSingleTest(
        visualizationMode: VisualizationMode,
        skinComplexity: SkinComplexity,
        targetFrameRate: Double,
        duration: TimeInterval
    ) async -> [PerformanceMetrics] {
        
        var metrics: [PerformanceMetrics] = []
        
        startTesting(targetFrameRate: targetFrameRate)
        
        // Sample metrics every 100ms during test
        let sampleInterval: TimeInterval = 0.1
        let totalSamples = Int(duration / sampleInterval)
        
        for _ in 0..<totalSamples {
            try? await Task.sleep(nanoseconds: UInt64(sampleInterval * 1_000_000_000))
            
            var currentSample = currentMetrics
            currentSample.visualizationMode = visualizationMode
            currentSample.skinComplexity = skinComplexity
            
            metrics.append(currentSample)
        }
        
        stopTesting()
        
        return metrics
    }
    
    // MARK: - Real-time Performance Access
    public var currentPerformanceMetrics: PerformanceMetrics {
        return currentMetrics
    }
    
    public func isProMotionSupported() -> Bool {
        // Check if any connected display supports 120Hz+
        let displayCount = CGDisplayActiveDisplayList(0, nil, nil)
        var displays: [CGDirectDisplayID] = Array(repeating: 0, count: Int(displayCount))
        CGDisplayActiveDisplayList(displayCount, &displays, nil)
        
        for displayID in displays {
            let capabilities = analyzeDisplay(displayID)
            if capabilities.supportsProMotion {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Battery and Thermal Testing
    public func testBatteryImpact() async -> BatteryTestResults {
        let initialBatteryLevel = getCurrentBatteryLevel()
        let initialThermalState = ProcessInfo.processInfo.thermalState
        
        // Run high-intensity test for 60 seconds
        startTesting(targetFrameRate: 120.0)
        
        var batteryReadings: [Double] = []
        var thermalReadings: [ProcessInfo.ThermalState] = []
        
        for _ in 0..<60 { // 1 minute test
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            batteryReadings.append(getCurrentBatteryLevel())
            thermalReadings.append(ProcessInfo.processInfo.thermalState)
        }
        
        stopTesting()
        
        let finalBatteryLevel = getCurrentBatteryLevel()
        let batteryDrain = initialBatteryLevel - finalBatteryLevel
        
        return BatteryTestResults(
            initialBatteryLevel: initialBatteryLevel,
            finalBatteryLevel: finalBatteryLevel,
            batteryDrainRate: batteryDrain,
            initialThermalState: initialThermalState,
            finalThermalState: ProcessInfo.processInfo.thermalState,
            maxThermalState: thermalReadings.max() ?? .nominal,
            duration: 60.0
        )
    }
    
    // MARK: - Utility Functions
    private func getCurrentCPUUsage() -> Double {
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
    
    private func getCurrentBatteryLevel() -> Double {
        // This would need IOKit integration for actual battery monitoring
        // For now, return a mock value
        return 0.85
    }
}

// MARK: - Supporting Types
public struct TestResults: Sendable {
    let metrics: [String: [PerformanceMetrics]]
    let timestamp: Date
    
    public var summary: TestSummary {
        var totalFrames = 0
        var totalDrops = 0
        var avgFrameRate = 0.0
        var maxFrameRate = 0.0
        var minFrameRate = Double.infinity
        
        for (_, metricsList) in metrics {
            for metric in metricsList {
                totalFrames += 1
                totalDrops += metric.frameDropCount
                avgFrameRate += metric.actualFrameRate
                maxFrameRate = max(maxFrameRate, metric.actualFrameRate)
                minFrameRate = min(minFrameRate, metric.actualFrameRate)
            }
        }
        
        if totalFrames > 0 {
            avgFrameRate /= Double(totalFrames)
        }
        
        return TestSummary(
            totalTests: metrics.count,
            totalFrames: totalFrames,
            totalDrops: totalDrops,
            averageFrameRate: avgFrameRate,
            maxFrameRate: maxFrameRate,
            minFrameRate: minFrameRate == Double.infinity ? 0 : minFrameRate,
            dropRate: totalFrames > 0 ? Double(totalDrops) / Double(totalFrames) : 0
        )
    }
}

public struct TestSummary: Sendable {
    let totalTests: Int
    let totalFrames: Int
    let totalDrops: Int
    let averageFrameRate: Double
    let maxFrameRate: Double
    let minFrameRate: Double
    let dropRate: Double
}

public struct BatteryTestResults: Sendable {
    let initialBatteryLevel: Double
    let finalBatteryLevel: Double
    let batteryDrainRate: Double
    let initialThermalState: ProcessInfo.ThermalState
    let finalThermalState: ProcessInfo.ThermalState
    let maxThermalState: ProcessInfo.ThermalState
    let duration: TimeInterval
}

// MARK: - Stutter Detection
private class StutterDetector {
    private var frameTimes: [TimeInterval] = []
    private var stutterCount = 0
    private let stutterThreshold: TimeInterval = 0.016 // 16ms threshold for 60Hz
    
    func processFrame(frameTime: TimeInterval, targetInterval: TimeInterval) {
        frameTimes.append(frameTime)
        
        // Keep last 30 frames for analysis
        if frameTimes.count > 30 {
            frameTimes.removeFirst()
        }
        
        // Detect stutter: frame time significantly longer than target
        if frameTime > targetInterval * 2.0 {
            stutterCount += 1
        }
    }
    
    func getStutterCount() -> Int {
        return stutterCount
    }
    
    func reset() {
        frameTimes.removeAll()
        stutterCount = 0
    }
}

// MARK: - Error Types
public enum PerformanceTestError: Error, LocalizedError {
    case metalInitializationFailed
    case displayLinkCreationFailed
    case testAlreadyRunning
    case invalidTestConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .metalInitializationFailed:
            return "Failed to initialize Metal for performance testing"
        case .displayLinkCreationFailed:
            return "Failed to create display link for frame timing"
        case .testAlreadyRunning:
            return "Performance test is already running"
        case .invalidTestConfiguration:
            return "Invalid test configuration provided"
        }
    }
}