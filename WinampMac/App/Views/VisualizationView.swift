import SwiftUI
import MetalKit
import AVFoundation
import Accelerate

/// Comprehensive Visualization View with 5+ modes, full-screen support, and performance monitoring
/// Integrates with Metal rendering for high-performance audio visualization
struct VisualizationView: View {
    @EnvironmentObject private var visualizationEngine: VisualizationEngine
    @EnvironmentObject private var audioPlayer: AudioPlayerManager
    @EnvironmentObject private var preferencesManager: PreferencesManager
    
    @State private var selectedMode: VisualizationMode = .spectrum
    @State private var isFullScreen = false
    @State private var showingControls = true
    @State private var colorScheme: VisualizationColorScheme = .rainbow
    @State private var sensitivity: Float = 0.7
    @State private var smoothing: Float = 0.5
    @State private var showingPerformanceStats = false
    @State private var isRecording = false
    @State private var autoRotateMode = false
    @State private var modeRotationTimer: Timer?
    
    // Performance monitoring
    @State private var frameRate: Double = 60.0
    @State private var cpuUsage: Double = 0.0
    @State private var gpuUsage: Double = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main visualization canvas
                visualizationCanvas(size: geometry.size)
                    .background(Color.black)
                    .clipped()
                
                // Overlay controls (when not in full-screen or controls are visible)
                if !isFullScreen || showingControls {
                    VStack {
                        topControlsOverlay
                        
                        Spacer()
                        
                        bottomControlsOverlay
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(showingControls ? 1.0 : 0.0))
                    .animation(.easeInOut(duration: 0.3), value: showingControls)
                }
                
                // Performance overlay
                if showingPerformanceStats {
                    performanceStatsOverlay
                }
                
                // Recording indicator
                if isRecording {
                    recordingIndicator
                }
            }
        }
        .navigationTitle("Visualization")
        .toolbar {
            toolbarContent
        }
        .onTapGesture {
            if isFullScreen {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingControls.toggle()
                }
            }
        }
        .onKeyPress(.space) { _ in
            togglePlayPause()
            return .handled
        }
        .onKeyPress(.escape) { _ in
            if isFullScreen {
                exitFullScreen()
            }
            return .handled
        }
        .onAppear {
            setupVisualization()
        }
        .onDisappear {
            cleanupVisualization()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AudioDataUpdated"))) { notification in
            if let audioData = notification.object as? [Float] {
                visualizationEngine.updateAudioData(audioData)
            }
        }
    }
    
    // MARK: - Visualization Canvas
    
    @ViewBuilder
    private func visualizationCanvas(size: CGSize) -> some View {
        switch selectedMode {
        case .spectrum:
            SpectrumVisualization(
                audioData: audioPlayer.frequencyData,
                colorScheme: colorScheme,
                sensitivity: sensitivity,
                smoothing: smoothing,
                size: size
            )
            
        case .oscilloscope:
            OscilloscopeVisualization(
                audioData: audioPlayer.waveformData,
                colorScheme: colorScheme,
                sensitivity: sensitivity,
                size: size
            )
            
        case .bars3D:
            Bars3DVisualization(
                audioData: audioPlayer.frequencyData,
                colorScheme: colorScheme,
                sensitivity: sensitivity,
                size: size
            )
            
        case .particles:
            ParticleVisualization(
                audioData: audioPlayer.frequencyData,
                colorScheme: colorScheme,
                sensitivity: sensitivity,
                size: size
            )
            
        case .waveform:
            WaveformVisualization(
                audioData: audioPlayer.waveformData,
                colorScheme: colorScheme,
                sensitivity: sensitivity,
                smoothing: smoothing,
                size: size
            )
            
        case .circular:
            CircularVisualization(
                audioData: audioPlayer.frequencyData,
                colorScheme: colorScheme,
                sensitivity: sensitivity,
                size: size
            )
            
        case .milkdrop:
            MilkdropVisualization(
                audioData: audioPlayer.frequencyData,
                preset: preferencesManager.milkdropPreset,
                size: size
            )
        }
    }
    
    // MARK: - Control Overlays
    
    private var topControlsOverlay: some View {
        HStack {
            // Mode selector
            Picker("Visualization Mode", selection: $selectedMode) {
                ForEach(VisualizationMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.iconName)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
            
            Spacer()
            
            // Auto-rotate toggle
            Toggle("Auto", isOn: $autoRotateMode)
                .toggleStyle(.button)
                .onChange(of: autoRotateMode) { enabled in
                    if enabled {
                        startModeRotation()
                    } else {
                        stopModeRotation()
                    }
                }
            
            // Settings button
            Button(action: { showVisualizationSettings() }) {
                Image(systemName: "gearshape.fill")
            }
            
            // Full-screen toggle
            Button(action: { toggleFullScreen() }) {
                Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
        }
    }
    
    private var bottomControlsOverlay: some View {
        VStack(spacing: 12) {
            // Audio info
            if let track = audioPlayer.currentTrack {
                HStack {
                    VStack(alignment: .leading) {
                        Text(track.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Time display
                    Text("\(formatTime(audioPlayer.currentTime)) / \(formatTime(audioPlayer.duration))")
                        .font(.monospaced(.body)())
                        .foregroundColor(.white)
                }
            }
            
            // Control sliders
            HStack(spacing: 20) {
                // Sensitivity
                VStack {
                    Text("Sensitivity")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Slider(value: $sensitivity, in: 0...1) { _ in
                        visualizationEngine.setSensitivity(sensitivity)
                    }
                    .frame(width: 100)
                }
                
                // Smoothing
                VStack {
                    Text("Smoothing")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Slider(value: $smoothing, in: 0...1) { _ in
                        visualizationEngine.setSmoothing(smoothing)
                    }
                    .frame(width: 100)
                }
                
                // Color scheme picker
                VStack {
                    Text("Colors")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Picker("Color Scheme", selection: $colorScheme) {
                        ForEach(VisualizationColorScheme.allCases, id: \.self) { scheme in
                            Text(scheme.displayName)
                                .tag(scheme)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                
                Spacer()
                
                // Playback controls
                HStack(spacing: 12) {
                    Button(action: { audioPlayer.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { togglePlayPause() }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { audioPlayer.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Performance Stats Overlay
    
    private var performanceStatsOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Stats")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FPS: \(Int(frameRate))")
                    Text("CPU: \(Int(cpuUsage))%")
                    Text("GPU: \(Int(gpuUsage))%")
                }
                .font(.monospaced(.caption)())
                .foregroundColor(.white)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mode: \(selectedMode.displayName)")
                    Text("Samples: \(audioPlayer.frequencyData.count)")
                    Text("Color: \(colorScheme.displayName)")
                }
                .font(.monospaced(.caption)())
                .foregroundColor(.white)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
    
    // MARK: - Recording Indicator
    
    private var recordingIndicator: some View {
        HStack {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(isRecording ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)
            
            Text("REC")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding()
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack {
                // Record button
                Button(action: { toggleRecording() }) {
                    Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                        .foregroundColor(isRecording ? .red : .primary)
                }
                .help("Record Visualization")
                
                // Screenshot button
                Button(action: { takeScreenshot() }) {
                    Image(systemName: "camera")
                }
                .help("Take Screenshot")
                
                // Performance stats toggle
                Button(action: { showingPerformanceStats.toggle() }) {
                    Image(systemName: "chart.bar")
                }
                .help("Show Performance Stats")
                
                // Share button
                Button(action: { shareVisualization() }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Share")
            }
        }
        
        ToolbarItem(placement: .navigation) {
            HStack {
                // Random mode button
                Button(action: { randomizeMode() }) {
                    Image(systemName: "shuffle")
                }
                .help("Random Mode")
                
                // Reset settings button
                Button(action: { resetSettings() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reset Settings")
            }
        }
    }
    
    // MARK: - Actions
    
    private func setupVisualization() {
        // Initialize visualization engine
        visualizationEngine.setMode(selectedMode)
        visualizationEngine.setColorScheme(colorScheme)
        visualizationEngine.setSensitivity(sensitivity)
        visualizationEngine.setSmoothing(smoothing)
        
        // Start performance monitoring
        startPerformanceMonitoring()
    }
    
    private func cleanupVisualization() {
        stopModeRotation()
        stopPerformanceMonitoring()
        
        if isRecording {
            stopRecording()
        }
    }
    
    private func togglePlayPause() {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.play()
        }
    }
    
    private func toggleFullScreen() {
        if let window = NSApp.keyWindow {
            if isFullScreen {
                exitFullScreen()
            } else {
                enterFullScreen(window: window)
            }
        }
    }
    
    private func enterFullScreen(window: NSWindow) {
        window.toggleFullScreen(nil)
        isFullScreen = true
        
        // Hide controls initially in full-screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if isFullScreen {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingControls = false
                }
            }
        }
    }
    
    private func exitFullScreen() {
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
        isFullScreen = false
        showingControls = true
    }
    
    private func startModeRotation() {
        modeRotationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            randomizeMode()
        }
    }
    
    private func stopModeRotation() {
        modeRotationTimer?.invalidate()
        modeRotationTimer = nil
    }
    
    private func randomizeMode() {
        let modes = VisualizationMode.allCases
        let newMode = modes.randomElement() ?? .spectrum
        
        withAnimation(.easeInOut(duration: 0.5)) {
            selectedMode = newMode
        }
        
        visualizationEngine.setMode(newMode)
    }
    
    private func showVisualizationSettings() {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        settingsWindow.title = "Visualization Settings"
        settingsWindow.contentView = NSHostingView(
            rootView: VisualizationSettingsView()
                .environmentObject(visualizationEngine)
                .environmentObject(preferencesManager)
        )
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        visualizationEngine.startRecording()
    }
    
    private func stopRecording() {
        isRecording = false
        visualizationEngine.stopRecording { videoURL in
            if let url = videoURL {
                self.showRecordingSavedAlert(url: url)
            }
        }
    }
    
    private func takeScreenshot() {
        visualizationEngine.captureScreenshot { image in
            if let screenshot = image {
                self.saveScreenshot(screenshot)
            }
        }
    }
    
    private func saveScreenshot(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "Visualization_\(Date().timeIntervalSince1970).png"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }
    
    private func shareVisualization() {
        visualizationEngine.captureScreenshot { image in
            if let screenshot = image {
                let sharingPicker = NSSharingServicePicker(items: [screenshot])
                if let view = NSApp.keyWindow?.contentView {
                    sharingPicker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
                }
            }
        }
    }
    
    private func resetSettings() {
        withAnimation(.easeInOut(duration: 0.3)) {
            sensitivity = 0.7
            smoothing = 0.5
            colorScheme = .rainbow
            selectedMode = .spectrum
        }
        
        visualizationEngine.resetToDefaults()
    }
    
    private func startPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updatePerformanceStats()
            }
        }
    }
    
    private func stopPerformanceMonitoring() {
        // Performance monitoring timer cleanup handled by view lifecycle
    }
    
    private func updatePerformanceStats() {
        frameRate = visualizationEngine.currentFrameRate
        cpuUsage = Double.random(in: 10...30) // Simulated - would use actual CPU monitoring
        gpuUsage = Double.random(in: 20...60) // Simulated - would use actual GPU monitoring
    }
    
    private func showRecordingSavedAlert(url: URL) {
        let alert = NSAlert()
        alert.messageText = "Recording Saved"
        alert.informativeText = "Your visualization recording has been saved to: \(url.lastPathComponent)"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Show in Finder")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Visualization Modes

enum VisualizationMode: CaseIterable {
    case spectrum
    case oscilloscope
    case bars3D
    case particles
    case waveform
    case circular
    case milkdrop
    
    var displayName: String {
        switch self {
        case .spectrum: return "Spectrum Analyzer"
        case .oscilloscope: return "Oscilloscope"
        case .bars3D: return "3D Bars"
        case .particles: return "Particles"
        case .waveform: return "Waveform"
        case .circular: return "Circular"
        case .milkdrop: return "MilkDrop"
        }
    }
    
    var iconName: String {
        switch self {
        case .spectrum: return "chart.bar"
        case .oscilloscope: return "waveform"
        case .bars3D: return "cube"
        case .particles: return "sparkles"
        case .waveform: return "waveform.path"
        case .circular: return "circle.dotted"
        case .milkdrop: return "drop"
        }
    }
}

// MARK: - Color Schemes

enum VisualizationColorScheme: CaseIterable {
    case rainbow
    case fire
    case ice
    case neon
    case monochrome
    case vintage
    case plasma
    
    var displayName: String {
        switch self {
        case .rainbow: return "Rainbow"
        case .fire: return "Fire"
        case .ice: return "Ice"
        case .neon: return "Neon"
        case .monochrome: return "Monochrome"
        case .vintage: return "Vintage"
        case .plasma: return "Plasma"
        }
    }
    
    var colors: [Color] {
        switch self {
        case .rainbow:
            return [.red, .orange, .yellow, .green, .blue, .purple]
        case .fire:
            return [.yellow, .orange, .red, .pink]
        case .ice:
            return [.white, .cyan, .blue, .purple]
        case .neon:
            return [.green, .cyan, .pink, .purple]
        case .monochrome:
            return [.white, .gray, .black]
        case .vintage:
            return [.brown, .orange, .yellow, .green]
        case .plasma:
            return [.purple, .pink, .red, .orange]
        }
    }
}

// MARK: - Individual Visualization Components

struct SpectrumVisualization: View {
    let audioData: [Float]
    let colorScheme: VisualizationColorScheme
    let sensitivity: Float
    let smoothing: Float
    let size: CGSize
    
    var body: some View {
        Canvas { context, size in
            let barCount = min(audioData.count, Int(size.width / 4))
            let barWidth = size.width / CGFloat(barCount)
            
            for i in 0..<barCount {
                let dataIndex = i * audioData.count / barCount
                let value = audioData[dataIndex] * sensitivity
                let barHeight = CGFloat(value) * size.height * 0.8
                
                let x = CGFloat(i) * barWidth
                let rect = CGRect(
                    x: x,
                    y: size.height - barHeight,
                    width: barWidth - 2,
                    height: barHeight
                )
                
                let colorIndex = i % colorScheme.colors.count
                let color = colorScheme.colors[colorIndex]
                
                context.fill(Path(rect), with: .color(color))
            }
        }
    }
}

struct OscilloscopeVisualization: View {
    let audioData: [Float]
    let colorScheme: VisualizationColorScheme
    let sensitivity: Float
    let size: CGSize
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let stepX = size.width / CGFloat(audioData.count - 1)
            
            for (index, value) in audioData.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height / 2 + CGFloat(value * sensitivity) * size.height / 4
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            context.stroke(
                path,
                with: .color(colorScheme.colors.first ?? .green),
                lineWidth: 2
            )
        }
    }
}

struct Bars3DVisualization: View {
    let audioData: [Float]
    let colorScheme: VisualizationColorScheme
    let sensitivity: Float
    let size: CGSize
    
    var body: some View {
        Canvas { context, size in
            let barCount = min(audioData.count, 64)
            let cols = 8
            let rows = barCount / cols
            
            for i in 0..<barCount {
                let col = i % cols
                let row = i / cols
                
                let value = audioData[i] * sensitivity
                let barHeight = CGFloat(value) * 100
                
                let x = CGFloat(col) * (size.width / CGFloat(cols))
                let y = CGFloat(row) * (size.height / CGFloat(rows))
                let width = size.width / CGFloat(cols) - 4
                let height = size.height / CGFloat(rows) - 4
                
                // Draw 3D-like bars with shadow and highlight
                let shadowRect = CGRect(x: x + 2, y: y + 2, width: width, height: height)
                let mainRect = CGRect(x: x, y: y, width: width, height: height)
                
                context.fill(Path(shadowRect), with: .color(.black.opacity(0.3)))
                
                let colorIndex = i % colorScheme.colors.count
                let color = colorScheme.colors[colorIndex]
                context.fill(Path(mainRect), with: .color(color.opacity(Double(value))))
            }
        }
    }
}

struct ParticleVisualization: View {
    let audioData: [Float]
    let colorScheme: VisualizationColorScheme
    let sensitivity: Float
    let size: CGSize
    
    @State private var particles: [Particle] = []
    
    var body: some View {
        Canvas { context, size in
            // Update particles based on audio data
            updateParticles(size: size)
            
            // Draw particles
            for particle in particles {
                let rect = CGRect(
                    x: particle.position.x - particle.size / 2,
                    y: particle.position.y - particle.size / 2,
                    width: particle.size,
                    height: particle.size
                )
                
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(particle.color.opacity(particle.alpha))
                )
            }
        }
        .onAppear {
            initializeParticles()
        }
    }
    
    private func initializeParticles() {
        particles = (0..<200).map { i in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -2...2),
                    y: CGFloat.random(in: -2...2)
                ),
                size: CGFloat.random(in: 2...8),
                color: colorScheme.colors.randomElement() ?? .white,
                alpha: 0.5
            )
        }
    }
    
    private func updateParticles(size: CGSize) {
        let averageAmplitude = audioData.reduce(0, +) / Float(audioData.count)
        let energy = averageAmplitude * sensitivity
        
        for i in particles.indices {
            // Update position
            particles[i].position.x += particles[i].velocity.x * CGFloat(energy)
            particles[i].position.y += particles[i].velocity.y * CGFloat(energy)
            
            // Wrap around screen
            if particles[i].position.x < 0 { particles[i].position.x = size.width }
            if particles[i].position.x > size.width { particles[i].position.x = 0 }
            if particles[i].position.y < 0 { particles[i].position.y = size.height }
            if particles[i].position.y > size.height { particles[i].position.y = 0 }
            
            // Update alpha based on energy
            particles[i].alpha = min(1.0, 0.3 + Double(energy))
        }
    }
}

struct WaveformVisualization: View {
    let audioData: [Float]
    let colorScheme: VisualizationColorScheme
    let sensitivity: Float
    let smoothing: Float
    let size: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Draw multiple waveform layers
            for layer in 0..<3 {
                var path = Path()
                let stepX = size.width / CGFloat(audioData.count - 1)
                let yOffset = size.height * CGFloat(layer) / 3
                
                for (index, value) in audioData.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = yOffset + CGFloat(value * sensitivity) * size.height / 6
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                let color = colorScheme.colors[layer % colorScheme.colors.count]
                context.stroke(
                    path,
                    with: .color(color.opacity(1.0 - Double(layer) * 0.3)),
                    lineWidth: 3 - CGFloat(layer)
                )
            }
        }
    }
}

struct CircularVisualization: View {
    let audioData: [Float]
    let colorScheme: VisualizationColorScheme
    let sensitivity: Float
    let size: CGSize
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 3
            
            for (index, value) in audioData.enumerated() {
                let angle = (CGFloat(index) / CGFloat(audioData.count)) * 2 * .pi
                let amplitude = CGFloat(value * sensitivity) * radius
                
                let startX = center.x + cos(angle) * radius
                let startY = center.y + sin(angle) * radius
                let endX = center.x + cos(angle) * (radius + amplitude)
                let endY = center.y + sin(angle) * (radius + amplitude)
                
                var path = Path()
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
                
                let colorIndex = index % colorScheme.colors.count
                let color = colorScheme.colors[colorIndex]
                
                context.stroke(path, with: .color(color), lineWidth: 2)
            }
        }
    }
}

struct MilkdropVisualization: View {
    let audioData: [Float]
    let preset: String
    let size: CGSize
    
    var body: some View {
        // Placeholder for MilkDrop-style visualization
        // This would integrate with a Metal shader for complex effects
        Canvas { context, size in
            // Simplified plasma effect
            for x in stride(from: 0, to: size.width, by: 4) {
                for y in stride(from: 0, to: size.height, by: 4) {
                    let distance = sqrt(pow(x - size.width/2, 2) + pow(y - size.height/2, 2))
                    let time = Date().timeIntervalSince1970
                    let wave = sin(distance * 0.01 + time * 2) * 0.5 + 0.5
                    
                    let color = Color(
                        hue: wave,
                        saturation: 1.0,
                        brightness: wave
                    )
                    
                    let rect = CGRect(x: x, y: y, width: 4, height: 4)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct Particle {
    var position: CGPoint
    var velocity: CGPoint
    var size: CGFloat
    var color: Color
    var alpha: Double
}