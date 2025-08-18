import Foundation
import Metal
import MetalKit
import Combine
import os.signpost

/// Integration example demonstrating how to use the ProMotion performance framework
/// in a complete Winamp macOS application
@MainActor
public final class PerformanceFrameworkIntegration: ObservableObject {
    
    // MARK: - Performance Components
    private let proMotionTester: ProMotionPerformanceTester
    private let adaptiveFrameRateManager: AdaptiveFrameRateManager
    private let batteryOptimizer: BatteryOptimizer
    private let performanceBenchmark: PerformanceBenchmark
    private let performanceMonitor: PerformanceMonitor
    
    // MARK: - Application State
    @Published public private(set) var isPerformanceOptimized = false
    @Published public private(set) var currentOptimizationLevel: OptimizationLevel = .balanced
    @Published public private(set) var performanceAlerts: [PerformanceAlert] = []
    @Published public private(set) var automaticOptimizationEnabled = true
    
    public enum OptimizationLevel: String, CaseIterable, Sendable {
        case maximum = "Maximum Performance"
        case balanced = "Balanced"
        case powerSaver = "Power Saver"
        case custom = "Custom"
    }
    
    public struct PerformanceAlert: Identifiable, Sendable {
        public let id = UUID()
        let title: String
        let message: String
        let severity: Severity
        let timestamp: Date
        
        public enum Severity: String, CaseIterable, Sendable {
            case info = "Info"
            case warning = "Warning"
            case critical = "Critical"
        }
    }
    
    // MARK: - Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Device and Rendering
    private let device: MTLDevice
    private var metalRenderer: MetalRenderer?
    
    public init(device: MTLDevice) throws {
        self.device = device
        
        // Initialize all performance components
        self.proMotionTester = try ProMotionPerformanceTester(device: device)
        self.adaptiveFrameRateManager = try AdaptiveFrameRateManager(device: device)
        self.batteryOptimizer = try BatteryOptimizer(device: device)
        self.performanceBenchmark = try PerformanceBenchmark(device: device)
        self.performanceMonitor = try PerformanceMonitor(device: device)
        
        setupPerformanceMonitoring()
        configureAutomaticOptimization()
    }
    
    // MARK: - Setup and Configuration
    
    private func setupPerformanceMonitoring() {
        // Start continuous performance monitoring
        performanceMonitor.startMonitoring()
        
        // Monitor performance metrics for automatic optimization
        performanceMonitor.$currentMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.evaluatePerformanceMetrics(metrics)
            }
            .store(in: &cancellables)
        
        // Monitor recommendations
        performanceMonitor.$recommendations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recommendations in
                self?.handlePerformanceRecommendations(recommendations)
            }
            .store(in: &cancellables)
        
        // Monitor adaptive frame rate changes
        adaptiveFrameRateManager.$currentMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.handleFrameRateAdaptation(metrics)
            }
            .store(in: &cancellables)
        
        // Monitor battery optimization recommendations
        batteryOptimizer.$recommendedSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.handleBatteryOptimization(settings)
            }
            .store(in: &cancellables)
    }
    
    private func configureAutomaticOptimization() {
        // Enable automatic optimization by default
        adaptiveFrameRateManager.enableAdaptation(true)
        batteryOptimizer.setPowerMode(.automatic)
        
        // Configure performance thresholds
        performanceMonitor.enableAutoOptimization = true
        performanceMonitor.enableRecommendations = true
    }
    
    // MARK: - Performance Evaluation
    
    private func evaluatePerformanceMetrics(_ metrics: PerformanceMonitor.LiveMetrics) {
        guard automaticOptimizationEnabled else { return }
        
        // Check for performance issues
        var shouldOptimize = false
        var optimizationReason = ""
        
        // Frame rate threshold
        if metrics.frameRate < 30.0 {
            shouldOptimize = true
            optimizationReason = "Low frame rate (\(String(format: "%.1f", metrics.frameRate)) fps)"
        }
        
        // CPU usage threshold
        if metrics.cpuUsage > 80.0 {
            shouldOptimize = true
            optimizationReason += optimizationReason.isEmpty ? "" : ", "
            optimizationReason += "High CPU usage (\(String(format: "%.1f", metrics.cpuUsage))%)"
        }
        
        // GPU usage threshold
        if metrics.gpuUsage > 85.0 {
            shouldOptimize = true
            optimizationReason += optimizationReason.isEmpty ? "" : ", "
            optimizationReason += "High GPU usage (\(String(format: "%.1f", metrics.gpuUsage))%)"
        }
        
        // Memory pressure
        if metrics.memoryPressure == .urgent || metrics.memoryPressure == .critical {
            shouldOptimize = true
            optimizationReason += optimizationReason.isEmpty ? "" : ", "
            optimizationReason += "Memory pressure (\(metrics.memoryPressure.rawValue))"
        }
        
        // Thermal throttling
        if metrics.thermalState == .serious || metrics.thermalState == .critical {
            shouldOptimize = true
            optimizationReason += optimizationReason.isEmpty ? "" : ", "
            optimizationReason += "Thermal throttling (\(metrics.thermalState))"
        }
        
        if shouldOptimize && !isPerformanceOptimized {
            applyAutomaticOptimization(reason: optimizationReason)
        } else if !shouldOptimize && isPerformanceOptimized {
            removeAutomaticOptimization()
        }
    }
    
    private func handlePerformanceRecommendations(_ recommendations: [PerformanceMonitor.PerformanceRecommendation]) {
        for recommendation in recommendations {
            if recommendation.severity == .critical {
                addPerformanceAlert(
                    title: recommendation.title,
                    message: recommendation.description,
                    severity: .critical
                )
                
                // Apply critical recommendations automatically
                if recommendation.automaticallyApplicable && automaticOptimizationEnabled {
                    applyCriticalOptimization(recommendation)
                }
            } else if recommendation.severity == .warning {
                addPerformanceAlert(
                    title: recommendation.title,
                    message: recommendation.suggestedAction,
                    severity: .warning
                )
            }
        }
    }
    
    private func handleFrameRateAdaptation(_ metrics: AdaptiveFrameRateManager.FrameRateMetrics) {
        // Log frame rate adaptations
        if abs(metrics.currentFrameRate - metrics.targetFrameRate) > 5.0 {
            addPerformanceAlert(
                title: "Frame Rate Adapted",
                message: "Frame rate changed to \(String(format: "%.0f", metrics.currentFrameRate)) fps",
                severity: .info
            )
        }
    }
    
    private func handleBatteryOptimization(_ settings: BatteryOptimizer.RenderingSettings) {
        // Apply battery optimization settings to renderer
        if let renderer = metalRenderer {
            applyRenderingSettings(settings, to: renderer)
        }
    }
    
    // MARK: - Optimization Application
    
    private func applyAutomaticOptimization(reason: String) {
        isPerformanceOptimized = true
        
        // Apply power saver mode
        currentOptimizationLevel = .powerSaver
        batteryOptimizer.setPowerMode(.powerSaver)
        adaptiveFrameRateManager.setMode(.powerSaver)
        
        addPerformanceAlert(
            title: "Automatic Optimization Applied",
            message: "Performance optimized due to: \(reason)",
            severity: .info
        )
    }
    
    private func removeAutomaticOptimization() {
        isPerformanceOptimized = false
        
        // Return to balanced mode
        currentOptimizationLevel = .balanced
        batteryOptimizer.setPowerMode(.balanced)
        adaptiveFrameRateManager.setMode(.balanced)
        
        addPerformanceAlert(
            title: "Optimization Removed",
            message: "Performance has improved, returning to normal settings",
            severity: .info
        )
    }
    
    private func applyCriticalOptimization(_ recommendation: PerformanceMonitor.PerformanceRecommendation) {
        switch recommendation.category {
        case .frameRate:
            adaptiveFrameRateManager.setMode(.powerSaver)
        case .thermal:
            batteryOptimizer.setPowerMode(.critical)
        case .memory:
            // Clear caches, reduce texture quality
            NotificationCenter.default.post(name: .memoryOptimizationRequired, object: nil)
        case .gpu:
            // Reduce visualization quality
            setVisualizationQuality(.minimal)
        case .cpu:
            // Reduce audio processing quality
            reduceAudioProcessingQuality()
        default:
            break
        }
    }
    
    private func applyRenderingSettings(_ settings: BatteryOptimizer.RenderingSettings, to renderer: MetalRenderer) {
        // This would integrate with the actual renderer
        // Apply frame rate, quality settings, effects, etc.
    }
    
    // MARK: - Public Interface
    
    public func setOptimizationLevel(_ level: OptimizationLevel) {
        currentOptimizationLevel = level
        
        switch level {
        case .maximum:
            batteryOptimizer.setPowerMode(.maximum)
            adaptiveFrameRateManager.setMode(.performance)
            setVisualizationQuality(.high)
            
        case .balanced:
            batteryOptimizer.setPowerMode(.balanced)
            adaptiveFrameRateManager.setMode(.balanced)
            setVisualizationQuality(.standard)
            
        case .powerSaver:
            batteryOptimizer.setPowerMode(.powerSaver)
            adaptiveFrameRateManager.setMode(.powerSaver)
            setVisualizationQuality(.minimal)
            
        case .custom:
            // Custom settings would be configured separately
            break
        }
        
        addPerformanceAlert(
            title: "Optimization Level Changed",
            message: "Performance level set to \(level.rawValue)",
            severity: .info
        )
    }
    
    public func enableAutomaticOptimization(_ enabled: Bool) {
        automaticOptimizationEnabled = enabled
        
        adaptiveFrameRateManager.enableAdaptation(enabled)
        performanceMonitor.enableAutoOptimization = enabled
        
        if enabled {
            batteryOptimizer.setPowerMode(.automatic)
        }
        
        addPerformanceAlert(
            title: enabled ? "Automatic Optimization Enabled" : "Automatic Optimization Disabled",
            message: enabled ? "Performance will be automatically optimized" : "Manual optimization only",
            severity: .info
        )
    }
    
    public func runPerformanceBenchmark() async -> PerformanceBenchmark.BenchmarkSuite {
        addPerformanceAlert(
            title: "Benchmark Started",
            message: "Running performance benchmark suite",
            severity: .info
        )
        
        let configs = PerformanceBenchmark.quickBenchmarkSuite()
        let suite = await performanceBenchmark.runBenchmarkSuite(configs, name: "User Requested Benchmark")
        
        addPerformanceAlert(
            title: "Benchmark Completed",
            message: "Performance score: \(String(format: "%.1f", suite.overallScore))",
            severity: .info
        )
        
        return suite
    }
    
    public func runComprehensiveTests() async -> ProMotionPerformanceTester.TestResults {
        addPerformanceAlert(
            title: "Comprehensive Testing Started",
            message: "Running ProMotion display tests",
            severity: .info
        )
        
        let results = await proMotionTester.runComprehensiveTests()
        
        addPerformanceAlert(
            title: "Testing Completed",
            message: "Tested \(results.summary.totalTests) scenarios",
            severity: .info
        )
        
        return results
    }
    
    public func exportPerformanceReport() -> Data? {
        return performanceMonitor.exportPerformanceData()
    }
    
    // MARK: - Helper Methods
    
    private func addPerformanceAlert(title: String, message: String, severity: PerformanceAlert.Severity) {
        let alert = PerformanceAlert(
            title: title,
            message: message,
            severity: severity,
            timestamp: Date()
        )
        
        performanceAlerts.append(alert)
        
        // Limit alert history
        if performanceAlerts.count > 50 {
            performanceAlerts.removeFirst()
        }
    }
    
    private func setVisualizationQuality(_ quality: BatteryOptimizer.VisualizationQuality) {
        // This would integrate with the visualization system
        NotificationCenter.default.post(
            name: .visualizationQualityChanged,
            object: quality
        )
    }
    
    private func reduceAudioProcessingQuality() {
        // This would integrate with the audio engine
        NotificationCenter.default.post(
            name: .audioQualityReductionRequired,
            object: nil
        )
    }
    
    // MARK: - Performance Monitoring Interface
    
    public var currentFrameRate: Double {
        return performanceMonitor.currentMetrics.frameRate
    }
    
    public var currentCPUUsage: Double {
        return performanceMonitor.currentMetrics.cpuUsage
    }
    
    public var currentGPUUsage: Double {
        return performanceMonitor.currentMetrics.gpuUsage
    }
    
    public var currentMemoryUsage: Double {
        return performanceMonitor.currentMetrics.memoryUsage
    }
    
    public var performanceScore: Double {
        return performanceMonitor.performanceScore
    }
    
    public var thermalState: ProcessInfo.ThermalState {
        return performanceMonitor.currentMetrics.thermalState
    }
    
    public var batteryLevel: Double {
        return adaptiveFrameRateManager.currentMetrics.batteryLevel
    }
    
    public var isPluggedIn: Bool {
        return adaptiveFrameRateManager.currentMetrics.isPluggedIn
    }
    
    public var estimatedBatteryLife: TimeInterval {
        return batteryOptimizer.estimatedBatteryLife
    }
    
    // MARK: - ProMotion Information
    
    public var supportsProMotion: Bool {
        return proMotionTester.isProMotionSupported()
    }
    
    public var currentDisplayRefreshRate: Double {
        return adaptiveFrameRateManager.currentMetrics.currentFrameRate
    }
    
    public var targetDisplayRefreshRate: Double {
        return adaptiveFrameRateManager.currentMetrics.targetFrameRate
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let visualizationQualityChanged = Notification.Name("visualizationQualityChanged")
    static let audioQualityReductionRequired = Notification.Name("audioQualityReductionRequired")
}

// MARK: - Example Usage

/*
 
 // Example of how to integrate the performance framework in your app:
 
 @MainActor
 class WinampApp: App {
     let device = MTLCreateSystemDefaultDevice()!
     let performanceIntegration: PerformanceFrameworkIntegration
     
     init() {
         performanceIntegration = try! PerformanceFrameworkIntegration(device: device)
         
         // Configure automatic optimization
         performanceIntegration.enableAutomaticOptimization(true)
         
         // Set initial optimization level
         performanceIntegration.setOptimizationLevel(.balanced)
     }
     
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .environmentObject(performanceIntegration)
                 .onAppear {
                     // Run initial performance check
                     Task {
                         let _ = await performanceIntegration.runPerformanceBenchmark()
                     }
                 }
         }
     }
 }
 
 // Example view that displays performance information:
 
 struct PerformanceView: View {
     @EnvironmentObject var performance: PerformanceFrameworkIntegration
     
     var body: some View {
         VStack {
             HStack {
                 Text("FPS: \(String(format: "%.1f", performance.currentFrameRate))")
                 Text("CPU: \(String(format: "%.1f", performance.currentCPUUsage))%")
                 Text("GPU: \(String(format: "%.1f", performance.currentGPUUsage))%")
             }
             
             Text("Performance Score: \(String(format: "%.1f", performance.performanceScore))")
             
             Picker("Optimization Level", selection: $performance.currentOptimizationLevel) {
                 ForEach(PerformanceFrameworkIntegration.OptimizationLevel.allCases, id: \.self) { level in
                     Text(level.rawValue).tag(level)
                 }
             }
             
             Button("Run Benchmark") {
                 Task {
                     let _ = await performance.runPerformanceBenchmark()
                 }
             }
         }
     }
 }
 
 */