import SwiftUI
import AppKit

/// Main application entry point for WinampMac
/// Demonstrates the integration of all core components
@main
struct WinampMacApp: App {
    
    @StateObject private var appState = AppState()
    @StateObject private var audioEngine = ModernAudioEngine()
    @StateObject private var windowManager = WinampWindowManager.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(audioEngine)
                .environmentObject(windowManager)
                .environmentObject(performanceMonitor)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            WinampMenuCommands()
        }
    }
}

// MARK: - App State Management
@MainActor
final class AppState: ObservableObject {
    @Published var currentSkin: WinampSkin?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingEqualizerWindow: Bool = false
    @Published var showingPlaylistWindow: Bool = false
    
    private let skinLoader = AsyncSkinLoader()
    
    func loadSkin(from url: URL) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let skin = try await skinLoader.loadSkin(from: url)
            currentSkin = skin
            
            // Apply skin to all windows
            WinampWindowManager.shared.applySkinToAllWindows(skin)
            
        } catch {
            errorMessage = error.localizedDescription
            await ErrorReporter.shared.reportError(
                error as? WinampError ?? .skinLoadingFailed(reason: .invalidArchive),
                context: "Loading skin from file picker"
            )
        }
        
        isLoading = false
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var audioEngine: ModernAudioEngine
    @EnvironmentObject private var windowManager: WinampWindowManager
    @EnvironmentObject private var performanceMonitor: PerformanceMonitor
    
    @State private var showingFilePicker = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            HeaderView()
            
            if appState.isLoading {
                ProgressView("Loading skin...")
                    .scaleEffect(1.2)
            } else if let skin = appState.currentSkin {
                SkinPreviewView(skin: skin)
            } else {
                PlaceholderView()
            }
            
            ControlsView()
            
            Spacer()
            
            StatusView()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.init(filenameExtension: "wsz")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await appState.loadSkin(from: url)
                    }
                }
            case .failure(let error):
                appState.errorMessage = error.localizedDescription
            }
        }
        .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    private func setupInitialState() {
        // Load default skin if available
        if let defaultSkinURL = Bundle.main.url(forResource: "default", withExtension: "wsz") {
            Task {
                await appState.loadSkin(from: defaultSkinURL)
            }
        }
        
        // Create main window
        let mainWindow = windowManager.createMainWindow()
        mainWindow.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Header View
struct HeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "music.note.list")
                .font(.title)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading) {
                Text("WinampMac")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Modern Winamp for macOS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Skin Preview View
struct SkinPreviewView: View {
    let skin: WinampSkin
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Skin: \(skin.name)")
                .font(.headline)
            
            if let mainBitmap = skin.resources.bitmaps["main.bmp"] {
                Image(nsImage: mainBitmap)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .background(Color.black)
                    .cornerRadius(8)
            }
            
            HStack {
                Label("Bitmaps: \(skin.resources.bitmaps.count)", systemImage: "photo")
                Spacer()
                Label("Cursors: \(skin.resources.cursors.count)", systemImage: "cursorarrow")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder View
struct PlaceholderView: View {
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No skin loaded")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Select a Winamp skin (.wsz) file to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Load Skin...") {
                showingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.init(filenameExtension: "wsz")!],
            allowsMultipleSelection: false
        ) { result in
            // This will be handled by the parent view
        }
    }
}

// MARK: - Controls View
struct ControlsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var audioEngine: ModernAudioEngine
    @EnvironmentObject private var windowManager: WinampWindowManager
    
    @State private var showingFilePicker = false
    @State private var showingAudioFilePicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Skin controls
            HStack {
                Button("Load Skin...") {
                    showingFilePicker = true
                }
                
                Spacer()
                
                Button("Default Skin") {
                    loadDefaultSkin()
                }
                .disabled(appState.isLoading)
            }
            
            Divider()
            
            // Audio controls
            HStack {
                Button("Load Audio...") {
                    showingAudioFilePicker = true
                }
                
                Spacer()
                
                Button(audioEngine.isPlaying ? "Pause" : "Play") {
                    if audioEngine.isPlaying {
                        audioEngine.pause()
                    } else {
                        audioEngine.play()
                    }
                }
                .disabled(audioEngine.duration == 0)
                
                Button("Stop") {
                    audioEngine.stop()
                }
                .disabled(!audioEngine.isPlaying && audioEngine.currentTime == 0)
            }
            
            Divider()
            
            // Window controls
            HStack {
                Button("Equalizer") {
                    toggleEqualizerWindow()
                }
                
                Button("Playlist") {
                    togglePlaylistWindow()
                }
                
                Spacer()
                
                Button("Close All") {
                    windowManager.closeAllWindows()
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.init(filenameExtension: "wsz")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await appState.loadSkin(from: url)
                    }
                }
            case .failure(let error):
                appState.errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showingAudioFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        do {
                            try await audioEngine.loadAudioFile(from: url)
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                }
            case .failure(let error):
                appState.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func loadDefaultSkin() {
        if let defaultSkinURL = Bundle.main.url(forResource: "default", withExtension: "wsz") {
            Task {
                await appState.loadSkin(from: defaultSkinURL)
            }
        }
    }
    
    private func toggleEqualizerWindow() {
        if appState.showingEqualizerWindow {
            // Close equalizer window logic
            appState.showingEqualizerWindow = false
        } else {
            let eqWindow = windowManager.createEqualizerWindow(with: appState.currentSkin)
            eqWindow.makeKeyAndOrderFront(nil)
            appState.showingEqualizerWindow = true
        }
    }
    
    private func togglePlaylistWindow() {
        if appState.showingPlaylistWindow {
            // Close playlist window logic
            appState.showingPlaylistWindow = false
        } else {
            let playlistWindow = windowManager.createPlaylistWindow(with: appState.currentSkin)
            playlistWindow.makeKeyAndOrderFront(nil)
            appState.showingPlaylistWindow = true
        }
    }
}

// MARK: - Status View
struct StatusView: View {
    @EnvironmentObject private var audioEngine: ModernAudioEngine
    @EnvironmentObject private var performanceMonitor: PerformanceMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Audio:")
                    .fontWeight(.medium)
                
                if audioEngine.duration > 0 {
                    Text("\(formatTime(audioEngine.currentTime)) / \(formatTime(audioEngine.duration))")
                        .font(.monospaced(.body)())
                } else {
                    Text("No audio loaded")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if audioEngine.isPlaying {
                    Image(systemName: "play.fill")
                        .foregroundColor(.green)
                } else if audioEngine.currentTime > 0 {
                    Image(systemName: "pause.fill")
                        .foregroundColor(.orange)
                }
            }
            
            if !performanceMonitor.warnings.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text("Performance: \(performanceMonitor.warnings.count) warnings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Clear") {
                        performanceMonitor.clearWarnings()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.separatorColor).opacity(0.3))
        .cornerRadius(8)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Menu Commands
struct WinampMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Load Skin...") {
                // Implementation would trigger file picker
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Button("Load Audio...") {
                // Implementation would trigger audio file picker
            }
            .keyboardShortcut("a", modifiers: .command)
        }
        
        CommandGroup(after: .toolbar) {
            Button("Show Equalizer") {
                // Implementation would show equalizer
            }
            .keyboardShortcut("e", modifiers: .command)
            
            Button("Show Playlist") {
                // Implementation would show playlist
            }
            .keyboardShortcut("p", modifiers: .command)
        }
    }
}

