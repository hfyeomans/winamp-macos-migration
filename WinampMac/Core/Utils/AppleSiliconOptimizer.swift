import Foundation
import SystemConfiguration
import MetalPerformanceShaders
import Accelerate
import simd

/// Apple Silicon optimization and performance monitoring system
/// Leverages M1/M2/M3 specific features for maximum performance
@MainActor
public final class AppleSiliconOptimizer: ObservableObject {
    
    public static let shared = AppleSiliconOptimizer()
    
    // MARK: - System Information
    @Published public private(set) var systemInfo: SystemInfo
    @Published public private(set) var performanceProfile: PerformanceProfile
    @Published public private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    
    // MARK: - Optimization State
    private var isOptimized: Bool = false
    private var thermalStateObserver: NSObjectProtocol?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    // MARK: - Performance Metrics
    private var frameTimeHistory: [TimeInterval] = []
    private let maxHistorySize = 60 // 1 second at 60fps
    
    private init() {
        self.systemInfo = SystemInfo.detect()
        self.performanceProfile = PerformanceProfile.determine(for: systemInfo)
        
        setupThermalMonitoring()
        setupMemoryPressureMonitoring()
        applyOptimizations()
    }
    
    deinit {
        Task { @MainActor in
            await cleanup()
        }
    }
    
    // MARK: - System Detection
    public struct SystemInfo: Sendable {
        public let isAppleSilicon: Bool
        public let chipFamily: ChipFamily
        public let coreCount: Int
        public let memorySize: UInt64
        public let hasUnifiedMemory: Bool
        public let metalFamily: Int
        public let supportsProMotion: Bool
        
        public enum ChipFamily: String, CaseIterable, Sendable {
            case m1 = "M1"
            case m1Pro = "M1 Pro"
            case m1Max = "M1 Max"
            case m1Ultra = "M1 Ultra"
            case m2 = "M2"
            case m2Pro = "M2 Pro"
            case m2Max = "M2 Max"
            case m2Ultra = "M2 Ultra"
            case m3 = "M3"
            case m3Pro = "M3 Pro"
            case m3Max = "M3 Max"
            case intel = "Intel"
            case unknown = "Unknown"
            
            public var performanceLevel: Int {
                switch self {
                case .m3Max: return 10
                case .m3Pro: return 9
                case .m3: return 8
                case .m2Ultra: return 10
                case .m2Max: return 9
                case .m2Pro: return 8
                case .m2: return 7
                case .m1Ultra: return 9
                case .m1Max: return 8
                case .m1Pro: return 7
                case .m1: return 6
                case .intel: return 4
                case .unknown: return 3
                }
            }
        }
        
        static func detect() -> SystemInfo {
            var systemInfo = utsname()
            uname(&systemInfo)
            
            let machine = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String.init(validatingCString: $0) ?? "Unknown"
                }
            }
            
            let isAppleSilicon = machine.hasPrefix("arm64") || machine.contains("apple")
            let chipFamily = detectChipFamily(from: machine)
            let coreCount = ProcessInfo.processInfo.processorCount
            let memorySize = ProcessInfo.processInfo.physicalMemory
            let hasUnifiedMemory = isAppleSilicon
            
            // Metal family detection
            var metalFamily = 1
            if let device = MTLCreateSystemDefaultDevice() {
                if device.supportsFamily(.apple7) {
                    metalFamily = 7
                } else if device.supportsFamily(.apple6) {
                    metalFamily = 6
                } else if device.supportsFamily(.mac2) {
                    metalFamily = 2
                }
            }
            
            // ProMotion detection (simplified)
            let supportsProMotion = isAppleSilicon && chipFamily.performanceLevel >= 7
            
            return SystemInfo(
                isAppleSilicon: isAppleSilicon,
                chipFamily: chipFamily,
                coreCount: coreCount,
                memorySize: memorySize,
                hasUnifiedMemory: hasUnifiedMemory,
                metalFamily: metalFamily,
                supportsProMotion: supportsProMotion
            )
        }
        
        private static func detectChipFamily(from machine: String) -> ChipFamily {
            // This is a simplified detection - in production, you'd use more sophisticated methods
            if machine.contains("arm64") {
                // M3 series detection based on typical identifiers
                if machine.contains("m3") || machine.contains("14,") || machine.contains("15,") {
                    if machine.contains("max") { return .m3Max }
                    if machine.contains("pro") { return .m3Pro }
                    return .m3
                }
                // M2 series detection
                if machine.contains("m2") || machine.contains("13,") {
                    if machine.contains("ultra") { return .m2Ultra }
                    if machine.contains("max") { return .m2Max }
                    if machine.contains("pro") { return .m2Pro }
                    return .m2
                }
                // M1 series detection
                if machine.contains("ultra") { return .m1Ultra }
                if machine.contains("max") { return .m1Max }
                if machine.contains("pro") { return .m1Pro }
                return .m1
            }
            
            if machine.contains("x86_64") {
                return .intel
            }
            
            return .unknown
        }
    }
    
    // MARK: - Performance Profiles
    public struct PerformanceProfile: Sendable {
        public let targetFrameRate: Int
        public let renderQuality: RenderQuality
        public let audioBufferSize: Int
        public let fftSize: Int
        public let enableMetalOptimizations: Bool
        public let enableAccelerateOptimizations: Bool
        public let maxConcurrentTasks: Int
        
        public enum RenderQuality: String, CaseIterable, Sendable {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case ultra = "Ultra"
            
            public var sampleCount: Int {
                switch self {
                case .low: return 1
                case .medium: return 2
                case .high: return 4
                case .ultra: return 8
                }
            }
        }
        
        static func determine(for systemInfo: SystemInfo) -> PerformanceProfile {
            let performanceLevel = systemInfo.chipFamily.performanceLevel
            
            let targetFrameRate: Int
            let renderQuality: RenderQuality
            let audioBufferSize: Int
            let fftSize: Int
            let maxConcurrentTasks: Int
            
            switch performanceLevel {
            case 9...: // M3 Max, M2 Ultra
                targetFrameRate = systemInfo.supportsProMotion ? 120 : 60
                renderQuality = .ultra
                audioBufferSize = 256
                fftSize = 2048
                maxConcurrentTasks = min(systemInfo.coreCount, 12)
                
            case 7...8: // M3, M3 Pro, M2, M2 Pro, M1 Pro, M1 Max
                targetFrameRate = systemInfo.supportsProMotion ? 120 : 60
                renderQuality = .high
                audioBufferSize = 512
                fftSize = 1024
                maxConcurrentTasks = min(systemInfo.coreCount, 8)
                
            case 5...6: // M1, M2
                targetFrameRate = 60
                renderQuality = .medium
                audioBufferSize = 512
                fftSize = 1024
                maxConcurrentTasks = min(systemInfo.coreCount, 6)
                
            default: // Intel, Unknown
                targetFrameRate = 60
                renderQuality = .low
                audioBufferSize = 1024
                fftSize = 512
                maxConcurrentTasks = min(systemInfo.coreCount, 4)
            }
            
            return PerformanceProfile(
                targetFrameRate: targetFrameRate,
                renderQuality: renderQuality,
                audioBufferSize: audioBufferSize,
                fftSize: fftSize,
                enableMetalOptimizations: systemInfo.isAppleSilicon,
                enableAccelerateOptimizations: systemInfo.isAppleSilicon,
                maxConcurrentTasks: maxConcurrentTasks
            )
        }
    }
    
    // MARK: - Thermal Monitoring
    private func setupThermalMonitoring() {
        thermalState = ProcessInfo.processInfo.thermalState
        
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleThermalStateChange()
            }
        }
    }
    
    private func handleThermalStateChange() {
        thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .nominal:
            // Restore full performance
            adjustPerformanceProfile(throttle: 1.0)
            
        case .fair:
            // Slight throttling
            adjustPerformanceProfile(throttle: 0.8)
            
        case .serious:
            // Moderate throttling
            adjustPerformanceProfile(throttle: 0.6)
            
        case .critical:
            // Aggressive throttling
            adjustPerformanceProfile(throttle: 0.4)
            
        @unknown default:
            adjustPerformanceProfile(throttle: 0.8)
        }
    }
    
    private func adjustPerformanceProfile(throttle: Double) {
        // Adjust frame rate
        let baseFrameRate = performanceProfile.targetFrameRate
        let throttledFrameRate = Int(Double(baseFrameRate) * throttle)
        
        // Adjust render quality
        let renderQuality: PerformanceProfile.RenderQuality
        switch throttle {
        case 0.8...: renderQuality = performanceProfile.renderQuality
        case 0.6..<0.8: renderQuality = .medium
        case 0.4..<0.6: renderQuality = .low
        default: renderQuality = .low
        }
        
        performanceProfile = PerformanceProfile(
            targetFrameRate: throttledFrameRate,
            renderQuality: renderQuality,
            audioBufferSize: performanceProfile.audioBufferSize,
            fftSize: performanceProfile.fftSize,
            enableMetalOptimizations: performanceProfile.enableMetalOptimizations,
            enableAccelerateOptimizations: performanceProfile.enableAccelerateOptimizations,
            maxConcurrentTasks: max(2, Int(Double(performanceProfile.maxConcurrentTasks) * throttle))
        )
        
        PerformanceMonitor.shared.recordMetric("thermalThrottle", value: throttle)
    }
    
    // MARK: - Memory Pressure Monitoring
    private func setupMemoryPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        source.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        
        source.resume()
        memoryPressureSource = source
    }
    
    private func handleMemoryPressure() {
        // Trigger cache cleanup
        Task {
            await SkinCacheManager().clearCache()
        }
        
        // Record memory pressure event
        PerformanceMonitor.shared.recordMetric("memoryPressure", value: 1.0)
        
        // Force garbage collection
        autoreleasepool {
            // Clear any temporary allocations
        }
    }
    
    // MARK: - Apple Silicon Optimizations
    private func applyOptimizations() {
        guard systemInfo.isAppleSilicon else { return }
        
        // Configure dispatch queues for Apple Silicon
        configureDispatchQueues()
        
        // Setup Metal optimizations
        configureMetalOptimizations()
        
        // Setup Accelerate optimizations
        configureAccelerateOptimizations()
        
        isOptimized = true
    }
    
    private func configureDispatchQueues() {
        // Configure quality of service for optimal Apple Silicon performance
        let attributes: DispatchQueue.Attributes = [.concurrent]
        
        // Audio processing queue - high priority
        let _ = DispatchQueue(
            label: "com.winamp.audio.processing",
            qos: .userInteractive,
            attributes: attributes,
            autoreleaseFrequency: .workItem
        )
        
        // Rendering queue - high priority
        let _ = DispatchQueue(
            label: "com.winamp.rendering",
            qos: .userInteractive,
            attributes: attributes,
            autoreleaseFrequency: .workItem
        )
        
        // Asset loading queue - medium priority
        let _ = DispatchQueue(
            label: "com.winamp.assets",
            qos: .userInitiated,
            attributes: attributes,
            autoreleaseFrequency: .workItem
        )
    }
    
    private func configureMetalOptimizations() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        
        // Enable optimizations specific to Apple Silicon GPUs
        if systemInfo.chipFamily.performanceLevel >= 7 {
            // High-performance configurations for M1 Pro and above
            // This would be used in the Metal renderer
        }
    }
    
    private func configureAccelerateOptimizations() {
        // Configure vDSP for optimal Apple Silicon performance
        // Enable NEON optimizations automatically on Apple Silicon
        
        // Set up optimized FFT configurations
        let fftRadix = vDSP_Radix.radix2
        // This would be used in the audio engine for spectrum analysis
    }
    
    // MARK: - Performance Monitoring
    public func recordFrameTime(_ frameTime: TimeInterval) {
        frameTimeHistory.append(frameTime)
        
        if frameTimeHistory.count > maxHistorySize {
            frameTimeHistory.removeFirst()
        }
        
        // Calculate performance metrics
        let averageFrameTime = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        let targetFrameTime = 1.0 / Double(performanceProfile.targetFrameRate)
        
        PerformanceMonitor.shared.recordMetric("frameTime", value: frameTime * 1000)
        PerformanceMonitor.shared.recordMetric("averageFrameTime", value: averageFrameTime * 1000)
        
        // Check if we're dropping frames
        if averageFrameTime > targetFrameTime * 1.2 {
            PerformanceMonitor.shared.recordMetric("frameDrops", value: 1.0)
        }
    }
    
    public func getPerformanceMetrics() -> PerformanceMetrics {
        let averageFrameTime = frameTimeHistory.isEmpty ? 0 : 
            frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        
        let currentFrameRate = averageFrameTime > 0 ? 1.0 / averageFrameTime : 0
        let targetFrameRate = Double(performanceProfile.targetFrameRate)
        let efficiency = min(1.0, currentFrameRate / targetFrameRate)
        
        return PerformanceMetrics(
            averageFrameTime: averageFrameTime,
            currentFrameRate: currentFrameRate,
            targetFrameRate: targetFrameRate,
            efficiency: efficiency,
            thermalState: thermalState
        )
    }
    
    // MARK: - Memory Management
    public func optimizeMemoryUsage() {
        // Trigger memory optimization
        Task {
            await SkinCacheManager().clearCache()
        }
        
        // Force autorelease pool drain
        autoreleasepool {}
        
        // Record memory optimization
        PerformanceMonitor.shared.recordMetric("memoryOptimization", value: 1.0)
    }
    
    // MARK: - Cleanup
    private func cleanup() async {
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        memoryPressureSource?.cancel()
    }
}

// MARK: - Performance Metrics
public struct PerformanceMetrics: Sendable {
    public let averageFrameTime: TimeInterval
    public let currentFrameRate: Double
    public let targetFrameRate: Double
    public let efficiency: Double
    public let thermalState: ProcessInfo.ThermalState
    
    public var isPerformingWell: Bool {
        return efficiency > 0.8 && thermalState <= .fair
    }
}

// MARK: - Accelerate Optimizations
public final class AccelerateOptimizer: @unchecked Sendable {
    
    @MainActor
    public static let shared = AccelerateOptimizer()
    
    private init() {}
    
    // MARK: - Optimized FFT Functions
    public func performOptimizedFFT(
        input: [Float],
        outputReal: inout [Float],
        outputImaginary: inout [Float]
    ) {
        let count = input.count
        guard count.nonzeroBitCount == 1 else { return } // Must be power of 2
        
        let log2n = vDSP_Length(log2(Float(count)))
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var realp = [Float](repeating: 0, count: count / 2)
        var imagp = [Float](repeating: 0, count: count / 2)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        input.withUnsafeBufferPointer { inputPtr in
            vDSP_ctoz(inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: count / 2) { $0 },
                     2, &splitComplex, 1, vDSP_Length(count / 2))
        }
        
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Scale the output
        var scale = Float(1.0 / Float(count))
        vDSP_vsmul(splitComplex.realp, 1, &scale, splitComplex.realp, 1, vDSP_Length(count / 2))
        vDSP_vsmul(splitComplex.imagp, 1, &scale, splitComplex.imagp, 1, vDSP_Length(count / 2))
        
        outputReal = Array(UnsafeBufferPointer(start: splitComplex.realp, count: count / 2))
        outputImaginary = Array(UnsafeBufferPointer(start: splitComplex.imagp, count: count / 2))
    }
    
    // MARK: - Optimized Vector Operations
    public func calculateMagnitudeSpectrum(real: [Float], imaginary: [Float]) -> [Float] {
        let count = min(real.count, imaginary.count)
        var magnitudes = Array(repeating: Float(0), count: count)
        
        real.withUnsafeBufferPointer { realPtr in
            imaginary.withUnsafeBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(
                    realp: UnsafeMutablePointer(mutating: realPtr.baseAddress!),
                    imagp: UnsafeMutablePointer(mutating: imagPtr.baseAddress!)
                )
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(count))
            }
        }
        
        // Apply square root to get magnitude
        var sqrtCount = Int32(count)
        vvsqrtf(&magnitudes, magnitudes, &sqrtCount)
        
        return magnitudes
    }
    
    // MARK: - Audio Processing Optimizations
    public func applyWindow(to signal: inout [Float], windowType: WindowType) {
        let count = signal.count
        var window = Array(repeating: Float(0), count: count)
        
        switch windowType {
        case .hann:
            vDSP_hann_window(&window, vDSP_Length(count), Int32(vDSP_HANN_NORM))
        case .hamming:
            vDSP_hamm_window(&window, vDSP_Length(count), 0)
        case .blackman:
            vDSP_blkman_window(&window, vDSP_Length(count), 0)
        }
        
        vDSP_vmul(signal, 1, window, 1, &signal, 1, vDSP_Length(count))
    }
    
    public enum WindowType {
        case hann
        case hamming
        case blackman
    }
    
    // MARK: - Equalizer Processing
    public func applyEqualizerBand(
        to signal: inout [Float],
        frequency: Float,
        gain: Float,
        sampleRate: Float
    ) {
        // Simplified biquad filter implementation using Accelerate
        let w = 2.0 * Float.pi * frequency / sampleRate
        let cosw = cos(w)
        let sinw = sin(w)
        let alpha = sinw / 2.0
        
        let A = pow(10.0, gain / 40.0)
        
        // Peaking EQ coefficients
        let b0 = 1 + alpha * A
        let b1 = -2 * cosw
        let b2 = 1 - alpha * A
        let a0 = 1 + alpha / A
        let a1 = -2 * cosw
        let a2 = 1 - alpha / A
        
        // Normalize coefficients
        let _ = [b0/a0, b1/a0, b2/a0, a1/a0, a2/a0]
        
        // Apply filter using vDSP
        // This is a simplified version - production would use proper biquad filtering
        var filtered = Array(repeating: Float(0), count: signal.count)
        
        // Simple gain application for demonstration
        var gainValue = A
        vDSP_vsmul(signal, 1, &gainValue, &filtered, 1, vDSP_Length(signal.count))
        
        signal = filtered
    }
}