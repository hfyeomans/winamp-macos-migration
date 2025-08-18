import Cocoa
import AVFoundation
import UserNotifications

// MARK: - Winamp macOS Error Recovery System
// Comprehensive error handling with graceful degradation and user-friendly recovery

class WinampErrorRecoveryManager: NSObject {
    
    // MARK: - Error Categories
    
    enum ErrorCategory {
        case skinLoading
        case audioPlayback
        case fileAccess
        case performance
        case systemIntegration
        case userInterface
    }
    
    enum SkinError: Error, LocalizedError {
        case missingMainBitmap
        case incompatibleFormat(version: String)
        case corruptedAssets([String])
        case insufficientMemory(required: UInt64, available: UInt64)
        case invalidArchive
        case networkTimeout(url: URL)
        
        var errorDescription: String? {
            switch self {
            case .missingMainBitmap:
                return "Required skin graphics are missing"
            case .incompatibleFormat(let version):
                return "Skin format version \(version) is not supported"
            case .corruptedAssets(let files):
                return "Damaged files detected: \(files.joined(separator: ", "))"
            case .insufficientMemory(let required, let available):
                return "Not enough memory (need \(required / 1024 / 1024)MB, have \(available / 1024 / 1024)MB)"
            case .invalidArchive:
                return "Skin file appears to be corrupted"
            case .networkTimeout(let url):
                return "Download timed out: \(url.lastPathComponent)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .missingMainBitmap:
                return "Default graphics will be used for missing elements. Consider downloading the skin again."
            case .incompatibleFormat:
                return "This skin was created for an older version. It may not display correctly."
            case .corruptedAssets:
                return "Try downloading the skin from the original source."
            case .insufficientMemory:
                return "Close other applications or try a simpler skin."
            case .invalidArchive:
                return "The skin file may be damaged. Try downloading it again."
            case .networkTimeout:
                return "Check your internet connection and try again."
            }
        }
    }
    
    enum AudioError: Error, LocalizedError {
        case formatNotSupported(String)
        case deviceNotAvailable
        case corruptedFile(URL)
        case drmProtected(URL)
        case networkStreamFailed(URL, underlying: Error)
        case codecMissing(String)
        case hardwareFailure
        
        var errorDescription: String? {
            switch self {
            case .formatNotSupported(let format):
                return "Audio format '\(format)' is not supported"
            case .deviceNotAvailable:
                return "Audio device is not available"
            case .corruptedFile(let url):
                return "Audio file appears to be corrupted: \(url.lastPathComponent)"
            case .drmProtected(let url):
                return "File is protected by DRM: \(url.lastPathComponent)"
            case .networkStreamFailed(let url, _):
                return "Network stream failed: \(url.lastPathComponent)"
            case .codecMissing(let codec):
                return "Required audio codec not found: \(codec)"
            case .hardwareFailure:
                return "Audio hardware problem detected"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .formatNotSupported:
                return "Convert the file to MP3, AAC, or FLAC format."
            case .deviceNotAvailable:
                return "Check audio settings and try selecting a different output device."
            case .corruptedFile:
                return "Try playing a different file or re-downloading this one."
            case .drmProtected:
                return "This file cannot be played due to digital rights management protection."
            case .networkStreamFailed:
                return "Check your internet connection and try again."
            case .codecMissing:
                return "Install the required audio codec or convert the file to a supported format."
            case .hardwareFailure:
                return "Restart the application or check audio system settings."
            }
        }
    }
    
    // MARK: - Recovery Strategies
    
    enum RecoveryStrategy {
        case automaticFallback      // Try fallback without user intervention
        case userPromptWithOptions  // Show dialog with recovery options
        case silentDegradation     // Reduce functionality gracefully
        case restartRequired       // Application restart needed
        case skipAndContinue       // Skip problematic item and continue
    }
    
    struct RecoveryAction {
        let title: String
        let description: String
        let action: () -> Void
        let destructive: Bool
        let requiresRestart: Bool
        
        static func useDefaults() -> RecoveryAction {
            RecoveryAction(
                title: "Use Default Graphics",
                description: "Continue with default graphics for missing elements",
                action: { /* Apply default skin assets */ },
                destructive: false,
                requiresRestart: false
            )
        }
        
        static func tryAgain() -> RecoveryAction {
            RecoveryAction(
                title: "Try Again",
                description: "Attempt to load the skin again",
                action: { /* Retry loading */ },
                destructive: false,
                requiresRestart: false
            )
        }
        
        static func resetToClassic() -> RecoveryAction {
            RecoveryAction(
                title: "Reset to Classic Skin",
                description: "Switch to the built-in classic Winamp skin",
                action: { /* Load classic skin */ },
                destructive: false,
                requiresRestart: false
            )
        }
        
        static func restartApplication() -> RecoveryAction {
            RecoveryAction(
                title: "Restart Winamp",
                description: "Restart the application to resolve the issue",
                action: { NSApp.terminate(nil) },
                destructive: true,
                requiresRestart: true
            )
        }
    }
    
    // MARK: - Error Recovery Implementation
    
    func handleError(_ error: Error, in context: ErrorContext) {
        let strategy = determineRecoveryStrategy(for: error, context: context)
        
        switch strategy {
        case .automaticFallback:
            performAutomaticRecovery(for: error, context: context)
        case .userPromptWithOptions:
            showRecoveryDialog(for: error, context: context)
        case .silentDegradation:
            performSilentDegradation(for: error, context: context)
        case .restartRequired:
            showRestartRequiredDialog(for: error)
        case .skipAndContinue:
            skipAndContinue(for: error, context: context)
        }
        
        // Log error for analytics and debugging
        logError(error, strategy: strategy, context: context)
    }
    
    private func determineRecoveryStrategy(for error: Error, context: ErrorContext) -> RecoveryStrategy {
        switch error {
        case let skinError as SkinError:
            return determineSkinRecoveryStrategy(skinError, context: context)
        case let audioError as AudioError:
            return determineAudioRecoveryStrategy(audioError, context: context)
        default:
            return .userPromptWithOptions
        }
    }
    
    private func determineSkinRecoveryStrategy(_ error: SkinError, context: ErrorContext) -> RecoveryStrategy {
        switch error {
        case .missingMainBitmap:
            return .automaticFallback  // Use default graphics automatically
        case .incompatibleFormat:
            return .userPromptWithOptions  // Let user decide
        case .corruptedAssets(let files) where files.count < 3:
            return .automaticFallback  // Few corrupted files, use defaults
        case .corruptedAssets:
            return .userPromptWithOptions  // Many corrupted files, ask user
        case .insufficientMemory:
            return .silentDegradation  // Reduce quality automatically
        case .invalidArchive:
            return .userPromptWithOptions  // Definitely need user intervention
        case .networkTimeout:
            return .userPromptWithOptions  // User may want to retry
        }
    }
    
    private func determineAudioRecoveryStrategy(_ error: AudioError, context: ErrorContext) -> RecoveryStrategy {
        switch error {
        case .formatNotSupported:
            return .skipAndContinue  // Skip unsupported files
        case .deviceNotAvailable:
            return .userPromptWithOptions  // User needs to select device
        case .corruptedFile:
            return .skipAndContinue  // Skip corrupted files
        case .drmProtected:
            return .skipAndContinue  // Skip DRM files
        case .networkStreamFailed:
            return .userPromptWithOptions  // User may want to retry
        case .codecMissing:
            return .userPromptWithOptions  // User needs to install codec
        case .hardwareFailure:
            return .restartRequired  // Hardware issues may need restart
        }
    }
    
    // MARK: - Recovery Implementations
    
    private func performAutomaticRecovery(for error: Error, context: ErrorContext) {
        switch error {
        case let skinError as SkinError:
            handleSkinErrorAutomatically(skinError, context: context)
        case let audioError as AudioError:
            handleAudioErrorAutomatically(audioError, context: context)
        default:
            // Fallback to user prompt for unknown errors
            showRecoveryDialog(for: error, context: context)
        }
    }
    
    private func handleSkinErrorAutomatically(_ error: SkinError, context: ErrorContext) {
        switch error {
        case .missingMainBitmap:
            // Load default skin assets for missing elements
            loadDefaultSkinAssets()
            showBriefNotification("Using default graphics for missing skin elements")
            
        case .insufficientMemory:
            // Reduce skin quality to fit in available memory
            reduceSkinQuality()
            showBriefNotification("Reduced skin quality to save memory")
            
        default:
            // Unexpected case, fall back to user prompt
            showRecoveryDialog(for: error, context: context)
        }
    }
    
    private func handleAudioErrorAutomatically(_ error: AudioError, context: ErrorContext) {
        switch error {
        case .formatNotSupported, .corruptedFile, .drmProtected:
            // Skip problematic file and move to next
            skipCurrentTrack()
            
        default:
            // Other audio errors need user intervention
            showRecoveryDialog(for: error, context: context)
        }
    }
    
    private func showRecoveryDialog(for error: Error, context: ErrorContext) {
        let alert = NSAlert()
        alert.messageText = getErrorTitle(for: error)
        alert.informativeText = getErrorDescription(for: error)
        alert.alertStyle = .warning
        
        let actions = getRecoveryActions(for: error, context: context)
        
        for action in actions {
            let button = alert.addButton(withTitle: action.title)
            if action.destructive {
                button.hasDestructiveAction = true
            }
        }
        
        // Add "More Info" button for detailed error information
        alert.addButton(withTitle: "More Info")
        
        alert.beginSheetModal(for: context.window) { response in
            self.handleRecoveryResponse(response, actions: actions, error: error, context: context)
        }
    }
    
    private func handleRecoveryResponse(_ response: NSApplication.ModalResponse, actions: [RecoveryAction], error: Error, context: ErrorContext) {
        let buttonIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        
        if buttonIndex < actions.count {
            let action = actions[buttonIndex]
            action.action()
            
            if action.requiresRestart {
                scheduleApplicationRestart()
            }
        } else {
            // "More Info" button pressed
            showDetailedErrorInfo(for: error, context: context)
        }
    }
    
    private func getRecoveryActions(for error: Error, context: ErrorContext) -> [RecoveryAction] {
        switch error {
        case let skinError as SkinError:
            return getSkinRecoveryActions(skinError, context: context)
        case let audioError as AudioError:
            return getAudioRecoveryActions(audioError, context: context)
        default:
            return [.tryAgain(), .resetToClassic(), .restartApplication()]
        }
    }
    
    private func getSkinRecoveryActions(_ error: SkinError, context: ErrorContext) -> [RecoveryAction] {
        var actions: [RecoveryAction] = []
        
        switch error {
        case .missingMainBitmap:
            actions = [.useDefaults(), .tryAgain(), .resetToClassic()]
            
        case .incompatibleFormat:
            actions = [
                RecoveryAction(
                    title: "Use Compatibility Mode",
                    description: "Try to load with compatibility adjustments",
                    action: { /* Enable compatibility mode */ },
                    destructive: false,
                    requiresRestart: false
                ),
                .resetToClassic(),
                .tryAgain()
            ]
            
        case .corruptedAssets:
            actions = [
                RecoveryAction(
                    title: "Repair Skin",
                    description: "Attempt to fix corrupted elements",
                    action: { /* Attempt repair */ },
                    destructive: false,
                    requiresRestart: false
                ),
                .useDefaults(),
                .resetToClassic()
            ]
            
        case .insufficientMemory:
            actions = [
                RecoveryAction(
                    title: "Reduce Quality",
                    description: "Use lower quality assets to fit in memory",
                    action: { /* Reduce quality */ },
                    destructive: false,
                    requiresRestart: false
                ),
                RecoveryAction(
                    title: "Close Other Windows",
                    description: "Close playlist and equalizer to free memory",
                    action: { /* Close extra windows */ },
                    destructive: false,
                    requiresRestart: false
                ),
                .resetToClassic()
            ]
            
        case .invalidArchive, .networkTimeout:
            actions = [.tryAgain(), .resetToClassic()]
        }
        
        return actions
    }
    
    private func getAudioRecoveryActions(_ error: AudioError, context: ErrorContext) -> [RecoveryAction] {
        switch error {
        case .formatNotSupported:
            return [
                RecoveryAction(
                    title: "Skip This File",
                    description: "Continue with the next track",
                    action: { /* Skip track */ },
                    destructive: false,
                    requiresRestart: false
                ),
                RecoveryAction(
                    title: "Show Converter Options",
                    description: "Get information about file conversion",
                    action: { /* Show conversion help */ },
                    destructive: false,
                    requiresRestart: false
                )
            ]
            
        case .deviceNotAvailable:
            return [
                RecoveryAction(
                    title: "Select Audio Device",
                    description: "Choose a different audio output device",
                    action: { /* Show device selector */ },
                    destructive: false,
                    requiresRestart: false
                ),
                .restartApplication()
            ]
            
        case .corruptedFile, .drmProtected:
            return [
                RecoveryAction(
                    title: "Skip This File",
                    description: "Continue with the next track",
                    action: { /* Skip track */ },
                    destructive: false,
                    requiresRestart: false
                ),
                RecoveryAction(
                    title: "Remove from Playlist",
                    description: "Remove this file from the current playlist",
                    action: { /* Remove from playlist */ },
                    destructive: true,
                    requiresRestart: false
                )
            ]
            
        case .networkStreamFailed:
            return [
                .tryAgain(),
                RecoveryAction(
                    title: "Skip Stream",
                    description: "Continue with the next track",
                    action: { /* Skip track */ },
                    destructive: false,
                    requiresRestart: false
                )
            ]
            
        case .codecMissing:
            return [
                RecoveryAction(
                    title: "Install Codec",
                    description: "Get information about installing the required codec",
                    action: { /* Show codec install info */ },
                    destructive: false,
                    requiresRestart: false
                ),
                RecoveryAction(
                    title: "Skip This File",
                    description: "Continue with the next track",
                    action: { /* Skip track */ },
                    destructive: false,
                    requiresRestart: false
                )
            ]
            
        case .hardwareFailure:
            return [.restartApplication()]
        }
    }
    
    // MARK: - Silent Degradation
    
    private func performSilentDegradation(for error: Error, context: ErrorContext) {
        switch error {
        case let skinError as SkinError where skinError == .insufficientMemory:
            // Gradually reduce quality until skin loads successfully
            degradeSkinQuality()
            
        default:
            // For other errors, fall back to user prompt
            showRecoveryDialog(for: error, context: context)
        }
    }
    
    private func degradeSkinQuality() {
        // Implement quality reduction steps
        // 1. Reduce texture resolution
        // 2. Disable animations
        // 3. Use simpler rendering
        // 4. Fall back to default skin if all else fails
    }
    
    // MARK: - Skip and Continue
    
    private func skipAndContinue(for error: Error, context: ErrorContext) {
        switch error {
        case is AudioError:
            skipCurrentTrack()
            showBriefNotification("Skipped problematic audio file")
            
        default:
            // For non-audio errors, this strategy shouldn't be used
            showRecoveryDialog(for: error, context: context)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getErrorTitle(for error: Error) -> String {
        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "Unknown Error"
        }
        return "An error occurred"
    }
    
    private func getErrorDescription(for error: Error) -> String {
        if let localizedError = error as? LocalizedError {
            return localizedError.recoverySuggestion ?? localizedError.failureReason ?? "Please try again."
        }
        return "An unexpected error occurred. Please try again."
    }
    
    private func showBriefNotification(_ message: String) {
        // Show a brief, non-intrusive notification
        DispatchQueue.main.async {
            let notification = NSUserNotification()
            notification.title = "Winamp"
            notification.informativeText = message
            notification.soundName = nil  // Silent notification
            
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    private func showDetailedErrorInfo(for error: Error, context: ErrorContext) {
        let detailWindow = ErrorDetailWindow(error: error, context: context)
        detailWindow.showWindow(nil)
    }
    
    private func logError(_ error: Error, strategy: RecoveryStrategy, context: ErrorContext) {
        // Log error for analytics and debugging
        print("Error Recovery: \(error) with strategy \(strategy) in context \(context)")
        
        // In a real implementation, this would send to analytics service
        // or crash reporting system
    }
    
    // MARK: - Recovery Action Implementations
    
    private func loadDefaultSkinAssets() {
        // Load built-in default graphics for missing skin elements
        NotificationCenter.default.post(
            name: NSNotification.Name("LoadDefaultSkinAssets"),
            object: nil
        )
    }
    
    private func reduceSkinQuality() {
        // Reduce skin rendering quality to save memory
        NotificationCenter.default.post(
            name: NSNotification.Name("ReduceSkinQuality"),
            object: nil
        )
    }
    
    private func skipCurrentTrack() {
        // Skip to next track in playlist
        NotificationCenter.default.post(
            name: NSNotification.Name("SkipCurrentTrack"),
            object: nil
        )
    }
    
    private func scheduleApplicationRestart() {
        let alert = NSAlert()
        alert.messageText = "Restart Required"
        alert.informativeText = "Winamp needs to restart to complete the recovery process."
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Restart Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }
}

// MARK: - Supporting Types

struct ErrorContext {
    let window: NSWindow
    let operation: String
    let userInitiated: Bool
    let retryCount: Int
    let timestamp: Date
    
    init(window: NSWindow, operation: String, userInitiated: Bool = true, retryCount: Int = 0) {
        self.window = window
        self.operation = operation
        self.userInitiated = userInitiated
        self.retryCount = retryCount
        self.timestamp = Date()
    }
}

// MARK: - Error Detail Window

class ErrorDetailWindow: NSWindowController {
    private let error: Error
    private let context: ErrorContext
    
    init(error: Error, context: ErrorContext) {
        self.error = error
        self.context = context
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        setupWindow()
        setupContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        window?.title = "Error Details"
        window?.center()
        window?.setFrameAutosaveName("ErrorDetailWindow")
    }
    
    private func setupContent() {
        guard let contentView = window?.contentView else { return }
        
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        textView.string = generateDetailedErrorReport()
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        
        contentView.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func generateDetailedErrorReport() -> String {
        var report = "WINAMP ERROR REPORT\n"
        report += "==================\n\n"
        
        report += "Timestamp: \(context.timestamp)\n"
        report += "Operation: \(context.operation)\n"
        report += "User Initiated: \(context.userInitiated)\n"
        report += "Retry Count: \(context.retryCount)\n\n"
        
        report += "Error Details:\n"
        report += "Type: \(type(of: error))\n"
        report += "Description: \(error.localizedDescription)\n"
        
        if let nsError = error as NSError? {
            report += "Domain: \(nsError.domain)\n"
            report += "Code: \(nsError.code)\n"
            
            if !nsError.userInfo.isEmpty {
                report += "User Info:\n"
                for (key, value) in nsError.userInfo {
                    report += "  \(key): \(value)\n"
                }
            }
        }
        
        report += "\nSystem Information:\n"
        report += "macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        report += "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n"
        report += "Available Memory: \(getAvailableMemory())\n"
        
        return report
    }
    
    private func getAvailableMemory() -> String {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        return "\(physicalMemory / 1024 / 1024) MB"
    }
}