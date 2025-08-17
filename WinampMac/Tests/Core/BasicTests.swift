import XCTest
@testable import WinampCore

/// Basic tests to verify core functionality
final class BasicTests: XCTestCase {
    
    func testSystemDetection() async throws {
        let optimizer = AppleSiliconOptimizer.shared
        let systemInfo = optimizer.systemInfo
        
        XCTAssertNotNil(systemInfo.chipFamily)
        XCTAssertGreaterThan(systemInfo.coreCount, 0)
        XCTAssertGreaterThan(systemInfo.memorySize, 0)
        
        print("Detected system: \(systemInfo.chipFamily.rawValue)")
        print("Core count: \(systemInfo.coreCount)")
        print("Memory: \(systemInfo.memorySize / 1024 / 1024 / 1024) GB")
        print("Apple Silicon: \(systemInfo.isAppleSilicon)")
    }
    
    func testErrorHandling() async throws {
        let reporter = ErrorReporter.shared
        
        // Test error reporting
        let testError = WinampError.skinLoadingFailed(reason: .invalidArchive)
        await reporter.reportError(testError, context: "Unit test")
        
        let recentErrors = await reporter.getRecentErrors(count: 1)
        XCTAssertEqual(recentErrors.count, 1)
        XCTAssertEqual(recentErrors.first?.context, "Unit test")
        
        await reporter.clearHistory()
        let clearedErrors = await reporter.getRecentErrors()
        XCTAssertEqual(clearedErrors.count, 0)
    }
    
    func testPerformanceMonitoring() throws {
        let monitor = PerformanceMonitor.shared
        
        // Record some test metrics
        monitor.recordMetric("testMetric", value: 50.0)
        XCTAssertEqual(monitor.metrics["testMetric"], 50.0)
        
        // Test threshold warnings
        monitor.recordMetric("frameTime", value: 20.0) // Should trigger warning
        XCTAssertFalse(monitor.warnings.isEmpty)
        
        monitor.clearWarnings()
        XCTAssertTrue(monitor.warnings.isEmpty)
    }
    
    func testAudioEngineInitialization() throws {
        let audioEngine = ModernAudioEngine()
        
        // Test basic properties
        XCTAssertFalse(audioEngine.isPlaying)
        XCTAssertEqual(audioEngine.currentTime, 0)
        XCTAssertEqual(audioEngine.duration, 0)
        XCTAssertEqual(audioEngine.volume, 1.0)
        XCTAssertEqual(audioEngine.balance, 0.0)
        
        // Test supported formats
        XCTAssertTrue(audioEngine.supportedFormats.contains("mp3"))
        XCTAssertTrue(audioEngine.supportedFormats.contains("wav"))
        XCTAssertTrue(audioEngine.supportedFormats.contains("flac"))
    }
    
    func testAccelerateOptimizations() throws {
        let optimizer = AccelerateOptimizer.shared
        
        // Test FFT with a simple signal
        let inputSize = 1024
        let input = (0..<inputSize).map { i in
            sin(2.0 * Float.pi * Float(i) * 440.0 / 44100.0) // 440 Hz sine wave
        }
        
        var outputReal = Array(repeating: Float(0), count: inputSize / 2)
        var outputImaginary = Array(repeating: Float(0), count: inputSize / 2)
        
        optimizer.performOptimizedFFT(
            input: input,
            outputReal: &outputReal,
            outputImaginary: &outputImaginary
        )
        
        // Verify we got some output
        XCTAssertFalse(outputReal.allSatisfy { $0 == 0 })
        
        // Test magnitude calculation
        let magnitudes = optimizer.calculateMagnitudeSpectrum(
            real: outputReal,
            imaginary: outputImaginary
        )
        
        XCTAssertEqual(magnitudes.count, outputReal.count)
        XCTAssertFalse(magnitudes.allSatisfy { $0 == 0 })
    }
    
    func testWindowFunctions() throws {
        let optimizer = AccelerateOptimizer.shared
        
        var signal = Array(repeating: Float(1.0), count: 1024)
        
        // Test Hann window
        optimizer.applyWindow(to: &signal, windowType: .hann)
        
        // Verify window was applied (edges should be close to 0)
        XCTAssertLessThan(abs(signal.first ?? 1.0), 0.1)
        XCTAssertLessThan(abs(signal.last ?? 1.0), 0.1)
        
        // Middle should be close to original value
        let middleIndex = signal.count / 2
        XCTAssertGreaterThan(signal[middleIndex], 0.8)
    }
    
    func testEqualizerBands() throws {
        let audioEngine = ModernAudioEngine()
        
        // Test equalizer band configuration
        XCTAssertEqual(audioEngine.equalizerBands.count, 10)
        
        // Test frequency bands
        let expectedFrequencies: [Float] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        
        for (index, expectedFreq) in expectedFrequencies.enumerated() {
            XCTAssertEqual(audioEngine.equalizerBands[index].frequency, expectedFreq)
            XCTAssertEqual(audioEngine.equalizerBands[index].gain, 0.0)
        }
    }
    
    func testSkinDataStructures() throws {
        // Test basic skin data structures
        let config = SkinConfiguration()
        XCTAssertEqual(config.name, "Unknown Skin")
        XCTAssertTrue(config.regions.isEmpty)
        XCTAssertTrue(config.visualizationColors.isEmpty)
        
        let resources = SkinResources()
        XCTAssertTrue(resources.bitmaps.isEmpty)
        XCTAssertTrue(resources.cursors.isEmpty)
        
        let playlistConfig = PlaylistConfiguration()
        XCTAssertEqual(playlistConfig.fontName, "Arial")
        XCTAssertEqual(playlistConfig.numberDisplayRect, .zero)
    }
    
    func testPerformanceProfile() throws {
        let systemInfo = AppleSiliconOptimizer.SystemInfo.detect()
        let profile = AppleSiliconOptimizer.PerformanceProfile.determine(for: systemInfo)
        
        XCTAssertGreaterThan(profile.targetFrameRate, 0)
        XCTAssertGreaterThan(profile.audioBufferSize, 0)
        XCTAssertGreaterThan(profile.fftSize, 0)
        XCTAssertGreaterThan(profile.maxConcurrentTasks, 0)
        
        // Performance profile should match system capabilities
        if systemInfo.isAppleSilicon {
            XCTAssertTrue(profile.enableMetalOptimizations)
            XCTAssertTrue(profile.enableAccelerateOptimizations)
        }
        
        print("Performance profile:")
        print("- Target frame rate: \(profile.targetFrameRate) fps")
        print("- Render quality: \(profile.renderQuality.rawValue)")
        print("- Audio buffer size: \(profile.audioBufferSize)")
        print("- FFT size: \(profile.fftSize)")
        print("- Max concurrent tasks: \(profile.maxConcurrentTasks)")
    }
}

// MARK: - Async Test Support
extension BasicTests {
    
    func testAsyncSkinLoader() async throws {
        let loader = AsyncSkinLoader()
        
        // Test with a non-existent file (should fail gracefully)
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent.wsz")
        
        do {
            _ = try await loader.loadSkin(from: nonExistentURL)
            XCTFail("Should have thrown an error for non-existent file")
        } catch {
            XCTAssertTrue(error is WinampError)
        }
    }
    
    func testCacheManager() async throws {
        let cacheManager = SkinCacheManager()
        
        // Test basic cache operations
        let testSkin = WinampSkin(
            id: "test",
            name: "Test Skin",
            configuration: SkinConfiguration(),
            resources: SkinResources(),
            sourceURL: URL(fileURLWithPath: "/tmp/test.wsz")
        )
        
        await cacheManager.cacheSkin(testSkin, id: "test")
        let cachedSkin = await cacheManager.getCachedSkin(id: "test")
        
        XCTAssertNotNil(cachedSkin)
        XCTAssertEqual(cachedSkin?.name, "Test Skin")
        
        await cacheManager.clearCache()
        let clearedSkin = await cacheManager.getCachedSkin(id: "test")
        XCTAssertNil(clearedSkin)
    }
}

// MARK: - Performance Test Support
extension BasicTests {
    
    func testPerformanceMeasurement() throws {
        let optimizer = AppleSiliconOptimizer.shared
        
        // Simulate frame times
        for i in 0..<60 {
            let frameTime = 0.016 + Double.random(in: -0.002...0.002) // ~60fps with variance
            optimizer.recordFrameTime(frameTime)
        }
        
        let metrics = optimizer.getPerformanceMetrics()
        
        XCTAssertGreaterThan(metrics.currentFrameRate, 0)
        XCTAssertGreaterThan(metrics.targetFrameRate, 0)
        XCTAssertGreaterThan(metrics.efficiency, 0)
        XCTAssertLessThanOrEqual(metrics.efficiency, 1.0)
        
        print("Performance metrics:")
        print("- Current frame rate: \(String(format: "%.1f", metrics.currentFrameRate)) fps")
        print("- Target frame rate: \(String(format: "%.1f", metrics.targetFrameRate)) fps")
        print("- Efficiency: \(String(format: "%.1f%%", metrics.efficiency * 100))")
        print("- Thermal state: \(metrics.thermalState)")
    }
}