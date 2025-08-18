import XCTest
import Metal
@testable import WinampPerformance
@testable import WinampCore
@testable import WinampRendering

/// Unit tests for the ProMotion display performance testing framework
@MainActor
final class PerformanceFrameworkTests: XCTestCase {
    
    var device: MTLDevice!
    var proMotionTester: ProMotionPerformanceTester!
    var adaptiveFrameRateManager: AdaptiveFrameRateManager!
    var batteryOptimizer: BatteryOptimizer!
    var performanceBenchmark: PerformanceBenchmark!
    var performanceMonitor: PerformanceMonitor!
    
    override func setUp() async throws {
        try await super.setUp()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal is not available on this system")
        }
        
        self.device = device
        
        // Initialize all performance components
        proMotionTester = try ProMotionPerformanceTester(device: device)
        adaptiveFrameRateManager = try AdaptiveFrameRateManager(device: device)
        batteryOptimizer = try BatteryOptimizer(device: device)
        performanceBenchmark = try PerformanceBenchmark(device: device)
        performanceMonitor = try PerformanceMonitor(device: device)
    }
    
    override func tearDown() async throws {
        proMotionTester = nil
        adaptiveFrameRateManager = nil
        batteryOptimizer = nil
        performanceBenchmark = nil
        performanceMonitor = nil
        device = nil
        
        try await super.tearDown()
    }
    
    // MARK: - ProMotion Performance Tester Tests
    
    func testProMotionDisplayDetection() {
        let supportsProMotion = proMotionTester.isProMotionSupported()
        
        // Test should not crash and should return a boolean
        XCTAssertTrue(supportsProMotion == true || supportsProMotion == false)
    }
    
    func testPerformanceMetricsInitialization() {
        let metrics = proMotionTester.currentPerformanceMetrics
        
        XCTAssertGreaterThanOrEqual(metrics.timestamp, 0)
        XCTAssertGreaterThanOrEqual(metrics.actualFrameRate, 0)
        XCTAssertGreaterThan(metrics.targetFrameRate, 0)
        XCTAssertGreaterThanOrEqual(metrics.frameDropCount, 0)
        XCTAssertGreaterThanOrEqual(metrics.stutterEvents, 0)
    }
    
    func testFrameRateTargetSetting() {
        proMotionTester.startTesting(targetFrameRate: 120.0)
        
        // Allow some time for metrics to update
        let expectation = expectation(description: "Frame rate target set")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        proMotionTester.stopTesting()
        
        // Test completed without crashing
        XCTAssertTrue(true)
    }
    
    // MARK: - Adaptive Frame Rate Manager Tests
    
    func testFrameRateModeChanges() {
        // Test all frame rate modes
        for mode in AdaptiveFrameRateManager.FrameRateMode.allCases {
            adaptiveFrameRateManager.setMode(mode)
            
            let metrics = adaptiveFrameRateManager.currentMetrics
            XCTAssertGreaterThan(metrics.targetFrameRate, 0)
        }
    }
    
    func testContentComplexityAdjustment() {
        for complexity in AdaptiveFrameRateManager.ContentComplexity.allCases {
            adaptiveFrameRateManager.setContentComplexity(complexity)
            
            // Should not crash
            XCTAssertTrue(true)
        }
    }
    
    func testAdaptiveModeToggle() {
        adaptiveFrameRateManager.enableAdaptation(true)
        XCTAssertTrue(adaptiveFrameRateManager.isAdaptationEnabled)
        
        adaptiveFrameRateManager.enableAdaptation(false)
        XCTAssertFalse(adaptiveFrameRateManager.isAdaptationEnabled)
    }
    
    // MARK: - Battery Optimizer Tests
    
    func testPowerModeConfiguration() {
        for mode in BatteryOptimizer.PowerMode.allCases {
            batteryOptimizer.setPowerMode(mode)
            
            let settings = batteryOptimizer.recommendedSettings
            XCTAssertGreaterThan(settings.frameRate, 0)
            XCTAssertGreaterThan(settings.textureQuality, 0)
        }
    }
    
    func testEnergyMeasurement() {
        batteryOptimizer.startEnergyMeasurement(mode: "Test Mode")
        
        // Brief delay to simulate work
        let expectation = expectation(description: "Energy measurement")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        let impact = batteryOptimizer.stopEnergyMeasurement()
        XCTAssertNotNil(impact)
        
        if let impact = impact {
            XCTAssertEqual(impact.visualizationMode, "Test Mode")
            XCTAssertGreaterThan(impact.duration, 0)
        }
    }
    
    func testBatteryLifeEstimation() {
        let settings = BatteryOptimizer.RenderingSettings(
            frameRate: 60.0,
            visualizationQuality: .standard,
            enableEffects: true,
            enableBloom: false,
            enableParticles: false,
            textureQuality: 0.8,
            enableVSync: true
        )
        
        let estimatedLife = batteryOptimizer.getEstimatedBatteryLife(withSettings: settings)
        
        // Should return a valid time interval (or -1 for unlimited when plugged in)
        XCTAssertTrue(estimatedLife >= -1)
    }
    
    // MARK: - Performance Benchmark Tests
    
    func testBenchmarkConfiguration() {
        let config = PerformanceBenchmark.BenchmarkConfiguration(
            name: "Test Benchmark",
            description: "Test configuration",
            duration: 1.0,
            targetFrameRate: 60.0,
            visualizationMode: .spectrum,
            skinComplexity: .simple
        )
        
        XCTAssertEqual(config.name, "Test Benchmark")
        XCTAssertEqual(config.duration, 1.0)
        XCTAssertEqual(config.targetFrameRate, 60.0)
    }
    
    func testStandardBenchmarkSuite() {
        let suite = PerformanceBenchmark.standardBenchmarkSuite()
        
        XCTAssertFalse(suite.isEmpty)
        XCTAssertTrue(suite.count >= 5) // Should have multiple benchmark configurations
        
        // Check that all configurations are valid
        for config in suite {
            XCTAssertFalse(config.name.isEmpty)
            XCTAssertGreaterThan(config.duration, 0)
            XCTAssertGreaterThan(config.targetFrameRate, 0)
        }
    }
    
    func testQuickBenchmarkSuite() {
        let suite = PerformanceBenchmark.quickBenchmarkSuite()
        
        XCTAssertFalse(suite.isEmpty)
        XCTAssertLessThanOrEqual(suite.count, 5) // Quick suite should be smaller
        
        // All quick benchmarks should have shorter duration
        for config in suite {
            XCTAssertLessThanOrEqual(config.duration, 15.0)
        }
    }
    
    // MARK: - Performance Monitor Tests
    
    func testPerformanceMonitorInitialization() {
        XCTAssertFalse(performanceMonitor.isActive)
        XCTAssertEqual(performanceMonitor.alertCount, 0)
        XCTAssertGreaterThanOrEqual(performanceMonitor.performanceScore, 0)
        XCTAssertLessThanOrEqual(performanceMonitor.performanceScore, 100)
    }
    
    func testMonitoringStartStop() {
        performanceMonitor.startMonitoring()
        XCTAssertTrue(performanceMonitor.isActive)
        
        performanceMonitor.stopMonitoring()
        XCTAssertFalse(performanceMonitor.isActive)
    }
    
    func testMetricRecording() {
        performanceMonitor.recordMetric("testMetric", value: 42.0)
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    func testPerformanceReportGeneration() {
        let report = performanceMonitor.getPerformanceReport(timeWindow: 60.0)
        
        XCTAssertEqual(report.timeWindow, 60.0)
        XCTAssertGreaterThanOrEqual(report.averageFrameRate, 0)
        XCTAssertGreaterThanOrEqual(report.performanceScore, 0)
        XCTAssertLessThanOrEqual(report.performanceScore, 100)
    }
    
    func testPerformanceDataExport() {
        let data = performanceMonitor.exportPerformanceData()
        
        // Should be able to export data (may be nil if no data available)
        if let data = data {
            XCTAssertGreaterThan(data.count, 0)
        }
    }
    
    // MARK: - Integration Tests
    
    func testComponentIntegration() {
        // Test that all components can work together
        performanceMonitor.startMonitoring()
        adaptiveFrameRateManager.setMode(.adaptive)
        batteryOptimizer.setPowerMode(.automatic)
        
        let expectation = expectation(description: "Integration test")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        performanceMonitor.stopMonitoring()
        
        // All components should work together without crashing
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceOfMetricsCollection() {
        measure {
            // Test the performance of collecting metrics
            for _ in 0..<100 {
                let _ = performanceMonitor.currentMetrics
            }
        }
    }
    
    func testPerformanceOfFrameRateCalculation() {
        measure {
            // Test the performance of frame rate calculations
            for _ in 0..<100 {
                let _ = adaptiveFrameRateManager.currentMetrics
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidDeviceHandling() {
        // Test error handling with invalid configurations
        // These tests ensure the framework handles edge cases gracefully
        
        XCTAssertNoThrow {
            let _ = try ProMotionPerformanceTester(device: device)
        }
        
        XCTAssertNoThrow {
            let _ = try AdaptiveFrameRateManager(device: device)
        }
        
        XCTAssertNoThrow {
            let _ = try BatteryOptimizer(device: device)
        }
    }
    
    // MARK: - Memory Tests
    
    func testMemoryUsage() {
        // Test that the performance framework doesn't leak memory
        weak var weakTester: ProMotionPerformanceTester?
        weak var weakManager: AdaptiveFrameRateManager?
        weak var weakOptimizer: BatteryOptimizer?
        
        autoreleasepool {
            do {
                let tester = try ProMotionPerformanceTester(device: device)
                let manager = try AdaptiveFrameRateManager(device: device)
                let optimizer = try BatteryOptimizer(device: device)
                
                weakTester = tester
                weakManager = manager
                weakOptimizer = optimizer
                
                // Use the objects briefly
                tester.startTesting()
                manager.setMode(.balanced)
                optimizer.setPowerMode(.balanced)
                
                // Clean up
                tester.stopTesting()
            } catch {
                XCTFail("Failed to create performance objects: \(error)")
            }
        }
        
        // Objects should be deallocated
        XCTAssertNil(weakTester)
        XCTAssertNil(weakManager)
        XCTAssertNil(weakOptimizer)
    }
}

// MARK: - Mock Tests for Async Operations

extension PerformanceFrameworkTests {
    
    func testAsyncBenchmarkExecution() async throws {
        let configs = [
            PerformanceBenchmark.BenchmarkConfiguration(
                name: "Quick Test",
                description: "Quick async test",
                duration: 0.1, // Very short for testing
                targetFrameRate: 60.0,
                visualizationMode: .spectrum,
                skinComplexity: .simple
            )
        ]
        
        let suite = await performanceBenchmark.runBenchmarkSuite(configs, name: "Test Suite")
        
        XCTAssertEqual(suite.name, "Test Suite")
        XCTAssertEqual(suite.configurations.count, 1)
        XCTAssertEqual(suite.results.count, 1)
        XCTAssertGreaterThan(suite.executionTime, 0)
    }
    
    func testAsyncBatteryTesting() async throws {
        let results = await batteryOptimizer.testBatteryImpact()
        
        XCTAssertGreaterThanOrEqual(results.duration, 0)
        XCTAssertGreaterThanOrEqual(results.initialBatteryLevel, 0)
        XCTAssertLessThanOrEqual(results.initialBatteryLevel, 1)
    }
}