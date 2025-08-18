import SwiftUI
import MetalKit
import AVFoundation
import AppKit
import UniformTypeIdentifiers

/// Main Player View - The core Winamp player interface with Metal-rendered skins
/// Supports full Winamp functionality including skin display, controls, and shade mode
struct MainPlayerView: View {
    @EnvironmentObject private var appManager: AppManager
    @EnvironmentObject private var skinLibrary: SkinLibraryManager
    @EnvironmentObject private var audioPlayer: AudioPlayerManager
    @EnvironmentObject private var visualizationEngine: VisualizationEngine
    @EnvironmentObject private var preferencesManager: PreferencesManager
    
    @State private var showingFilePicker = false
    @State private var showingSkinPicker = false
    @State private var dragHover = false
    @State private var volume: Float = 0.7
    @State private var balance: Float = 0.0
    @State private var seekPosition: Double = 0.0
    @State private var isSeekingActive = false
    
    // Animation states
    @State private var playButtonPressed = false
    @State private var pauseButtonPressed = false
    @State private var stopButtonPressed = false
    @State private var prevButtonPressed = false
    @State private var nextButtonPressed = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundView(for: geometry.size)
                
                if appManager.isShadeMode {
                    shadeModeView(for: geometry.size)
                } else {
                    fullPlayerView(for: geometry.size)
                }
                
                // Loading overlay
                if appManager.isLoadingSkin {
                    loadingOverlay
                }
                
                // First launch overlay
                if appManager.isFirstLaunch && appManager.currentSkin == nil {
                    firstLaunchOverlay
                }
            }
        }
        .frame(
            width: appManager.isShadeMode ? 275 : 275,
            height: appManager.isShadeMode ? 14 : 116
        )
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: appManager.currentSkin?.metadata.windowBorderRadius ?? 0))
        .overlay(
            RoundedRectangle(cornerRadius: appManager.currentSkin?.metadata.windowBorderRadius ?? 0)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(dragHover ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: dragHover)
        .onDrop(of: [.fileURL], isTargeted: $dragHover) { providers in
            handleDrop(providers: providers)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            handleAudioFileSelection(result)
        }
        .fileImporter(
            isPresented: $showingSkinPicker,
            allowedContentTypes: [UTType(filenameExtension: "wsz")!],
            allowsMultipleSelection: false
        ) { result in
            handleSkinFileSelection(result)
        }
        .alert("Error", isPresented: $appManager.showingErrorAlert) {
            Button("OK") {
                appManager.dismissError()
            }
        } message: {
            Text(appManager.errorMessage ?? "")
        }
        .contextMenu {
            contextMenuItems
        }
        .onAppear {
            setupInitialState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SkinDidChange"))) { _ in
            updateUIForNewSkin()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShadeModeDidChange"))) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                // View will automatically resize due to frame changes
            }
        }
    }
    
    // MARK: - Background View
    @ViewBuilder
    private func backgroundView(for size: CGSize) -> some View {
        if let skin = appManager.currentSkin {
            MetalSkinView(skin: skin, size: size, isShadeMode: appManager.isShadeMode)
                .allowsHitTesting(false)
        } else {
            // Default gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.4),
                    Color(red: 0.1, green: 0.2, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Full Player View
    @ViewBuilder
    private func fullPlayerView(for size: CGSize) -> some View {
        VStack(spacing: 0) {
            // Title bar
            titleBarView
                .frame(height: 20)
            
            // Main display area
            HStack(spacing: 0) {
                // Left side - Time display and visualization
                VStack(spacing: 2) {
                    timeDisplayView
                        .frame(height: 20)
                    
                    miniVisualizationView
                        .frame(height: 32)
                }
                .frame(width: 180)
                
                Spacer()
                
                // Right side - Volume and controls
                VStack(spacing: 2) {
                    volumeDisplayView
                        .frame(height: 20)
                    
                    balanceDisplayView
                        .frame(height: 12)
                }
                .frame(width: 90)
            }
            .frame(height: 54)
            .padding(.horizontal, 4)
            
            // Control buttons
            controlButtonsView
                .frame(height: 28)
                .padding(.horizontal, 4)
            
            // Seek bar
            seekBarView
                .frame(height: 14)
                .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Shade Mode View
    @ViewBuilder
    private func shadeModeView(for size: CGSize) -> some View {
        HStack(spacing: 4) {
            // Mini play controls
            HStack(spacing: 2) {
                miniControlButton(
                    action: { audioPlayer.previousTrack() },
                    systemImage: "backward.fill",
                    isPressed: $prevButtonPressed
                )
                
                miniControlButton(
                    action: { togglePlayPause() },
                    systemImage: audioPlayer.isPlaying ? "pause.fill" : "play.fill",
                    isPressed: audioPlayer.isPlaying ? $pauseButtonPressed : $playButtonPressed
                )
                
                miniControlButton(
                    action: { audioPlayer.stop() },
                    systemImage: "stop.fill",
                    isPressed: $stopButtonPressed
                )
                
                miniControlButton(
                    action: { audioPlayer.nextTrack() },
                    systemImage: "forward.fill",
                    isPressed: $nextButtonPressed
                )
            }
            
            // Mini time display
            Text(formatTime(audioPlayer.currentTime))
                .font(.system(size: 8, family: .monospaced))
                .foregroundColor(.white)
                .frame(width: 40)
            
            Spacer()
            
            // Track title (scrolling)
            ScrollingText(
                text: audioPlayer.currentTrack?.title ?? "WinampMac",
                font: .system(size: 8),
                color: .white,
                width: 120
            )
            
            Spacer()
            
            // Shade mode toggle
            Button(action: { appManager.toggleShadeMode() }) {
                Image(systemName: "arrow.down.square")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: 14)
    }
    
    // MARK: - UI Components
    
    private var titleBarView: some View {
        HStack {
            // Menu button
            Button(action: { showMainMenu() }) {
                Image(systemName: "line.horizontal.3")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Track title
            ScrollingText(
                text: audioPlayer.currentTrack?.title ?? "WinampMac - Modern Winamp for macOS",
                font: .system(size: 9, weight: .medium),
                color: .white,
                width: 180
            )
            
            Spacer()
            
            // Window controls
            HStack(spacing: 2) {
                Button(action: { appManager.toggleShadeMode() }) {
                    Image(systemName: appManager.isShadeMode ? "arrow.down.square" : "arrow.up.square")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var timeDisplayView: some View {
        HStack {
            Text(formatTime(audioPlayer.currentTime))
                .font(.system(size: 16, family: .monospaced, design: .monospaced))
                .foregroundColor(.green)
                .background(Color.black)
                .padding(.horizontal, 4)
            
            Spacer()
            
            // Playback mode indicators
            HStack(spacing: 2) {
                if audioPlayer.isRepeatEnabled {
                    Image(systemName: "repeat")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                }
                
                if audioPlayer.isShuffleEnabled {
                    Image(systemName: "shuffle")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                }
            }
        }
    }
    
    private var miniVisualizationView: some View {
        GeometryReader { geometry in
            if audioPlayer.isPlaying {
                VisualizationMiniView(
                    audioData: audioPlayer.currentAudioData,
                    size: geometry.size,
                    style: preferencesManager.miniVisualizationStyle
                )
            } else {
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Text("WinampMac")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    )
            }
        }
        .background(Color.black)
        .border(Color.gray.opacity(0.3), width: 1)
    }
    
    private var volumeDisplayView: some View {
        VStack(spacing: 1) {
            Text("Volume")
                .font(.system(size: 7))
                .foregroundColor(.white)
            
            Slider(value: $volume, in: 0...1) { _ in
                audioPlayer.setVolume(volume)
            }
            .controlSize(.mini)
        }
    }
    
    private var balanceDisplayView: some View {
        VStack(spacing: 1) {
            Text("Balance")
                .font(.system(size: 7))
                .foregroundColor(.white)
            
            Slider(value: $balance, in: -1...1) { _ in
                audioPlayer.setBalance(balance)
            }
            .controlSize(.mini)
        }
    }
    
    private var controlButtonsView: some View {
        HStack(spacing: 8) {
            // Previous
            controlButton(
                action: { audioPlayer.previousTrack() },
                systemImage: "backward.fill",
                isPressed: $prevButtonPressed
            )
            
            // Play/Pause
            controlButton(
                action: { togglePlayPause() },
                systemImage: audioPlayer.isPlaying ? "pause.fill" : "play.fill",
                isPressed: audioPlayer.isPlaying ? $pauseButtonPressed : $playButtonPressed
            )
            
            // Stop
            controlButton(
                action: { audioPlayer.stop() },
                systemImage: "stop.fill",
                isPressed: $stopButtonPressed
            )
            
            // Next
            controlButton(
                action: { audioPlayer.nextTrack() },
                systemImage: "forward.fill",
                isPressed: $nextButtonPressed
            )
            
            Spacer()
            
            // Open file
            Button(action: { showingFilePicker = true }) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            // Equalizer
            Button(action: { appManager.showingEqualizer.toggle() }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10))
                    .foregroundColor(appManager.showingEqualizer ? .yellow : .white)
            }
            .buttonStyle(.plain)
            
            // Playlist
            Button(action: { appManager.showingPlaylist.toggle() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 10))
                    .foregroundColor(appManager.showingPlaylist ? .yellow : .white)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var seekBarView: some View {
        VStack(spacing: 2) {
            HStack {
                Text(formatTime(audioPlayer.currentTime))
                    .font(.system(size: 8, family: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(formatTime(audioPlayer.duration))
                    .font(.system(size: 8, family: .monospaced))
                    .foregroundColor(.white)
            }
            
            Slider(
                value: $seekPosition,
                in: 0...max(1, audioPlayer.duration)
            ) { editing in
                isSeekingActive = editing
                if !editing {
                    audioPlayer.seek(to: seekPosition)
                }
            }
            .controlSize(.mini)
            .disabled(audioPlayer.duration == 0)
        }
        .onReceive(audioPlayer.$currentTime) { time in
            if !isSeekingActive {
                seekPosition = time
            }
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
            
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Loading Skin...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: appManager.skinLoadingProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(width: 200)
                
                Text("\(Int(appManager.skinLoadingProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
    
    private var firstLaunchOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
            
            VStack(spacing: 16) {
                Image(systemName: "music.note.house")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                
                Text("Welcome to WinampMac")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Drop a .wsz skin file here or click below to get started")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    Button("Load Skin") {
                        showingSkinPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Browse Library") {
                        openSkinLibrary()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
    }
    
    private var contextMenuItems: some View {
        Group {
            Button("Load Skin...") {
                showingSkinPicker = true
            }
            
            Button("Load Audio...") {
                showingFilePicker = true
            }
            
            Divider()
            
            Button("Skin Library") {
                openSkinLibrary()
            }
            
            Button("Preferences...") {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
            
            Divider()
            
            Button(appManager.isShadeMode ? "Exit Shade Mode" : "Shade Mode") {
                appManager.toggleShadeMode()
            }
            
            Button("Always on Top") {
                preferencesManager.toggleAlwaysOnTop()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    @ViewBuilder
    private func controlButton(
        action: @escaping () -> Void,
        systemImage: String,
        isPressed: Binding<Bool>
    ) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed.wrappedValue = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed.wrappedValue = false
                }
            }
        }) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isPressed.wrappedValue ? Color.blue : Color.clear)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed.wrappedValue ? 0.95 : 1.0)
    }
    
    @ViewBuilder
    private func miniControlButton(
        action: @escaping () -> Void,
        systemImage: String,
        isPressed: Binding<Bool>
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 6))
                .foregroundColor(.white)
                .frame(width: 12, height: 8)
        }
        .buttonStyle(.plain)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func togglePlayPause() {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.play()
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        
                        DispatchQueue.main.async {
                            if url.pathExtension.lowercased() == "wsz" {
                                Task {
                                    await appManager.loadSkin(from: url)
                                }
                            } else if UTType.audio.conforms(to: UTType(filenameExtension: url.pathExtension)!) {
                                Task {
                                    await audioPlayer.loadAudioFile(from: url)
                                }
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func handleAudioFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    await audioPlayer.loadAudioFile(from: url)
                }
            }
        case .failure(let error):
            appManager.errorMessage = error.localizedDescription
            appManager.showingErrorAlert = true
        }
    }
    
    private func handleSkinFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task {
                    await appManager.loadSkin(from: url)
                }
            }
        case .failure(let error):
            appManager.errorMessage = error.localizedDescription
            appManager.showingErrorAlert = true
        }
    }
    
    private func setupInitialState() {
        // Load last used skin or default
        if let lastSkinPath = UserDefaults.standard.string(forKey: "LastUsedSkinPath"),
           let url = URL(string: lastSkinPath) {
            Task {
                await appManager.loadSkin(from: url)
            }
        } else {
            Task {
                await appManager.loadDefaultSkin()
            }
        }
        
        // Setup audio player
        volume = Float(audioPlayer.volume)
        balance = Float(audioPlayer.balance)
    }
    
    private func updateUIForNewSkin() {
        // Update window properties based on new skin
        if let skin = appManager.currentSkin {
            // Save as last used skin
            UserDefaults.standard.set(skin.sourceURL?.absoluteString, forKey: "LastUsedSkinPath")
        }
    }
    
    private func showMainMenu() {
        let menu = NSMenu()
        
        menu.addItem(withTitle: "Load Skin...", action: #selector(loadSkinAction), keyEquivalent: "")
        menu.addItem(withTitle: "Load Audio...", action: #selector(loadAudioAction), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Skin Library", action: #selector(openSkinLibraryAction), keyEquivalent: "")
        menu.addItem(withTitle: "Preferences...", action: #selector(showPreferencesAction), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "About WinampMac", action: #selector(showAboutAction), keyEquivalent: "")
        
        // Show menu at current mouse position
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSView())
        }
    }
    
    private func openSkinLibrary() {
        // Open skin library window
        if let url = URL(string: "winamp://window/skin-library") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func loadSkinAction() {
        showingSkinPicker = true
    }
    
    @objc private func loadAudioAction() {
        showingFilePicker = true
    }
    
    @objc private func openSkinLibraryAction() {
        openSkinLibrary()
    }
    
    @objc private func showPreferencesAction() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
    
    @objc private func showAboutAction() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

// MARK: - Metal Skin View
struct MetalSkinView: NSViewRepresentable {
    let skin: WinampSkin
    let size: CGSize
    let isShadeMode: Bool
    
    func makeNSView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = false
        metalView.preferredFramesPerSecond = 60
        
        // Configure for skin rendering
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalView.colorPixelFormat = .bgra8Unorm
        
        return metalView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.updateSkin(skin, size: size, isShadeMode: isShadeMode)
    }
    
    func makeCoordinator() -> MetalSkinRenderer {
        return MetalSkinRenderer()
    }
}

// MARK: - Scrolling Text View
struct ScrollingText: View {
    let text: String
    let font: Font
    let color: Color
    let width: CGFloat
    
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Text(text)
                .font(font)
                .foregroundColor(color)
                .fixedSize()
                .offset(x: offset)
                .background(
                    GeometryReader { textGeometry in
                        Color.clear
                            .onAppear {
                                textWidth = textGeometry.size.width
                                startScrolling()
                            }
                            .onChange(of: text) { _ in
                                textWidth = textGeometry.size.width
                                startScrolling()
                            }
                    }
                )
        }
        .frame(width: width)
        .clipped()
    }
    
    private func startScrolling() {
        offset = width
        
        guard textWidth > width else { return }
        
        withAnimation(.linear(duration: Double(textWidth + width) / 30)) {
            offset = -textWidth
        }
        
        // Restart animation when complete
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(textWidth + width) / 30 + 2) {
            startScrolling()
        }
    }
}

// MARK: - Visualization Mini View
struct VisualizationMiniView: View {
    let audioData: [Float]
    let size: CGSize
    let style: VisualizationStyle
    
    var body: some View {
        Canvas { context, size in
            switch style {
            case .spectrum:
                drawSpectrum(context: context, size: size)
            case .oscilloscope:
                drawOscilloscope(context: context, size: size)
            case .bars:
                drawBars(context: context, size: size)
            }
        }
    }
    
    private func drawSpectrum(context: GraphicsContext, size: CGSize) {
        let barWidth = size.width / CGFloat(audioData.count)
        
        for (index, value) in audioData.enumerated() {
            let barHeight = CGFloat(value) * size.height
            let x = CGFloat(index) * barWidth
            let rect = CGRect(x: x, y: size.height - barHeight, width: barWidth - 1, height: barHeight)
            
            context.fill(
                Path(rect),
                with: .color(.green)
            )
        }
    }
    
    private func drawOscilloscope(context: GraphicsContext, size: CGSize) {
        var path = Path()
        let stepX = size.width / CGFloat(audioData.count - 1)
        
        for (index, value) in audioData.enumerated() {
            let x = CGFloat(index) * stepX
            let y = size.height / 2 + CGFloat(value) * size.height / 4
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.stroke(path, with: .color(.green), lineWidth: 1)
    }
    
    private func drawBars(context: GraphicsContext, size: CGSize) {
        let barCount = min(audioData.count, 20)
        let barWidth = size.width / CGFloat(barCount)
        
        for i in 0..<barCount {
            let value = audioData[i * audioData.count / barCount]
            let barHeight = CGFloat(value) * size.height
            let x = CGFloat(i) * barWidth
            let rect = CGRect(x: x, y: size.height - barHeight, width: barWidth - 2, height: barHeight)
            
            let color = Color(
                hue: Double(i) / Double(barCount),
                saturation: 1.0,
                brightness: 1.0
            )
            
            context.fill(Path(rect), with: .color(color))
        }
    }
}

enum VisualizationStyle: CaseIterable {
    case spectrum
    case oscilloscope
    case bars
    
    var displayName: String {
        switch self {
        case .spectrum: return "Spectrum"
        case .oscilloscope: return "Oscilloscope"
        case .bars: return "Bars"
        }
    }
}
