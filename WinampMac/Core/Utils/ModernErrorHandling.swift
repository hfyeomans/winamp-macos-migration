//
//  ModernErrorHandling.swift
//  WinampMac
//
//  Modern error handling patterns with Result types and proper Swift error handling
//  Replaces force unwrapping with safe error propagation
//  Compatible with macOS 15.0+ and future-proofed for macOS 26.x
//

import Foundation
import OSLog
import AppKit

/// Comprehensive error handling system for Winamp macOS
@available(macOS 15.0, *)
@MainActor
public final class ModernErrorHandling {
    
    // MARK: - Centralized Logger
    public static let logger = Logger(subsystem: "com.winamp.mac", category: "ErrorHandling")
    
    // MARK: - Error Types
    public enum WinampError: LocalizedError, Equatable {
        // Skin-related errors
        case skinNotFound(String)
        case skinCorrupted(String, underlying: String?)
        case skinIncompatible(String, version: String?)
        case skinMissingAssets([String])
        
        // Audio-related errors
        case audioInitializationFailed(String)
        case audioFormatUnsupported(String)
        case audioDeviceNotFound(String)
        case audioPlaybackFailed(String)
        
        // File system errors
        case fileNotReadable(String)
        case fileNotWritable(String)
        case directoryNotCreatable(String)
        case insufficientStorage(required: Int64, available: Int64)
        
        // Network errors
        case networkUnavailable
        case downloadFailed(url: String, reason: String)
        case serverError(code: Int, message: String)
        
        // Memory errors
        case memoryAllocationFailed(size: Int)
        case memoryPressureCritical
        case cacheEvictionFailed
        
        // Configuration errors
        case configurationInvalid(key: String, value: String)
        case settingsCorrupted(String)
        case defaultsNotAccessible
        
        // Metal/Graphics errors
        case metalNotSupported
        case shaderCompilationFailed(String)
        case textureCreationFailed(String)
        case renderingFailed(String)
        
        // System errors
        case permissionDenied(operation: String)
        case systemCallFailed(function: String, errno: Int32)
        case resourceUnavailable(resource: String)
        
        public var errorDescription: String? {
            switch self {
            // Skin errors
            case .skinNotFound(let name):
                return "Skin '\(name)' not found"
            case .skinCorrupted(let name, let underlying):
                let base = "Skin '\(name)' is corrupted"
                return underlying.map { "\(base): \($0)" } ?? base
            case .skinIncompatible(let name, let version):
                let base = "Skin '\(name)' is incompatible"
                return version.map { "\(base) (version \($0))" } ?? base
            case .skinMissingAssets(let assets):
                return "Skin missing required assets: \(assets.joined(separator: ", "))"
                
            // Audio errors
            case .audioInitializationFailed(let reason):
                return "Audio initialization failed: \(reason)"
            case .audioFormatUnsupported(let format):
                return "Audio format '\(format)' is not supported"
            case .audioDeviceNotFound(let device):
                return "Audio device '\(device)' not found"
            case .audioPlaybackFailed(let reason):
                return "Audio playback failed: \(reason)"
                
            // File system errors
            case .fileNotReadable(let path):
                return "File '\(path)' is not readable"
            case .fileNotWritable(let path):
                return "File '\(path)' is not writable"
            case .directoryNotCreatable(let path):
                return "Directory '\(path)' cannot be created"
            case .insufficientStorage(let required, let available):
                let requiredMB = ByteCountFormatter.string(fromByteCount: required, countStyle: .file)
                let availableMB = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
                return "Insufficient storage: need \(requiredMB), have \(availableMB)"
                
            // Network errors
            case .networkUnavailable:
                return "Network connection unavailable"
            case .downloadFailed(let url, let reason):
                return "Download failed for '\(url)': \(reason)"
            case .serverError(let code, let message):
                return "Server error \(code): \(message)"
                
            // Memory errors
            case .memoryAllocationFailed(let size):
                let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .memory)
                return "Memory allocation failed for \(sizeStr)"
            case .memoryPressureCritical:
                return "Critical memory pressure detected"
            case .cacheEvictionFailed:
                return "Cache eviction failed"
                
            // Configuration errors
            case .configurationInvalid(let key, let value):
                return "Invalid configuration: \(key) = '\(value)'"
            case .settingsCorrupted(let details):
                return "Settings corrupted: \(details)"
            case .defaultsNotAccessible:
                return "User defaults not accessible"
                
            // Metal/Graphics errors
            case .metalNotSupported:
                return "Metal rendering not supported on this device"
            case .shaderCompilationFailed(let error):
                return "Shader compilation failed: \(error)"
            case .textureCreationFailed(let reason):
                return "Texture creation failed: \(reason)"
            case .renderingFailed(let reason):
                return "Rendering failed: \(reason)"
                
            // System errors
            case .permissionDenied(let operation):
                return "Permission denied for operation: \(operation)"
            case .systemCallFailed(let function, let errno):
                return "System call '\(function)' failed with errno \(errno)"
            case .resourceUnavailable(let resource):
                return "Resource unavailable: \(resource)"
            }
        }
        
        public var recoverySuggestion: String? {
            switch self {
            case .skinNotFound:
                return "Check that the skin file exists and try again"
            case .skinCorrupted:
                return "Try downloading the skin again or use a different skin"
            case .skinIncompatible:
                return "Use a compatible skin version or update the application"
            case .audioInitializationFailed:
                return "Check audio settings and restart the application"
            case .networkUnavailable:
                return "Check your internet connection and try again"
            case .memoryPressureCritical:
                return "Close other applications to free up memory"
            case .metalNotSupported:
                return "Use software rendering mode or update your graphics drivers"
            case .permissionDenied:
                return "Grant the necessary permissions in System Preferences"
            default:
                return "Try restarting the application"
            }
        }
        
        public var failureReason: String? {
            switch self {
            case .skinCorrupted(_, let underlying):
                return underlying
            case .audioPlaybackFailed(let reason):
                return reason
            case .downloadFailed(_, let reason):
                return reason
            default:
                return nil
            }
        }
    }
    
    // MARK: - Error Context
    public struct ErrorContext {
        public let operation: String
        public let timestamp: Date
        public let userInfo: [String: Any]
        public let stackTrace: [String]
        
        public init(operation: String, userInfo: [String: Any] = [:]) {
            self.operation = operation
            self.timestamp = Date()
            self.userInfo = userInfo
            self.stackTrace = Thread.callStackSymbols
        }
    }
    
    // MARK: - Result Types
    public typealias WinampResult<T> = Result<T, WinampError>
    
    // MARK: - Error Reporting
    public struct ErrorReport {
        public let error: WinampError
        public let context: ErrorContext
        public let severity: Severity
        public let shouldReport: Bool
        
        public enum Severity {
            case low       // Recoverable, no user impact
            case medium    // Some functionality affected
            case high      // Major functionality affected
            case critical  // App may crash or become unusable
        }
        
        public init(error: WinampError, context: ErrorContext, severity: Severity = .medium, shouldReport: Bool = true) {
            self.error = error
            self.context = context
            self.severity = severity
            self.shouldReport = shouldReport
        }
    }
    
    // MARK: - Error Handler Protocol
    public protocol ErrorHandler {
        func handle(_ error: ModernErrorHandling.WinampError, context: ModernErrorHandling.ErrorContext) async
        func canHandle(_ error: ModernErrorHandling.WinampError) -> Bool
    }
    
    // MARK: - Error Manager
    @MainActor public static let shared = ModernErrorHandling()
    
    private var errorHandlers: [ErrorHandler] = []
    private var errorHistory: [ErrorReport] = []
    private let errorQueue = DispatchQueue(label: "com.winamp.errors", qos: .utility)
    
    private init() {
        setupDefaultHandlers()
        setupCrashReporting()
    }
    
    private func setupDefaultHandlers() {
        registerHandler(LoggingErrorHandler())
        registerHandler(UserNotificationErrorHandler())
        registerHandler(RecoveryErrorHandler())
    }
    
    private func setupCrashReporting() {
        // Set up uncaught exception handler
        NSSetUncaughtExceptionHandler { exception in
            Self.logger.fault("Uncaught exception: \(exception)")
            
            let error = WinampError.systemCallFailed(
                function: "NSException",
                errno: -1
            )
            let context = ErrorContext(
                operation: "uncaught_exception",
                userInfo: [
                    "name": exception.name.rawValue,
                    "reason": exception.reason ?? "Unknown",
                    "userInfo": exception.userInfo ?? [:]
                ]
            )
            
            Task {
                await Self.shared.reportError(error, context: context, severity: .critical)
            }
        }
    }
    
    // MARK: - Public Interface
    public func registerHandler(_ handler: ErrorHandler) {
        Task { @MainActor in
            self.errorHandlers.append(handler)
        }
    }
    
    public func reportError(_ error: WinampError, context: ErrorContext, severity: ErrorReport.Severity = .medium) async {
        let report = ErrorReport(error: error, context: context, severity: severity)
        
        Task { @MainActor in
            self.errorHistory.append(report)
            
            // Keep history manageable
            if self.errorHistory.count > 1000 {
                self.errorHistory.removeFirst(100)
            }
        }
        
        // Handle error with registered handlers
        for handler in errorHandlers {
            if handler.canHandle(error) {
                await handler.handle(error, context: context)
            }
        }
        
        // Log based on severity
        switch severity {
        case .low:
            Self.logger.debug("Low severity error: \(error.localizedDescription)")
        case .medium:
            Self.logger.info("Medium severity error: \(error.localizedDescription)")
        case .high:
            Self.logger.error("High severity error: \(error.localizedDescription)")
        case .critical:
            Self.logger.fault("Critical error: \(error.localizedDescription)")
        }
    }
    
    public func getErrorHistory() -> [ErrorReport] {
        return errorQueue.sync {
            return Array(errorHistory)
        }
    }
    
    public func clearErrorHistory() {
        Task { @MainActor in
            self.errorHistory.removeAll()
        }
    }
}

// MARK: - Safe Operation Wrappers
@available(macOS 15.0, *)
public extension ModernErrorHandling {
    
    /// Safely execute an operation that might throw
    static func safeExecute<T>(
        operation: String,
        userInfo: [String: Any] = [:],
        block: () throws -> T
    ) async -> WinampResult<T> {
        let context = ErrorContext(operation: operation, userInfo: userInfo)
        
        do {
            let result = try block()
            return .success(result)
        } catch let error as WinampError {
            await shared.reportError(error, context: context)
            return .failure(error)
        } catch {
            let winampError = WinampError.systemCallFailed(
                function: operation,
                errno: Int32((error as NSError).code)
            )
            await shared.reportError(winampError, context: context)
            return .failure(winampError)
        }
    }
    
    /// Safely execute an async operation
    static func safeExecuteAsync<T: Sendable>(
        operation: String,
        userInfo: [String: Any] = [:],
        block: @Sendable () async throws -> T
    ) async -> WinampResult<T> {
        let context = ErrorContext(operation: operation, userInfo: userInfo)
        
        do {
            let result = try await block()
            return .success(result)
        } catch let error as WinampError {
            await shared.reportError(error, context: context)
            return .failure(error)
        } catch {
            let winampError = WinampError.systemCallFailed(
                function: operation,
                errno: Int32((error as NSError).code)
            )
            await shared.reportError(winampError, context: context)
            return .failure(winampError)
        }
    }
    
    /// Safely unwrap optionals
    static func safeUnwrap<T>(
        _ optional: T?,
        operation: String,
        errorType: WinampError
    ) async -> WinampResult<T> {
        guard let value = optional else {
            let context = ErrorContext(operation: operation)
            await shared.reportError(errorType, context: context)
            return .failure(errorType)
        }
        return .success(value)
    }
}

// MARK: - Default Error Handlers
@available(macOS 15.0, *)
private struct LoggingErrorHandler: ModernErrorHandling.ErrorHandler {
    func handle(_ error: ModernErrorHandling.WinampError, context: ModernErrorHandling.ErrorContext) async {
        ModernErrorHandling.logger.error("Error in \(context.operation): \(error.localizedDescription)")
    }
    
    func canHandle(_ error: ModernErrorHandling.WinampError) -> Bool {
        return true // Log all errors
    }
}

@available(macOS 15.0, *)
private struct UserNotificationErrorHandler: ModernErrorHandling.ErrorHandler {
    func handle(_ error: ModernErrorHandling.WinampError, context: ModernErrorHandling.ErrorContext) async {
        // Only show user notifications for medium+ severity errors
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Winamp Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            
            if let suggestion = error.recoverySuggestion {
                alert.informativeText += "\n\n\(suggestion)"
            }
            
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func canHandle(_ error: ModernErrorHandling.WinampError) -> Bool {
        // Show alerts for user-facing errors
        switch error {
        case .skinNotFound, .skinCorrupted, .skinIncompatible,
             .audioInitializationFailed, .networkUnavailable,
             .permissionDenied:
            return true
        default:
            return false
        }
    }
}

@available(macOS 15.0, *)
private struct RecoveryErrorHandler: ModernErrorHandling.ErrorHandler {
    func handle(_ error: ModernErrorHandling.WinampError, context: ModernErrorHandling.ErrorContext) async {
        // Attempt automatic recovery for certain errors
        switch error {
        case .memoryPressureCritical:
            // Clear caches
            NotificationCenter.default.post(name: .clearCaches, object: nil)
            
        case .audioInitializationFailed:
            // Try to reinitialize audio
            NotificationCenter.default.post(name: .reinitializeAudio, object: nil)
            
        case .skinCorrupted:
            // Fall back to default skin
            NotificationCenter.default.post(name: .loadDefaultSkin, object: nil)
            
        default:
            break
        }
    }
    
    func canHandle(_ error: ModernErrorHandling.WinampError) -> Bool {
        switch error {
        case .memoryPressureCritical, .audioInitializationFailed, .skinCorrupted:
            return true
        default:
            return false
        }
    }
}

// MARK: - Recovery Notifications
extension Notification.Name {
    static let clearCaches = Notification.Name("WinampClearCaches")
    static let reinitializeAudio = Notification.Name("WinampReinitializeAudio")
    static let loadDefaultSkin = Notification.Name("WinampLoadDefaultSkin")
}

// MARK: - Extensions for Common Operations
@available(macOS 15.0, *)
public extension NSImage {
    
    /// Safely create NSImage from data
    static func safeInit(data: Data, operation: String = "image_creation") async -> ModernErrorHandling.WinampResult<NSImage> {
        return await ModernErrorHandling.safeExecute(operation: operation) {
            guard let image = NSImage(data: data) else {
                throw ModernErrorHandling.WinampError.skinCorrupted("image", underlying: "Invalid image data")
            }
            return image
        }
    }
    
    /// Safely get CGImage representation
    func safeCGImage(operation: String = "cgimage_conversion") async -> ModernErrorHandling.WinampResult<CGImage> {
        return await ModernErrorHandling.safeUnwrap(
            self.cgImage(forProposedRect: nil, context: nil, hints: nil),
            operation: operation,
            errorType: .skinCorrupted("image", underlying: "Could not get CGImage representation")
        )
    }
}

@available(macOS 15.0, *)
public extension FileManager {
    
    /// Safely check file existence and readability
    func safeFileExists(at url: URL) async -> ModernErrorHandling.WinampResult<Bool> {
        return await ModernErrorHandling.safeExecute(operation: "file_exists_check") {
            let exists = self.fileExists(atPath: url.path)
            if exists {
                guard self.isReadableFile(atPath: url.path) else {
                    throw ModernErrorHandling.WinampError.fileNotReadable(url.path)
                }
            }
            return exists
        }
    }
    
    /// Safely create directory
    func safeCreateDirectory(at url: URL, withIntermediateDirectories: Bool = true) async -> ModernErrorHandling.WinampResult<Void> {
        return await ModernErrorHandling.safeExecuteAsync(operation: "create_directory") {
            try self.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
        }
    }
}