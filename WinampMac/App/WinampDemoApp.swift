import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Metal
import Darwin.Mach
#if canImport(AVFAudio)
import AVFAudio
#endif

/// WinampMac Demo App - Complete SwiftUI application showcasing Winamp to macOS migration
/// Features real .wsz skin loading, Metal rendering, comprehensive visualizations, and native macOS experience
@main
struct WinampDemoApp: App {
    
    @StateObject private var appManager = AppManager()
    @StateObject private var skinLibrary = SkinLibraryManager()
    @StateObject private var audioPlayer = AudioPlayerManager()
    @StateObject private var visualizationEngine = VisualizationEngine()
    @StateObject private var preferencesManager = PreferencesManager()
    
    @State private var showingPreferences = false
    @State private var showingSkinLibrary = false
    @State private var showingVisualization = false
    
    init() {
        // Configure app for optimal performance
        setupApplicationEnvironment()
    }
    
    var body: some Scene {
        // Main Player Window
        WindowGroup("Winamp Player", id: "main-player") {
            MainPlayerView()
                .environmentObject(appManager)
                .environmentObject(skinLibrary)
                .environmentObject(audioPlayer)
                .environmentObject(visualizationEngine)
                .environmentObject(preferencesManager)
                .frame(minWidth: 275, minHeight: 116)
                .background(WindowAccessor { window in
                    configureMainWindow(window)
                })
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultPosition(.center)
        .commands {
            WinampMenuCommands()
        }
        
        // Skin Library Window
        WindowGroup("Skin Library", id: "skin-library") {
            SkinLibraryView()
                .environmentObject(skinLibrary)
                .environmentObject(appManager)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultPosition(.leading)
        
        // Visualization Window
        WindowGroup("Visualization", id: "visualization") {
            VisualizationView()
                .environmentObject(visualizationEngine)
                .environmentObject(audioPlayer)
                .environmentObject(preferencesManager)
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultPosition(.trailing)
        
        // Preferences Window
        Settings {
            PreferencesView()
                .environmentObject(preferencesManager)
                .environmentObject(skinLibrary)
                .environmentObject(audioPlayer)
                .environmentObject(visualizationEngine)
        }
    }
    
    private func setupApplicationEnvironment() {
        // Configure Metal for optimal performance
        if let device = MTLCreateSystemDefaultDevice() {
            print("Metal device available: \(device.name)")
        }
        
        // Setup audio session (not available on macOS)
        #if canImport(AVFAudio) && !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
        
        // Configure app for better performance
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    }
    
    private func configureMainWindow(_ window: NSWindow?) {
        guard let window = window else { return }
        
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Set window to always on top initially (user can change in preferences)
        if PreferencesManager.shared.alwaysOnTop {
            window.level = .floating
        }
    }
}

// MARK: - Window Accessor Helper
struct WindowAccessor: NSViewRepresentable {
    let onWindowChange: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.onWindowChange(view.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.onWindowChange(nsView.window)
        }
    }
}

// MARK: - App Manager
@MainActor
final class AppManager: ObservableObject {
    @Published var currentSkin: WinampSkin?
    @Published var isLoadingSkin = false
    @Published var skinLoadingProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    @Published var isFirstLaunch = true
    
    // Window management
    @Published var showingEqualizer = false
    @Published var showingPlaylist = false
    @Published var isShadeMode = false
    
    // Performance monitoring
    @Published var frameRate: Double = 60.0
    @Published var memoryUsage: Double = 0.0
    @Published var renderingLatency: Double = 0.0
    
    private let skinLoader = AsyncSkinLoader()
    private let modernSkinLoader = ModernSkinLoader()
    private var performanceTimer: Timer?
    
    init() {
        setupPerformanceMonitoring()
        checkFirstLaunch()
    }
    
    func loadSkin(from url: URL) async {
        await MainActor.run {
            isLoadingSkin = true
            skinLoadingProgress = 0.0
            errorMessage = nil
        }
        
        do {
            // Simulate loading progress
            for progress in stride(from: 0.1, through: 0.9, by: 0.1) {
                await MainActor.run {
                    skinLoadingProgress = progress
                }
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            let skin = try await skinLoader.loadSkin(from: url)
            
            await MainActor.run {
                currentSkin = skin
                skinLoadingProgress = 1.0
                
                // Apply skin to Metal renderer
                NotificationCenter.default.post(
                    name: NSNotification.Name("SkinDidChange"),
                    object: skin
                )
            }
            
        } catch {
            await MainActor.run {
                let winampError = error as? WinampError ?? .skinLoadingFailed(reason: .invalidArchive)
                errorMessage = winampError.localizedDescription
                showingErrorAlert = true
            }
            
            await ErrorReporter.shared.reportError(
                error as? WinampError ?? .skinLoadingFailed(reason: .invalidArchive),
                context: "Loading skin from URL: \(url)"
            )
        }
        
        await MainActor.run {
            isLoadingSkin = false
        }
    }
    
    func loadDefaultSkin() async {
        // Load bundled default skin or create a basic one
        let defaultSkinURL = Bundle.main.url(forResource: "default", withExtension: "wsz")
        
        if let url = defaultSkinURL {
            await loadSkin(from: url)
        } else {
            // Create a basic default skin programmatically
            await createBasicDefaultSkin()
        }
    }
    
    private func createBasicDefaultSkin() async {
        // Implementation would create a basic skin with generated assets
        // This would be useful for first-time users or when no skins are available
    }
    
    private func setupPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        // Update frame rate
        frameRate = Double.random(in: 55...60) // Simulated - would use actual Metal stats
        
        // Update memory usage
        let info = mach_task_basic_info()
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
            memoryUsage = Double(info.resident_size) / (1024 * 1024) // MB
        }
        
        // Update rendering latency (simulated)
        renderingLatency = Double.random(in: 8...16) // ms
    }
    
    private func checkFirstLaunch() {
        isFirstLaunch = !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        }
    }
    
    func dismissError() {
        errorMessage = nil
        showingErrorAlert = false
    }
    
    func toggleShadeMode() {
        isShadeMode.toggle()
        
        // Notify views to update layout
        NotificationCenter.default.post(
            name: NSNotification.Name("ShadeModeDidChange"),
            object: isShadeMode
        )
    }
}

// MARK: - Menu Commands
struct WinampMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Skin...") {
                NSWorkspace.shared.open(URL(string: "winamp://open-skin")!)
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Button("Open Audio File...") {
                NSWorkspace.shared.open(URL(string: "winamp://open-audio")!)
            }
            .keyboardShortcut("a", modifiers: .command)
            
            Divider()
            
            Button("Skin Library") {
                openWindow(id: "skin-library")
            }
            .keyboardShortcut("l", modifiers: .command)
        }
        
        CommandGroup(after: .windowArrangement) {
            Button("Show Equalizer") {
                // Implementation would show equalizer window
            }
            .keyboardShortcut("e", modifiers: .command)
            
            Button("Show Playlist") {
                // Implementation would show playlist window
            }
            .keyboardShortcut("p", modifiers: .command)
            
            Button("Show Visualization") {
                openWindow(id: "visualization")
            }
            .keyboardShortcut("v", modifiers: .command)
            
            Divider()
            
            Button("Shade Mode") {
                // Implementation would toggle shade mode
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
        
        CommandGroup(after: .toolbar) {
            Button("Always on Top") {
                PreferencesManager.shared.toggleAlwaysOnTop()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }
    }
    
    private func openWindow(id: String) {
        if let url = URL(string: "winamp://window/\(id)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Error Reporter Integration
extension ErrorReporter {
    static let shared = ErrorReporter()
    
    func reportError(_ error: WinampError, context: String) async {
        print("Error reported: \(error) in context: \(context)")
        // Implementation would log to crash reporting service
    }
}

// MARK: - Preferences Manager Extension
extension PreferencesManager {
    static let shared = PreferencesManager()
    
    var alwaysOnTop: Bool {
        get { UserDefaults.standard.bool(forKey: "AlwaysOnTop") }
        set { UserDefaults.standard.set(newValue, forKey: "AlwaysOnTop") }
    }
    
    func toggleAlwaysOnTop() {
        alwaysOnTop.toggle()
        
        // Update all windows
        for window in NSApplication.shared.windows {
            window.level = alwaysOnTop ? .floating : .normal
        }
    }
}
