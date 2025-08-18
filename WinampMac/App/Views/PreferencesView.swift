import SwiftUI
import AppKit

/// Comprehensive Preferences View with tabbed interface for all app settings
/// Covers general, audio, visualization, performance, and advanced settings
struct PreferencesView: View {
    @EnvironmentObject private var preferencesManager: PreferencesManager
    @EnvironmentObject private var skinLibrary: SkinLibraryManager
    @EnvironmentObject private var audioPlayer: AudioPlayerManager
    @EnvironmentObject private var visualizationEngine: VisualizationEngine
    
    @State private var selectedTab: PreferencesTab = .general
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPreferencesView()
                .environmentObject(preferencesManager)
                .environmentObject(skinLibrary)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(PreferencesTab.general)
            
            AudioPreferencesView()
                .environmentObject(preferencesManager)
                .environmentObject(audioPlayer)
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.3")
                }
                .tag(PreferencesTab.audio)
            
            VisualizationPreferencesView()
                .environmentObject(preferencesManager)
                .environmentObject(visualizationEngine)
                .tabItem {
                    Label("Visualization", systemImage: "waveform")
                }
                .tag(PreferencesTab.visualization)
            
            PerformancePreferencesView()
                .environmentObject(preferencesManager)
                .tabItem {
                    Label("Performance", systemImage: "speedometer")
                }
                .tag(PreferencesTab.performance)
            
            AdvancedPreferencesView()
                .environmentObject(preferencesManager)
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .tag(PreferencesTab.advanced)
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - General Preferences

struct GeneralPreferencesView: View {
    @EnvironmentObject private var preferencesManager: PreferencesManager
    @EnvironmentObject private var skinLibrary: SkinLibraryManager
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at startup", isOn: $preferencesManager.launchAtStartup)
                    .onChange(of: preferencesManager.launchAtStartup) { enabled in
                        setLaunchAtStartup(enabled)
                    }
                
                Toggle("Restore last session", isOn: $preferencesManager.restoreLastSession)
                
                Picker("Default skin", selection: $preferencesManager.defaultSkinID) {
                    Text("None").tag(String?.none)
                    ForEach(skinLibrary.skins) { skin in
                        Text(skin.name).tag(String?.some(skin.id.uuidString))
                    }
                }
            }
            
            Section("Window Behavior") {
                Toggle("Always on top", isOn: $preferencesManager.alwaysOnTop)
                    .onChange(of: preferencesManager.alwaysOnTop) { _ in
                        updateWindowLevels()
                    }
                
                Toggle("Hide dock icon", isOn: $preferencesManager.hideDockIcon)
                    .onChange(of: preferencesManager.hideDockIcon) { hide in
                        setDockIconVisibility(!hide)
                    }
                
                Toggle("Minimize to menu bar", isOn: $preferencesManager.minimizeToMenuBar)
                
                Toggle("Show in all spaces", isOn: $preferencesManager.showInAllSpaces)
                    .onChange(of: preferencesManager.showInAllSpaces) { _ in
                        updateWindowBehavior()
                    }
            }
            
            Section("Interface") {
                Picker("Theme", selection: $preferencesManager.interfaceTheme) {
                    Text("System").tag(InterfaceTheme.system)
                    Text("Light").tag(InterfaceTheme.light)
                    Text("Dark").tag(InterfaceTheme.dark)
                }
                .onChange(of: preferencesManager.interfaceTheme) { theme in
                    applyInterfaceTheme(theme)
                }
                
                Slider(
                    value: $preferencesManager.interfaceScale,
                    in: 0.8...2.0,
                    step: 0.1
                ) {
                    Text("Interface Scale")
                } minimumValueLabel: {
                    Text("80%")
                } maximumValueLabel: {
                    Text("200%")
                }
                
                Toggle("Show tooltips", isOn: $preferencesManager.showTooltips)
                
                Toggle("Animate interface", isOn: $preferencesManager.animateInterface)
            }
            
            Section("File Associations") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Associated file types:")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(AudioFileType.allCases, id: \.self) { fileType in
                            Toggle(fileType.displayName, isOn: bindingForFileType(fileType))
                                .onChange(of: bindingForFileType(fileType).wrappedValue) { enabled in
                                    setFileAssociation(fileType, enabled: enabled)
                                }
                        }
                    }
                    
                    HStack {
                        Button("Select All") {
                            setAllFileAssociations(true)
                        }
                        
                        Button("Select None") {
                            setAllFileAssociations(false)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
    }
    
    private func bindingForFileType(_ fileType: AudioFileType) -> Binding<Bool> {
        Binding(
            get: { preferencesManager.associatedFileTypes.contains(fileType) },
            set: { enabled in
                if enabled {
                    preferencesManager.associatedFileTypes.insert(fileType)
                } else {
                    preferencesManager.associatedFileTypes.remove(fileType)
                }
            }
        )
    }
    
    private func setLaunchAtStartup(_ enabled: Bool) {
        // Implementation would configure launch agent
        print("Launch at startup: \(enabled)")
    }
    
    private func updateWindowLevels() {
        for window in NSApplication.shared.windows {
            window.level = preferencesManager.alwaysOnTop ? .floating : .normal
        }
    }
    
    private func setDockIconVisibility(_ visible: Bool) {
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
    }
    
    private func updateWindowBehavior() {
        for window in NSApplication.shared.windows {
            if preferencesManager.showInAllSpaces {
                window.collectionBehavior.insert(.canJoinAllSpaces)
            } else {
                window.collectionBehavior.remove(.canJoinAllSpaces)
            }
        }
    }
    
    private func applyInterfaceTheme(_ theme: InterfaceTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
    
    private func setFileAssociation(_ fileType: AudioFileType, enabled: Bool) {
        // Implementation would register/unregister file associations
        print("File association for \(fileType.displayName): \(enabled)")
    }
    
    private func setAllFileAssociations(_ enabled: Bool) {
        if enabled {
            preferencesManager.associatedFileTypes = Set(AudioFileType.allCases)
        } else {
            preferencesManager.associatedFileTypes.removeAll()
        }
    }
}

// MARK: - Audio Preferences

struct AudioPreferencesView: View {
    @EnvironmentObject private var preferencesManager: PreferencesManager
    @EnvironmentObject private var audioPlayer: AudioPlayerManager
    
    @State private var selectedOutputDevice: String = ""
    @State private var availableOutputDevices: [String] = []
    @State private var selectedEqualizerPreset: String = "Flat"
    
    var body: some View {
        Form {
            Section("Output") {
                Picker("Output Device", selection: $selectedOutputDevice) {
                    ForEach(availableOutputDevices, id: \.self) { device in
                        Text(device).tag(device)
                    }
                }
                .onAppear {
                    loadAvailableOutputDevices()
                }
                
                HStack {
                    Text("Buffer Size")
                    Spacer()
                    Picker("Buffer Size", selection: $preferencesManager.audioBufferSize) {
                        Text("64 samples").tag(64)
                        Text("128 samples").tag(128)
                        Text("256 samples").tag(256)
                        Text("512 samples").tag(512)
                        Text("1024 samples").tag(1024)
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Text("Sample Rate")
                    Spacer()
                    Picker("Sample Rate", selection: $preferencesManager.sampleRate) {
                        Text("44.1 kHz").tag(44100)
                        Text("48 kHz").tag(48000)
                        Text("88.2 kHz").tag(88200)
                        Text("96 kHz").tag(96000)
                        Text("192 kHz").tag(192000)
                    }
                    .pickerStyle(.menu)
                }
            }
            
            Section("Equalizer") {
                Toggle("Enable Equalizer", isOn: $audioPlayer.isEqualizerEnabled)
                    .onChange(of: audioPlayer.isEqualizerEnabled) { enabled in
                        audioPlayer.setEqualizerEnabled(enabled)
                    }
                
                if audioPlayer.isEqualizerEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Preset:")
                            Picker("Equalizer Preset", selection: $selectedEqualizerPreset) {
                                ForEach(EqualizerPreset.presets, id: \.name) { preset in
                                    Text(preset.name).tag(preset.name)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedEqualizerPreset) { presetName in
                                if let preset = EqualizerPreset.presets.first(where: { $0.name == presetName }) {
                                    audioPlayer.loadEqualizerPreset(preset)
                                }
                            }
                            
                            Spacer()
                            
                            Button("Reset") {
                                audioPlayer.resetEqualizer()
                            }
                        }
                        
                        // Equalizer bands
                        HStack(spacing: 8) {
                            ForEach(0..<audioPlayer.equalizerBands.count, id: \.self) { index in
                                VStack {
                                    Text("\(frequencyLabels[index])")
                                        .font(.caption2)
                                        .frame(width: 40)
                                    
                                    Slider(
                                        value: Binding(
                                            get: { audioPlayer.equalizerBands[index] },
                                            set: { value in
                                                audioPlayer.setEqualizerBand(index, gain: value)
                                            }
                                        ),
                                        in: -12...12,
                                        step: 0.5
                                    ) {
                                        Text("Band \(index + 1)")
                                    }
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 40, height: 150)
                                    
                                    Text("\(Int(audioPlayer.equalizerBands[index]))dB")
                                        .font(.caption2)
                                        .frame(width: 40)
                                }
                            }
                        }
                    }
                }
            }
            
            Section("Playback") {
                Toggle("Crossfade between tracks", isOn: $preferencesManager.crossfadeEnabled)
                
                if preferencesManager.crossfadeEnabled {
                    HStack {
                        Text("Crossfade Duration")
                        Spacer()
                        Slider(
                            value: $preferencesManager.crossfadeDuration,
                            in: 0.5...10.0,
                            step: 0.5
                        ) {
                            Text("Duration")
                        }
                        Text("\(preferencesManager.crossfadeDuration, specifier: "%.1f")s")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                
                Toggle("Gapless playback", isOn: $preferencesManager.gaplessPlayback)
                
                Toggle("Auto-normalize volume", isOn: $preferencesManager.autoNormalize)
                
                HStack {
                    Text("Replay Gain")
                    Spacer()
                    Picker("Replay Gain", selection: $preferencesManager.replayGainMode) {
                        Text("Off").tag(ReplayGainMode.off)
                        Text("Track").tag(ReplayGainMode.track)
                        Text("Album").tag(ReplayGainMode.album)
                    }
                    .pickerStyle(.menu)
                }
            }
            
            Section("Format Support") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enabled audio formats:")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(AudioFormat.allCases, id: \.self) { format in
                            Toggle(format.displayName, isOn: bindingForAudioFormat(format))
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private let frequencyLabels = ["31", "62", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
    
    private func bindingForAudioFormat(_ format: AudioFormat) -> Binding<Bool> {
        Binding(
            get: { preferencesManager.enabledAudioFormats.contains(format) },
            set: { enabled in
                if enabled {
                    preferencesManager.enabledAudioFormats.insert(format)
                } else {
                    preferencesManager.enabledAudioFormats.remove(format)
                }
            }
        )
    }
    
    private func loadAvailableOutputDevices() {
        // Implementation would query available audio output devices
        availableOutputDevices = ["Built-in Output", "USB Audio Device", "AirPods Pro"]
        selectedOutputDevice = availableOutputDevices.first ?? ""
    }
}

// MARK: - Visualization Preferences

struct VisualizationPreferencesView: View {
    @EnvironmentObject private var preferencesManager: PreferencesManager
    @EnvironmentObject private var visualizationEngine: VisualizationEngine
    
    var body: some View {
        Form {
            Section("General") {
                Picker("Default visualization", selection: $preferencesManager.defaultVisualizationMode) {
                    ForEach(VisualizationMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                
                Picker("Default color scheme", selection: $preferencesManager.defaultColorScheme) {
                    ForEach(VisualizationColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }
                
                Toggle("Auto-rotate modes", isOn: $preferencesManager.autoRotateModes)
                
                if preferencesManager.autoRotateModes {
                    HStack {
                        Text("Rotation interval")
                        Spacer()
                        Slider(
                            value: $preferencesManager.modeRotationInterval,
                            in: 5...120,
                            step: 5
                        ) {
                            Text("Interval")
                        }
                        Text("\(Int(preferencesManager.modeRotationInterval))s")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            
            Section("Performance") {
                HStack {
                    Text("Frame Rate Limit")
                    Spacer()
                    Picker("Frame Rate", selection: $preferencesManager.visualizationFrameRate) {
                        Text("30 FPS").tag(30)
                        Text("60 FPS").tag(60)
                        Text("120 FPS").tag(120)
                        Text("Unlimited").tag(0)
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Text("Quality Level")
                    Spacer()
                    Picker("Quality", selection: $preferencesManager.visualizationQuality) {
                        Text("Low").tag(VisualizationQuality.low)
                        Text("Medium").tag(VisualizationQuality.medium)
                        Text("High").tag(VisualizationQuality.high)
                        Text("Ultra").tag(VisualizationQuality.ultra)
                    }
                    .pickerStyle(.menu)
                }
                
                Toggle("Use Metal Performance Shaders", isOn: $preferencesManager.useMetalPerformanceShaders)
                
                Toggle("Enable GPU acceleration", isOn: $preferencesManager.enableGPUAcceleration)
            }
            
            Section("Audio Analysis") {
                HStack {
                    Text("FFT Size")
                    Spacer()
                    Picker("FFT Size", selection: $preferencesManager.fftSize) {
                        Text("512").tag(512)
                        Text("1024").tag(1024)
                        Text("2048").tag(2048)
                        Text("4096").tag(4096)
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Text("Smoothing")
                    Spacer()
                    Slider(
                        value: $preferencesManager.audioSmoothing,
                        in: 0...1,
                        step: 0.1
                    ) {
                        Text("Smoothing")
                    }
                    Text("\(Int(preferencesManager.audioSmoothing * 100))%")
                        .frame(width: 40, alignment: .trailing)
                }
                
                HStack {
                    Text("Sensitivity")
                    Spacer()
                    Slider(
                        value: $preferencesManager.audioSensitivity,
                        in: 0...2,
                        step: 0.1
                    ) {
                        Text("Sensitivity")
                    }
                    Text("\(preferencesManager.audioSensitivity, specifier: "%.1f")x")
                        .frame(width: 40, alignment: .trailing)
                }
            }
            
            Section("MilkDrop") {
                Picker("Default preset", selection: $preferencesManager.milkdropPreset) {
                    ForEach(milkdropPresets, id: \.self) { preset in
                        Text(preset).tag(preset)
                    }
                }
                
                Toggle("Random presets", isOn: $preferencesManager.randomMilkdropPresets)
                
                if preferencesManager.randomMilkdropPresets {
                    HStack {
                        Text("Preset duration")
                        Spacer()
                        Slider(
                            value: $preferencesManager.milkdropPresetDuration,
                            in: 10...300,
                            step: 10
                        ) {
                            Text("Duration")
                        }
                        Text("\(Int(preferencesManager.milkdropPresetDuration))s")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
    }
    
    private let milkdropPresets = [
        "Classic Spiral",
        "Electric Flow",
        "Plasma Storm",
        "Neon Waves",
        "Digital Rain",
        "Cosmic Dance",
        "Fractal Dreams"
    ]
}

// MARK: - Performance Preferences

struct PerformancePreferencesView: View {
    @EnvironmentObject private var preferencesManager: PreferencesManager
    
    var body: some View {
        Form {
            Section("Memory Management") {
                HStack {
                    Text("Skin Cache Size")
                    Spacer()
                    Picker("Cache Size", selection: $preferencesManager.skinCacheSize) {
                        Text("50 MB").tag(50)
                        Text("100 MB").tag(100)
                        Text("200 MB").tag(200)
                        Text("500 MB").tag(500)
                        Text("1 GB").tag(1000)
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Text("Audio Buffer Count")
                    Spacer()
                    Picker("Buffer Count", selection: $preferencesManager.audioBufferCount) {
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("8").tag(8)
                        Text("16").tag(16)
                    }
                    .pickerStyle(.menu)
                }
                
                Toggle("Preload frequent skins", isOn: $preferencesManager.preloadFrequentSkins)
                
                Button("Clear All Caches") {
                    clearAllCaches()
                }
            }
            
            Section("CPU Usage") {
                HStack {
                    Text("Thread Priority")
                    Spacer()
                    Picker("Priority", selection: $preferencesManager.threadPriority) {
                        Text("Low").tag(ThreadPriority.low)
                        Text("Normal").tag(ThreadPriority.normal)
                        Text("High").tag(ThreadPriority.high)
                    }
                    .pickerStyle(.menu)
                }
                
                Toggle("Limit background processing", isOn: $preferencesManager.limitBackgroundProcessing)
                
                Toggle("Pause when inactive", isOn: $preferencesManager.pauseWhenInactive)
                
                HStack {
                    Text("CPU Usage Limit")
                    Spacer()
                    Slider(
                        value: $preferencesManager.cpuUsageLimit,
                        in: 10...100,
                        step: 5
                    ) {
                        Text("CPU Limit")
                    }
                    Text("\(Int(preferencesManager.cpuUsageLimit))%")
                        .frame(width: 40, alignment: .trailing)
                }
            }
            
            Section("Energy Efficiency") {
                Toggle("Reduce animations on battery", isOn: $preferencesManager.reduceAnimationsOnBattery)
                
                Toggle("Lower quality on battery", isOn: $preferencesManager.lowerQualityOnBattery)
                
                Toggle("Adaptive performance", isOn: $preferencesManager.adaptivePerformance)
                
                if preferencesManager.adaptivePerformance {
                    Text("Automatically adjusts quality based on system performance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Monitoring") {
                Toggle("Show performance overlay", isOn: $preferencesManager.showPerformanceOverlay)
                
                Toggle("Log performance metrics", isOn: $preferencesManager.logPerformanceMetrics)
                
                Toggle("Enable crash reporting", isOn: $preferencesManager.enableCrashReporting)
                
                Button("Export Performance Report") {
                    exportPerformanceReport()
                }
            }
        }
        .padding()
    }
    
    private func clearAllCaches() {
        // Implementation would clear all caches
        print("Clearing all caches...")
    }
    
    private func exportPerformanceReport() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "WinampMac_Performance_Report.json"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                // Implementation would export performance data
                print("Exporting performance report to: \(url)")
            }
        }
    }
}

// MARK: - Advanced Preferences

struct AdvancedPreferencesView: View {
    @EnvironmentObject private var preferencesManager: PreferencesManager
    
    @State private var showingResetAlert = false
    
    var body: some View {
        Form {
            Section("Debug") {
                Toggle("Enable debug logging", isOn: $preferencesManager.enableDebugLogging)
                
                Toggle("Verbose Metal logging", isOn: $preferencesManager.verboseMetalLogging)
                
                Toggle("Show internal errors", isOn: $preferencesManager.showInternalErrors)
                
                Button("Open Log Folder") {
                    openLogFolder()
                }
            }
            
            Section("Skin Engine") {
                Toggle("Strict skin parsing", isOn: $preferencesManager.strictSkinParsing)
                
                Toggle("Enable skin scripting", isOn: $preferencesManager.enableSkinScripting)
                
                Toggle("Cache skin thumbnails", isOn: $preferencesManager.cacheSkinThumbnails)
                
                HStack {
                    Text("Max concurrent skin loads")
                    Spacer()
                    Stepper(
                        "\(preferencesManager.maxConcurrentSkinLoads)",
                        value: $preferencesManager.maxConcurrentSkinLoads,
                        in: 1...10
                    )
                }
            }
            
            Section("Experimental") {
                Toggle("Beta features", isOn: $preferencesManager.enableBetaFeatures)
                    .onChange(of: preferencesManager.enableBetaFeatures) { enabled in
                        if enabled {
                            showBetaWarning()
                        }
                    }
                
                if preferencesManager.enableBetaFeatures {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Neural network upscaling", isOn: $preferencesManager.enableNeuralUpscaling)
                        
                        Toggle("Advanced audio effects", isOn: $preferencesManager.enableAdvancedAudioEffects)
                        
                        Toggle("Experimental visualizations", isOn: $preferencesManager.enableExperimentalVisualizations)
                        
                        Text("⚠️ Beta features may be unstable")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Section("Data & Privacy") {
                Toggle("Anonymous usage statistics", isOn: $preferencesManager.shareUsageStatistics)
                
                Toggle("Crash report sharing", isOn: $preferencesManager.shareCrashReports)
                
                Button("Clear All User Data") {
                    showingResetAlert = true
                }
                .foregroundColor(.red)
                
                Button("Export Settings") {
                    exportSettings()
                }
                
                Button("Import Settings") {
                    importSettings()
                }
            }
            
            Section("Reset") {
                Button("Reset to Defaults") {
                    showingResetAlert = true
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
    
    private func openLogFolder() {
        let logURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Logs/WinampMac")
        
        if let url = logURL {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func showBetaWarning() {
        let alert = NSAlert()
        alert.messageText = "Enable Beta Features?"
        alert.informativeText = "Beta features are experimental and may cause instability. Use at your own risk."
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertSecondButtonReturn {
            preferencesManager.enableBetaFeatures = false
        }
    }
    
    private func exportSettings() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "WinampMac_Settings.json"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                preferencesManager.exportSettings(to: url)
            }
        }
    }
    
    private func importSettings() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                preferencesManager.importSettings(from: url)
            }
        }
    }
    
    private func resetToDefaults() {
        preferencesManager.resetToDefaults()
    }
}

// MARK: - Supporting Types

enum PreferencesTab: CaseIterable {
    case general
    case audio
    case visualization
    case performance
    case advanced
}

enum InterfaceTheme: CaseIterable, Codable {
    case system
    case light
    case dark
}

enum AudioFileType: CaseIterable, Hashable, Codable {
    case mp3, aac, flac, wav, aiff, m4a, ogg, wma
    
    var displayName: String {
        switch self {
        case .mp3: return "MP3"
        case .aac: return "AAC"
        case .flac: return "FLAC"
        case .wav: return "WAV"
        case .aiff: return "AIFF"
        case .m4a: return "M4A"
        case .ogg: return "OGG"
        case .wma: return "WMA"
        }
    }
}

enum AudioFormat: CaseIterable, Hashable, Codable {
    case pcm16, pcm24, pcm32, float32, float64
    
    var displayName: String {
        switch self {
        case .pcm16: return "16-bit PCM"
        case .pcm24: return "24-bit PCM"
        case .pcm32: return "32-bit PCM"
        case .float32: return "32-bit Float"
        case .float64: return "64-bit Float"
        }
    }
}

enum ReplayGainMode: CaseIterable, Codable {
    case off, track, album
}

enum VisualizationQuality: CaseIterable, Codable {
    case low, medium, high, ultra
}

enum ThreadPriority: CaseIterable, Codable {
    case low, normal, high
}