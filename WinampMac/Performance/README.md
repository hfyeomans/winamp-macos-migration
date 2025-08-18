# ProMotion Display Performance Framework for Winamp macOS

A comprehensive performance testing and optimization framework designed specifically for the Winamp macOS app, featuring 120Hz ProMotion display support and adaptive frame rate management.

## Overview

This framework provides five main components:

1. **ProMotion Performance Tester** - Tests 120Hz rendering capabilities and measures actual frame rates
2. **Adaptive Frame Rate Manager** - Dynamically adjusts frame rates based on performance and power state
3. **Battery Optimizer** - Optimizes power consumption while maintaining visual quality
4. **Performance Benchmark Suite** - Automated testing across different scenarios
5. **Real-time Performance Monitor** - Live performance monitoring with recommendations

## Features

### ProMotion Display Testing
- **Display Detection**: Automatically detects ProMotion-capable displays (120Hz+)
- **Frame Rate Measurement**: Precise frame timing using CVDisplayLink
- **Visualization Testing**: Tests all 5 visualization modes at different refresh rates
- **Performance Metrics**: Tracks GPU/CPU usage, frame drops, and stuttering
- **Comprehensive Testing**: Automated test suite covering all scenarios

### Adaptive Frame Rate Management
- **Dynamic Adjustment**: Automatically switches between 30/60/120Hz based on performance
- **Motion Prediction**: Smooth transitions using motion prediction algorithms
- **Content Awareness**: Adjusts based on visualization complexity
- **Power Management**: Reduces frame rates during battery-critical situations
- **Thermal Management**: Responds to thermal throttling conditions

### Battery Optimization
- **Power State Monitoring**: Real-time battery level and charging state tracking
- **Energy Impact Measurement**: Tracks power consumption of different visualization modes
- **Low Power Mode**: Automatically reduces effects when on battery power
- **Usage Estimates**: Provides battery life estimates for different settings
- **Thermal Response**: Automatic throttling during overheating

### Performance Benchmarking
- **Automated Testing**: Runs comprehensive performance tests automatically
- **Multiple Scenarios**: Tests with different skin complexities and visualization modes
- **Metal Pipeline Validation**: Ensures efficient Metal rendering pipeline
- **Memory Performance**: Tracks memory usage and cache performance
- **Detailed Reports**: Generates comprehensive performance reports

### Real-time Monitoring
- **Live FPS Counter**: Real-time frame rate display
- **System Metrics**: CPU, GPU, memory, and thermal monitoring
- **Performance Graphs**: Historical performance data visualization
- **Intelligent Recommendations**: AI-powered optimization suggestions
- **Automatic Optimization**: Can automatically apply performance improvements

## Technical Requirements

### System Requirements
- macOS 15.0+ (Sequoia)
- Metal-capable Mac (Apple Silicon or Intel with discrete GPU)
- Swift 6.0+
- Xcode 16.0+

### Optional Hardware Features
- ProMotion display (for 120Hz testing)
- Battery (for power optimization testing)
- External displays (for multi-display scenarios)

## Usage

### Basic Integration

```swift
import WinampPerformance

@MainActor
class PerformanceManager {
    let device: MTLDevice
    let performanceIntegration: PerformanceFrameworkIntegration
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw PerformanceError.metalNotAvailable
        }
        
        self.device = device
        self.performanceIntegration = try PerformanceFrameworkIntegration(device: device)
        
        // Enable automatic optimization
        performanceIntegration.enableAutomaticOptimization(true)
        performanceIntegration.setOptimizationLevel(.balanced)
    }
}
```

### Running Performance Tests

```swift
// Quick performance check
let quickSuite = PerformanceBenchmark.quickBenchmarkSuite()
let results = await performanceBenchmark.runBenchmarkSuite(quickSuite)

// Comprehensive ProMotion testing
let proMotionResults = await proMotionTester.runComprehensiveTests()

// Battery impact testing
let batteryResults = await batteryOptimizer.testBatteryImpact()
```

### Real-time Monitoring

```swift
// Start monitoring
performanceMonitor.startMonitoring()

// Access live metrics
let currentFPS = performanceMonitor.currentMetrics.frameRate
let cpuUsage = performanceMonitor.currentMetrics.cpuUsage
let performanceScore = performanceMonitor.performanceScore

// Get recommendations
let recommendations = performanceMonitor.recommendations
```

### Adaptive Frame Rate

```swift
// Set frame rate mode
adaptiveFrameRateManager.setMode(.adaptive)

// Configure content complexity
adaptiveFrameRateManager.setContentComplexity(.high)

// Enable adaptation
adaptiveFrameRateManager.enableAdaptation(true)
```

### Battery Optimization

```swift
// Set power mode
batteryOptimizer.setPowerMode(.automatic)

// Get recommended settings
let settings = batteryOptimizer.recommendedSettings

// Estimate battery life
let estimatedLife = batteryOptimizer.getEstimatedBatteryLife(withSettings: settings)
```

## Testing Scenarios

### Standard Test Suite
1. **Baseline Performance** - Basic rendering without visualizations
2. **Spectrum Analyzer** - Standard spectrum at 60Hz
3. **Particle System** - Complex particle visualization
4. **ProMotion 120Hz** - 120Hz rendering with complex visualization
5. **Maximum Complexity** - Extreme settings stress test
6. **Memory Stress** - High memory usage scenarios
7. **Thermal Stress** - Sustained high load testing

### Quick Test Suite
1. **Quick Baseline** - 10-second basic performance check
2. **Quick ProMotion** - 10-second 120Hz capability test

### Custom Testing
```swift
let customConfig = PerformanceBenchmark.BenchmarkConfiguration(
    name: "Custom Test",
    description: "Custom performance test",
    duration: 30.0,
    targetFrameRate: 90.0,
    visualizationMode: .particles,
    skinComplexity: .complex,
    concurrentTests: true
)
```

## Performance Metrics

### Frame Rate Metrics
- Current FPS
- Target FPS
- Frame drop percentage
- Stutter events
- Frame time consistency

### System Metrics
- CPU usage (%)
- GPU usage (%)
- Memory usage (MB)
- Memory pressure level
- Thermal state

### Battery Metrics
- Current battery level (%)
- Estimated battery life (hours)
- Power usage (watts)
- Energy impact by mode
- Charging state

### Rendering Metrics
- Draw calls per frame
- Triangles rendered
- Texture memory usage
- Buffer memory usage
- Pipeline state changes

## Configuration Options

### Performance Thresholds
```swift
let thresholds = PerformanceThresholds(
    highCPUThreshold: 80.0,      // 80% CPU usage
    highGPUThreshold: 85.0,      // 85% GPU usage
    highMemoryThreshold: 0.8,    // 80% memory usage
    frameDropThreshold: 0.05,    // 5% frame drops
    batteryLowThreshold: 0.2,    // 20% battery
    thermalThrottleTemperature: .critical
)
```

### Optimization Settings
```swift
let settings = OptimizationSettings(
    enableAutomaticOptimization: true,
    lowBatteryThreshold: 0.2,
    criticalBatteryThreshold: 0.1,
    targetFrameRateOnBattery: 30.0,
    targetFrameRatePluggedIn: 120.0,
    reduceVisualizationsOnBattery: true,
    disableEffectsOnLowBattery: true,
    enableBackgroundThrottling: true,
    thermalThrottlingEnabled: true
)
```

## Performance Recommendations

The framework provides intelligent recommendations based on system state:

### Automatic Optimizations
- **Frame Rate Reduction**: When performance drops below targets
- **Effect Disabling**: During high CPU/GPU usage
- **Quality Reduction**: Under memory pressure
- **Thermal Throttling**: During overheating
- **Battery Optimization**: When running on battery power

### Manual Recommendations
- Close unnecessary applications
- Reduce visualization complexity
- Lower skin quality settings
- Disable particle effects
- Switch to power saver mode

## Integration with Winamp Components

### Metal Renderer Integration
```swift
// Apply optimized settings to renderer
renderer.setFrameRate(adaptiveFrameRateManager.currentMetrics.targetFrameRate)
renderer.setQuality(batteryOptimizer.recommendedSettings.visualizationQuality)
```

### Audio Engine Integration
```swift
// Adjust audio processing based on performance
if performanceMonitor.performanceScore < 70 {
    audioEngine.setQuality(.reduced)
}
```

### UI Integration
```swift
// Display performance information in UI
struct PerformanceView: View {
    @EnvironmentObject var performance: PerformanceFrameworkIntegration
    
    var body: some View {
        VStack {
            Text("FPS: \(performance.currentFrameRate, specifier: "%.1f")")
            Text("Score: \(performance.performanceScore, specifier: "%.0f")")
            Text("Battery: \(performance.estimatedBatteryLife / 3600, specifier: "%.1f")h")
        }
    }
}
```

## Debugging and Profiling

### Performance Logging
```swift
// Enable detailed logging
performanceMonitor.showDebugInfo = true

// Record custom metrics
performanceMonitor.recordMetric("customOperation", value: 42.0)
```

### Signposting Integration
The framework uses os_signpost for integration with Instruments:
- Performance test events
- Frame rate adaptations
- Thermal state changes
- Battery optimizations
- Memory warnings

### Export and Analysis
```swift
// Export performance data
let data = performanceMonitor.exportPerformanceData()

// Generate comprehensive report
let report = performanceMonitor.getPerformanceReport(timeWindow: 300)
```

## Best Practices

### Initialization
1. Initialize performance components early in app lifecycle
2. Check for Metal availability before creating components
3. Configure automatic optimization settings based on user preferences

### Monitoring
1. Start performance monitoring when app becomes active
2. Stop monitoring when app goes to background
3. Respect user privacy settings for performance data collection

### Optimization
1. Apply optimizations gradually to avoid jarring changes
2. Provide user feedback when automatic optimizations are applied
3. Allow users to override automatic optimizations

### Testing
1. Run quick tests during app startup for basic health check
2. Provide comprehensive testing option in settings
3. Export test results for debugging and support

## Error Handling

### Common Errors
- `PerformanceTestError.metalInitializationFailed`
- `PerformanceTestError.displayLinkCreationFailed`
- `PerformanceTestError.testAlreadyRunning`
- `BenchmarkError.benchmarkAlreadyRunning`

### Recovery Strategies
```swift
do {
    let tester = try ProMotionPerformanceTester(device: device)
} catch PerformanceTestError.metalInitializationFailed {
    // Fallback to basic rendering without performance testing
    fallbackToBasicRendering()
}
```

## Future Enhancements

### Planned Features
- Machine learning-based performance prediction
- Cross-device performance comparison
- Cloud-based performance analytics
- Advanced thermal modeling
- GPU memory bandwidth optimization

### Integration Opportunities
- Metal Performance Shaders integration
- Core ML performance prediction
- CloudKit performance data sync
- WidgetKit performance widgets
- Control Center integration

---

For more information, see the individual component documentation and the comprehensive test suite in `WinampMac/Tests/Performance/`.