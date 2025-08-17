import Foundation

/// Comprehensive error handling system for WinampMac
/// Uses Result types and structured error reporting for reliability
public enum WinampError: Error, Sendable {
    // MARK: - Skin Loading Errors
    case skinLoadingFailed(reason: SkinLoadingError)
    case skinParsingFailed(file: String, reason: String)
    case skinResourceMissing(resource: String)
    case skinFormatUnsupported(format: String)
    
    // MARK: - Rendering Errors
    case metalInitializationFailed(reason: String)
    case shaderCompilationFailed(shader: String, error: String)
    case textureCreationFailed(reason: String)
    case renderingPipelineFailed(reason: String)
    
    // MARK: - Audio Errors
    case audioEngineInitializationFailed(reason: String)
    case audioFormatUnsupported(format: String)
    case equalizerSetupFailed(reason: String)
    case fftProcessingFailed(reason: String)
    
    // MARK: - Window Management Errors
    case windowCreationFailed(reason: String)
    case windowShapingFailed(reason: String)
    case dockingFailed(reason: String)
    
    // MARK: - Resource Errors
    case fileNotFound(path: String)
    case compressionFailed(reason: String)
    case cacheOperationFailed(operation: String, reason: String)
    
    // MARK: - System Errors
    case insufficientMemory
    case unsupportedPlatform(required: String)
    case performanceThresholdExceeded(metric: String, value: Double, threshold: Double)
    
    public enum SkinLoadingError: Sendable {
        case invalidArchive
        case corruptedData
        case missingMainBitmap
        case invalidConfiguration
        case unsupportedVersion
    }
}

// MARK: - Error Descriptions
extension WinampError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .skinLoadingFailed(let reason):
            return "Failed to load skin: \(reason.localizedDescription)"
        case .skinParsingFailed(let file, let reason):
            return "Failed to parse skin file '\(file)': \(reason)"
        case .skinResourceMissing(let resource):
            return "Skin resource missing: \(resource)"
        case .skinFormatUnsupported(let format):
            return "Unsupported skin format: \(format)"
        case .metalInitializationFailed(let reason):
            return "Metal initialization failed: \(reason)"
        case .shaderCompilationFailed(let shader, let error):
            return "Shader '\(shader)' compilation failed: \(error)"
        case .textureCreationFailed(let reason):
            return "Texture creation failed: \(reason)"
        case .renderingPipelineFailed(let reason):
            return "Rendering pipeline failed: \(reason)"
        case .audioEngineInitializationFailed(let reason):
            return "Audio engine initialization failed: \(reason)"
        case .audioFormatUnsupported(let format):
            return "Unsupported audio format: \(format)"
        case .equalizerSetupFailed(let reason):
            return "Equalizer setup failed: \(reason)"
        case .fftProcessingFailed(let reason):
            return "FFT processing failed: \(reason)"
        case .windowCreationFailed(let reason):
            return "Window creation failed: \(reason)"
        case .windowShapingFailed(let reason):
            return "Window shaping failed: \(reason)"
        case .dockingFailed(let reason):
            return "Window docking failed: \(reason)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .compressionFailed(let reason):
            return "Compression operation failed: \(reason)"
        case .cacheOperationFailed(let operation, let reason):
            return "Cache operation '\(operation)' failed: \(reason)"
        case .insufficientMemory:
            return "Insufficient memory to complete operation"
        case .unsupportedPlatform(let required):
            return "Unsupported platform. Required: \(required)"
        case .performanceThresholdExceeded(let metric, let value, let threshold):
            return "Performance threshold exceeded: \(metric) = \(value) > \(threshold)"
        }
    }
}

extension WinampError.SkinLoadingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "Invalid or corrupted skin archive"
        case .corruptedData:
            return "Skin data is corrupted"
        case .missingMainBitmap:
            return "Main bitmap file is missing"
        case .invalidConfiguration:
            return "Invalid skin configuration"
        case .unsupportedVersion:
            return "Unsupported skin version"
        }
    }
}

// MARK: - Error Recovery Suggestions
extension WinampError {
    public var recoverySuggestion: String? {
        switch self {
        case .skinLoadingFailed:
            return "Try selecting a different skin or check if the skin file is corrupted."
        case .metalInitializationFailed:
            return "Ensure your system supports Metal 3.0 and restart the application."
        case .audioEngineInitializationFailed:
            return "Check audio device availability and system permissions."
        case .insufficientMemory:
            return "Close other applications to free up memory."
        case .unsupportedPlatform:
            return "Update to macOS 15.0 or later to use this application."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
}

// MARK: - Performance Monitoring
@MainActor
public final class PerformanceMonitor: ObservableObject {
    public static let shared = PerformanceMonitor()
    
    @Published public private(set) var metrics: [String: Double] = [:]
    @Published public private(set) var warnings: [String] = []
    
    private let thresholds: [String: Double] = [
        "frameTime": 16.67, // 60 FPS threshold
        "memoryUsage": 512.0, // 512 MB threshold
        "cpuUsage": 80.0, // 80% CPU threshold
        "renderTime": 8.0 // 8ms render time threshold
    ]
    
    private init() {}
    
    public func recordMetric(_ name: String, value: Double) {
        metrics[name] = value
        
        if let threshold = thresholds[name], value > threshold {
            let warning = "Performance threshold exceeded: \(name) = \(value) > \(threshold)"
            warnings.append(warning)
            
            // Keep only last 10 warnings
            if warnings.count > 10 {
                warnings.removeFirst()
            }
        }
    }
    
    public func clearWarnings() {
        warnings.removeAll()
    }
}

// MARK: - Error Reporting
public actor ErrorReporter {
    public static let shared = ErrorReporter()
    
    private var errorHistory: [ErrorReport] = []
    private let maxHistorySize = 100
    
    private init() {}
    
    public struct ErrorReport: Sendable {
        public let error: WinampError
        public let timestamp: Date
        public let context: String?
        
        public init(error: WinampError, context: String? = nil) {
            self.error = error
            self.timestamp = Date()
            self.context = context
        }
    }
    
    public func reportError(_ error: WinampError, context: String? = nil) {
        let report = ErrorReport(error: error, context: context)
        errorHistory.append(report)
        
        // Maintain history size
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst()
        }
        
        // Log to console for debugging
        print("WinampMac Error: \(error.localizedDescription)")
        if let context = context {
            print("Context: \(context)")
        }
    }
    
    public func getRecentErrors(count: Int = 10) -> [ErrorReport] {
        return Array(errorHistory.suffix(count))
    }
    
    public func clearHistory() {
        errorHistory.removeAll()
    }
}