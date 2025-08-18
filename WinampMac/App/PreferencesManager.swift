import Foundation
import SwiftUI
import Combine

/// Comprehensive Preferences Manager for storing and managing all app settings
/// Handles user defaults, iCloud sync, and settings import/export
@MainActor
final class PreferencesManager: ObservableObject {
    
    static let shared = PreferencesManager()
    
    // MARK: - General Settings
    @Published var launchAtStartup: Bool = false
    @Published var restoreLastSession: Bool = true
    @Published var defaultSkinID: String? = nil
    @Published var alwaysOnTop: Bool = false
    @Published var hideDockIcon: Bool = false
    @Published var minimizeToMenuBar: Bool = false
    @Published var showInAllSpaces: Bool = false
    @Published var interfaceTheme: InterfaceTheme = .system
    @Published var interfaceScale: Double = 1.0
    @Published var showTooltips: Bool = true
    @Published var animateInterface: Bool = true
    @Published var associatedFileTypes: Set<AudioFileType> = [.mp3, .aac, .flac, .wav]
    
    // MARK: - Audio Settings
    @Published var audioBufferSize: Int = 512
    @Published var sampleRate: Int = 44100
    @Published var crossfadeEnabled: Bool = false
    @Published var crossfadeDuration: Double = 3.0
    @Published var gaplessPlayback: Bool = true
    @Published var autoNormalize: Bool = false
    @Published var replayGainMode: ReplayGainMode = .off
    @Published var enabledAudioFormats: Set<AudioFormat> = [.pcm16, .pcm24, .float32]
    
    // MARK: - Visualization Settings
    @Published var defaultVisualizationMode: VisualizationMode = .spectrum
    @Published var defaultColorScheme: VisualizationColorScheme = .rainbow
    @Published var autoRotateModes: Bool = false
    @Published var modeRotationInterval: Double = 30.0
    @Published var visualizationFrameRate: Int = 60
    @Published var visualizationQuality: VisualizationQuality = .high
    @Published var useMetalPerformanceShaders: Bool = true
    @Published var enableGPUAcceleration: Bool = true
    @Published var fftSize: Int = 1024
    @Published var audioSmoothing: Double = 0.3
    @Published var audioSensitivity: Double = 1.0
    @Published var milkdropPreset: String = "Classic Spiral"
    @Published var randomMilkdropPresets: Bool = false
    @Published var milkdropPresetDuration: Double = 60.0
    @Published var miniVisualizationStyle: VisualizationStyle = .spectrum
    
    // MARK: - Performance Settings
    @Published var skinCacheSize: Int = 200
    @Published var audioBufferCount: Int = 4
    @Published var preloadFrequentSkins: Bool = true
    @Published var threadPriority: ThreadPriority = .normal
    @Published var limitBackgroundProcessing: Bool = false
    @Published var pauseWhenInactive: Bool = false
    @Published var cpuUsageLimit: Double = 80.0
    @Published var reduceAnimationsOnBattery: Bool = true
    @Published var lowerQualityOnBattery: Bool = true
    @Published var adaptivePerformance: Bool = true
    @Published var showPerformanceOverlay: Bool = false
    @Published var logPerformanceMetrics: Bool = false
    @Published var enableCrashReporting: Bool = true
    
    // MARK: - Advanced Settings
    @Published var enableDebugLogging: Bool = false
    @Published var verboseMetalLogging: Bool = false
    @Published var showInternalErrors: Bool = false
    @Published var strictSkinParsing: Bool = true
    @Published var enableSkinScripting: Bool = false
    @Published var cacheSkinThumbnails: Bool = true
    @Published var maxConcurrentSkinLoads: Int = 3
    @Published var enableBetaFeatures: Bool = false
    @Published var enableNeuralUpscaling: Bool = false
    @Published var enableAdvancedAudioEffects: Bool = false
    @Published var enableExperimentalVisualizations: Bool = false
    @Published var shareUsageStatistics: Bool = false
    @Published var shareCrashReports: Bool = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let ubiquitousDefaults = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()
    private let settingsVersion = "1.0"
    
    // MARK: - Keys
    private enum Keys {
        // General
        static let launchAtStartup = "LaunchAtStartup"
        static let restoreLastSession = "RestoreLastSession"
        static let defaultSkinID = "DefaultSkinID"
        static let alwaysOnTop = "AlwaysOnTop"
        static let hideDockIcon = "HideDockIcon"
        static let minimizeToMenuBar = "MinimizeToMenuBar"
        static let showInAllSpaces = "ShowInAllSpaces"
        static let interfaceTheme = "InterfaceTheme"
        static let interfaceScale = "InterfaceScale"
        static let showTooltips = "ShowTooltips"
        static let animateInterface = "AnimateInterface"
        static let associatedFileTypes = "AssociatedFileTypes"
        
        // Audio
        static let audioBufferSize = "AudioBufferSize"
        static let sampleRate = "SampleRate"
        static let crossfadeEnabled = "CrossfadeEnabled"
        static let crossfadeDuration = "CrossfadeDuration"
        static let gaplessPlayback = "GaplessPlayback"
        static let autoNormalize = "AutoNormalize"
        static let replayGainMode = "ReplayGainMode"
        static let enabledAudioFormats = "EnabledAudioFormats"
        
        // Visualization
        static let defaultVisualizationMode = "DefaultVisualizationMode"
        static let defaultColorScheme = "DefaultColorScheme"
        static let autoRotateModes = "AutoRotateModes"
        static let modeRotationInterval = "ModeRotationInterval"
        static let visualizationFrameRate = "VisualizationFrameRate"
        static let visualizationQuality = "VisualizationQuality"
        static let useMetalPerformanceShaders = "UseMetalPerformanceShaders"
        static let enableGPUAcceleration = "EnableGPUAcceleration"
        static let fftSize = "FFTSize"
        static let audioSmoothing = "AudioSmoothing"
        static let audioSensitivity = "AudioSensitivity"
        static let milkdropPreset = "MilkdropPreset"
        static let randomMilkdropPresets = "RandomMilkdropPresets"
        static let milkdropPresetDuration = "MilkdropPresetDuration"
        static let miniVisualizationStyle = "MiniVisualizationStyle"
        
        // Performance
        static let skinCacheSize = "SkinCacheSize"
        static let audioBufferCount = "AudioBufferCount"
        static let preloadFrequentSkins = "PreloadFrequentSkins"
        static let threadPriority = "ThreadPriority"
        static let limitBackgroundProcessing = "LimitBackgroundProcessing"
        static let pauseWhenInactive = "PauseWhenInactive"
        static let cpuUsageLimit = "CPUUsageLimit"
        static let reduceAnimationsOnBattery = "ReduceAnimationsOnBattery"
        static let lowerQualityOnBattery = "LowerQualityOnBattery"
        static let adaptivePerformance = "AdaptivePerformance"
        static let showPerformanceOverlay = "ShowPerformanceOverlay"
        static let logPerformanceMetrics = "LogPerformanceMetrics"
        static let enableCrashReporting = "EnableCrashReporting"
        
        // Advanced
        static let enableDebugLogging = "EnableDebugLogging"
        static let verboseMetalLogging = "VerboseMetalLogging"
        static let showInternalErrors = "ShowInternalErrors"
        static let strictSkinParsing = "StrictSkinParsing"
        static let enableSkinScripting = "EnableSkinScripting"
        static let cacheSkinThumbnails = "CacheSkinThumbnails"
        static let maxConcurrentSkinLoads = "MaxConcurrentSkinLoads"
        static let enableBetaFeatures = "EnableBetaFeatures"
        static let enableNeuralUpscaling = "EnableNeuralUpscaling"
        static let enableAdvancedAudioEffects = "EnableAdvancedAudioEffects"
        static let enableExperimentalVisualizations = "EnableExperimentalVisualizations"
        static let shareUsageStatistics = "ShareUsageStatistics"
        static let shareCrashReports = "ShareCrashReports"
        
        static let settingsVersion = "SettingsVersion"
    }
    
    init() {
        loadSettings()
        setupObservers()
        migrateSettingsIfNeeded()
    }
    
    // MARK: - Loading and Saving
    
    private func loadSettings() {
        // General
        launchAtStartup = userDefaults.bool(forKey: Keys.launchAtStartup)
        restoreLastSession = userDefaults.object(forKey: Keys.restoreLastSession) as? Bool ?? true
        defaultSkinID = userDefaults.string(forKey: Keys.defaultSkinID)
        alwaysOnTop = userDefaults.bool(forKey: Keys.alwaysOnTop)
        hideDockIcon = userDefaults.bool(forKey: Keys.hideDockIcon)
        minimizeToMenuBar = userDefaults.bool(forKey: Keys.minimizeToMenuBar)
        showInAllSpaces = userDefaults.bool(forKey: Keys.showInAllSpaces)
        
        if let themeData = userDefaults.data(forKey: Keys.interfaceTheme),
           let theme = try? JSONDecoder().decode(InterfaceTheme.self, from: themeData) {
            interfaceTheme = theme
        }
        
        interfaceScale = userDefaults.object(forKey: Keys.interfaceScale) as? Double ?? 1.0
        showTooltips = userDefaults.object(forKey: Keys.showTooltips) as? Bool ?? true
        animateInterface = userDefaults.object(forKey: Keys.animateInterface) as? Bool ?? true
        
        if let fileTypesData = userDefaults.data(forKey: Keys.associatedFileTypes),
           let fileTypes = try? JSONDecoder().decode(Set<AudioFileType>.self, from: fileTypesData) {
            associatedFileTypes = fileTypes
        }
        
        // Audio
        audioBufferSize = userDefaults.object(forKey: Keys.audioBufferSize) as? Int ?? 512
        sampleRate = userDefaults.object(forKey: Keys.sampleRate) as? Int ?? 44100
        crossfadeEnabled = userDefaults.bool(forKey: Keys.crossfadeEnabled)
        crossfadeDuration = userDefaults.object(forKey: Keys.crossfadeDuration) as? Double ?? 3.0
        gaplessPlayback = userDefaults.object(forKey: Keys.gaplessPlayback) as? Bool ?? true
        autoNormalize = userDefaults.bool(forKey: Keys.autoNormalize)
        
        if let replayGainData = userDefaults.data(forKey: Keys.replayGainMode),
           let replayGain = try? JSONDecoder().decode(ReplayGainMode.self, from: replayGainData) {
            replayGainMode = replayGain
        }
        
        if let formatsData = userDefaults.data(forKey: Keys.enabledAudioFormats),
           let formats = try? JSONDecoder().decode(Set<AudioFormat>.self, from: formatsData) {
            enabledAudioFormats = formats
        }
        
        // Visualization
        if let vizModeData = userDefaults.data(forKey: Keys.defaultVisualizationMode),
           let vizMode = try? JSONDecoder().decode(VisualizationMode.self, from: vizModeData) {
            defaultVisualizationMode = vizMode
        }
        
        if let colorSchemeData = userDefaults.data(forKey: Keys.defaultColorScheme),
           let colorScheme = try? JSONDecoder().decode(VisualizationColorScheme.self, from: colorSchemeData) {
            defaultColorScheme = colorScheme
        }
        
        autoRotateModes = userDefaults.bool(forKey: Keys.autoRotateModes)
        modeRotationInterval = userDefaults.object(forKey: Keys.modeRotationInterval) as? Double ?? 30.0
        visualizationFrameRate = userDefaults.object(forKey: Keys.visualizationFrameRate) as? Int ?? 60
        
        if let qualityData = userDefaults.data(forKey: Keys.visualizationQuality),
           let quality = try? JSONDecoder().decode(VisualizationQuality.self, from: qualityData) {
            visualizationQuality = quality
        }
        
        useMetalPerformanceShaders = userDefaults.object(forKey: Keys.useMetalPerformanceShaders) as? Bool ?? true
        enableGPUAcceleration = userDefaults.object(forKey: Keys.enableGPUAcceleration) as? Bool ?? true
        fftSize = userDefaults.object(forKey: Keys.fftSize) as? Int ?? 1024
        audioSmoothing = userDefaults.object(forKey: Keys.audioSmoothing) as? Double ?? 0.3
        audioSensitivity = userDefaults.object(forKey: Keys.audioSensitivity) as? Double ?? 1.0
        milkdropPreset = userDefaults.string(forKey: Keys.milkdropPreset) ?? "Classic Spiral"
        randomMilkdropPresets = userDefaults.bool(forKey: Keys.randomMilkdropPresets)
        milkdropPresetDuration = userDefaults.object(forKey: Keys.milkdropPresetDuration) as? Double ?? 60.0
        
        if let styleData = userDefaults.data(forKey: Keys.miniVisualizationStyle),
           let style = try? JSONDecoder().decode(VisualizationStyle.self, from: styleData) {
            miniVisualizationStyle = style
        }
        
        // Performance
        skinCacheSize = userDefaults.object(forKey: Keys.skinCacheSize) as? Int ?? 200
        audioBufferCount = userDefaults.object(forKey: Keys.audioBufferCount) as? Int ?? 4
        preloadFrequentSkins = userDefaults.object(forKey: Keys.preloadFrequentSkins) as? Bool ?? true
        
        if let priorityData = userDefaults.data(forKey: Keys.threadPriority),
           let priority = try? JSONDecoder().decode(ThreadPriority.self, from: priorityData) {
            threadPriority = priority
        }
        
        limitBackgroundProcessing = userDefaults.bool(forKey: Keys.limitBackgroundProcessing)
        pauseWhenInactive = userDefaults.bool(forKey: Keys.pauseWhenInactive)
        cpuUsageLimit = userDefaults.object(forKey: Keys.cpuUsageLimit) as? Double ?? 80.0
        reduceAnimationsOnBattery = userDefaults.object(forKey: Keys.reduceAnimationsOnBattery) as? Bool ?? true
        lowerQualityOnBattery = userDefaults.object(forKey: Keys.lowerQualityOnBattery) as? Bool ?? true
        adaptivePerformance = userDefaults.object(forKey: Keys.adaptivePerformance) as? Bool ?? true
        showPerformanceOverlay = userDefaults.bool(forKey: Keys.showPerformanceOverlay)
        logPerformanceMetrics = userDefaults.bool(forKey: Keys.logPerformanceMetrics)
        enableCrashReporting = userDefaults.object(forKey: Keys.enableCrashReporting) as? Bool ?? true
        
        // Advanced
        enableDebugLogging = userDefaults.bool(forKey: Keys.enableDebugLogging)
        verboseMetalLogging = userDefaults.bool(forKey: Keys.verboseMetalLogging)
        showInternalErrors = userDefaults.bool(forKey: Keys.showInternalErrors)
        strictSkinParsing = userDefaults.object(forKey: Keys.strictSkinParsing) as? Bool ?? true
        enableSkinScripting = userDefaults.bool(forKey: Keys.enableSkinScripting)
        cacheSkinThumbnails = userDefaults.object(forKey: Keys.cacheSkinThumbnails) as? Bool ?? true
        maxConcurrentSkinLoads = userDefaults.object(forKey: Keys.maxConcurrentSkinLoads) as? Int ?? 3
        enableBetaFeatures = userDefaults.bool(forKey: Keys.enableBetaFeatures)
        enableNeuralUpscaling = userDefaults.bool(forKey: Keys.enableNeuralUpscaling)
        enableAdvancedAudioEffects = userDefaults.bool(forKey: Keys.enableAdvancedAudioEffects)
        enableExperimentalVisualizations = userDefaults.bool(forKey: Keys.enableExperimentalVisualizations)
        shareUsageStatistics = userDefaults.bool(forKey: Keys.shareUsageStatistics)
        shareCrashReports = userDefaults.bool(forKey: Keys.shareCrashReports)
    }
    
    private func setupObservers() {
        // Observe all published properties and save when they change
        $launchAtStartup.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.launchAtStartup)
        }.store(in: &cancellables)
        
        $restoreLastSession.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.restoreLastSession)
        }.store(in: &cancellables)
        
        $defaultSkinID.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.defaultSkinID)
        }.store(in: &cancellables)
        
        $alwaysOnTop.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.alwaysOnTop)
        }.store(in: &cancellables)
        
        $hideDockIcon.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.hideDockIcon)
        }.store(in: &cancellables)
        
        $minimizeToMenuBar.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.minimizeToMenuBar)
        }.store(in: &cancellables)
        
        $showInAllSpaces.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.showInAllSpaces)
        }.store(in: &cancellables)
        
        $interfaceTheme.sink { [weak self] value in
            if let data = try? JSONEncoder().encode(value) {
                self?.userDefaults.set(data, forKey: Keys.interfaceTheme)
            }
        }.store(in: &cancellables)
        
        $interfaceScale.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.interfaceScale)
        }.store(in: &cancellables)
        
        $showTooltips.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.showTooltips)
        }.store(in: &cancellables)
        
        $animateInterface.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.animateInterface)
        }.store(in: &cancellables)
        
        $associatedFileTypes.sink { [weak self] value in
            if let data = try? JSONEncoder().encode(value) {
                self?.userDefaults.set(data, forKey: Keys.associatedFileTypes)
            }
        }.store(in: &cancellables)
        
        // Audio settings observers
        $audioBufferSize.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.audioBufferSize)
        }.store(in: &cancellables)
        
        $sampleRate.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.sampleRate)
        }.store(in: &cancellables)
        
        $crossfadeEnabled.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.crossfadeEnabled)
        }.store(in: &cancellables)
        
        $crossfadeDuration.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.crossfadeDuration)
        }.store(in: &cancellables)
        
        $gaplessPlayback.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.gaplessPlayback)
        }.store(in: &cancellables)
        
        $autoNormalize.sink { [weak self] value in
            self?.userDefaults.set(value, forKey: Keys.autoNormalize)
        }.store(in: &cancellables)
        
        $replayGainMode.sink { [weak self] value in
            if let data = try? JSONEncoder().encode(value) {
                self?.userDefaults.set(data, forKey: Keys.replayGainMode)
            }
        }.store(in: &cancellables)
        
        $enabledAudioFormats.sink { [weak self] value in
            if let data = try? JSONEncoder().encode(value) {
                self?.userDefaults.set(data, forKey: Keys.enabledAudioFormats)
            }
        }.store(in: &cancellables)
        
        // Continue with other observers...
        // (Similar pattern for all other published properties)
        
        // Save changes periodically
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: - Public Methods
    
    func resetToDefaults() {
        // Reset all properties to their default values
        launchAtStartup = false
        restoreLastSession = true
        defaultSkinID = nil
        alwaysOnTop = false
        hideDockIcon = false
        minimizeToMenuBar = false
        showInAllSpaces = false
        interfaceTheme = .system
        interfaceScale = 1.0
        showTooltips = true
        animateInterface = true
        associatedFileTypes = [.mp3, .aac, .flac, .wav]
        
        // Audio defaults
        audioBufferSize = 512
        sampleRate = 44100
        crossfadeEnabled = false
        crossfadeDuration = 3.0
        gaplessPlayback = true
        autoNormalize = false
        replayGainMode = .off
        enabledAudioFormats = [.pcm16, .pcm24, .float32]
        
        // Visualization defaults
        defaultVisualizationMode = .spectrum
        defaultColorScheme = .rainbow
        autoRotateModes = false
        modeRotationInterval = 30.0
        visualizationFrameRate = 60
        visualizationQuality = .high
        useMetalPerformanceShaders = true
        enableGPUAcceleration = true
        fftSize = 1024
        audioSmoothing = 0.3
        audioSensitivity = 1.0
        milkdropPreset = "Classic Spiral"
        randomMilkdropPresets = false
        milkdropPresetDuration = 60.0
        miniVisualizationStyle = .spectrum
        
        // Performance defaults
        skinCacheSize = 200
        audioBufferCount = 4
        preloadFrequentSkins = true
        threadPriority = .normal
        limitBackgroundProcessing = false
        pauseWhenInactive = false
        cpuUsageLimit = 80.0
        reduceAnimationsOnBattery = true
        lowerQualityOnBattery = true
        adaptivePerformance = true
        showPerformanceOverlay = false
        logPerformanceMetrics = false
        enableCrashReporting = true
        
        // Advanced defaults
        enableDebugLogging = false
        verboseMetalLogging = false
        showInternalErrors = false
        strictSkinParsing = true
        enableSkinScripting = false
        cacheSkinThumbnails = true
        maxConcurrentSkinLoads = 3
        enableBetaFeatures = false
        enableNeuralUpscaling = false
        enableAdvancedAudioEffects = false
        enableExperimentalVisualizations = false
        shareUsageStatistics = false
        shareCrashReports = false
        
        // Clear all stored defaults
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("Winamp") || key.hasPrefix("Audio") || key.hasPrefix("Visualization") {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    func exportSettings(to url: URL) {
        let settings: [String: Any] = [
            "version": settingsVersion,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "general": [
                "launchAtStartup": launchAtStartup,
                "restoreLastSession": restoreLastSession,
                "defaultSkinID": defaultSkinID as Any,
                "alwaysOnTop": alwaysOnTop,
                "hideDockIcon": hideDockIcon,
                "minimizeToMenuBar": minimizeToMenuBar,
                "showInAllSpaces": showInAllSpaces,
                "interfaceTheme": String(describing: interfaceTheme),
                "interfaceScale": interfaceScale,
                "showTooltips": showTooltips,
                "animateInterface": animateInterface
            ],
            "audio": [
                "audioBufferSize": audioBufferSize,
                "sampleRate": sampleRate,
                "crossfadeEnabled": crossfadeEnabled,
                "crossfadeDuration": crossfadeDuration,
                "gaplessPlayback": gaplessPlayback,
                "autoNormalize": autoNormalize,
                "replayGainMode": String(describing: replayGainMode)
            ],
            "visualization": [
                "defaultVisualizationMode": String(describing: defaultVisualizationMode),
                "defaultColorScheme": String(describing: defaultColorScheme),
                "autoRotateModes": autoRotateModes,
                "modeRotationInterval": modeRotationInterval,
                "visualizationFrameRate": visualizationFrameRate,
                "visualizationQuality": String(describing: visualizationQuality),
                "useMetalPerformanceShaders": useMetalPerformanceShaders,
                "enableGPUAcceleration": enableGPUAcceleration,
                "fftSize": fftSize,
                "audioSmoothing": audioSmoothing,
                "audioSensitivity": audioSensitivity
            ],
            "performance": [
                "skinCacheSize": skinCacheSize,
                "audioBufferCount": audioBufferCount,
                "preloadFrequentSkins": preloadFrequentSkins,
                "threadPriority": String(describing: threadPriority),
                "limitBackgroundProcessing": limitBackgroundProcessing,
                "pauseWhenInactive": pauseWhenInactive,
                "cpuUsageLimit": cpuUsageLimit,
                "adaptivePerformance": adaptivePerformance
            ],
            "advanced": [
                "enableDebugLogging": enableDebugLogging,
                "verboseMetalLogging": verboseMetalLogging,
                "strictSkinParsing": strictSkinParsing,
                "enableSkinScripting": enableSkinScripting,
                "cacheSkinThumbnails": cacheSkinThumbnails,
                "maxConcurrentSkinLoads": maxConcurrentSkinLoads,
                "enableBetaFeatures": enableBetaFeatures
            ]
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            try data.write(to: url)
        } catch {
            print("Failed to export settings: \(error)")
        }
    }
    
    func importSettings(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Parse and apply settings
            if let general = settings?["general"] as? [String: Any] {
                launchAtStartup = general["launchAtStartup"] as? Bool ?? launchAtStartup
                restoreLastSession = general["restoreLastSession"] as? Bool ?? restoreLastSession
                defaultSkinID = general["defaultSkinID"] as? String
                alwaysOnTop = general["alwaysOnTop"] as? Bool ?? alwaysOnTop
                hideDockIcon = general["hideDockIcon"] as? Bool ?? hideDockIcon
                minimizeToMenuBar = general["minimizeToMenuBar"] as? Bool ?? minimizeToMenuBar
                showInAllSpaces = general["showInAllSpaces"] as? Bool ?? showInAllSpaces
                interfaceScale = general["interfaceScale"] as? Double ?? interfaceScale
                showTooltips = general["showTooltips"] as? Bool ?? showTooltips
                animateInterface = general["animateInterface"] as? Bool ?? animateInterface
            }
            
            // Continue parsing other sections...
            
        } catch {
            print("Failed to import settings: \(error)")
        }
    }
    
    func toggleAlwaysOnTop() {
        alwaysOnTop.toggle()
        
        // Apply to all windows immediately
        for window in NSApplication.shared.windows {
            window.level = alwaysOnTop ? .floating : .normal
        }
    }
    
    // MARK: - Private Methods
    
    private func migrateSettingsIfNeeded() {
        let currentVersion = userDefaults.string(forKey: Keys.settingsVersion) ?? "0.0"
        
        if currentVersion != settingsVersion {
            // Perform migration if needed
            performSettingsMigration(from: currentVersion, to: settingsVersion)
            userDefaults.set(settingsVersion, forKey: Keys.settingsVersion)
        }
    }
    
    private func performSettingsMigration(from oldVersion: String, to newVersion: String) {
        // Migration logic for different versions
        print("Migrating settings from \(oldVersion) to \(newVersion)")
        
        // Example migration logic
        if oldVersion == "0.0" {
            // First version - no migration needed
        }
        
        // Future migrations would go here
    }
}

// MARK: - iCloud Sync Extension
extension PreferencesManager {
    
    func enableiCloudSync() {
        ubiquitousDefaults.synchronize()
        
        // Sync current settings to iCloud
        synciCloudSettings()
        
        // Observe iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudSettingsChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousDefaults
        )
    }
    
    private func synciCloudSettings() {
        // Sync key settings to iCloud
        ubiquitousDefaults.set(alwaysOnTop, forKey: "iCloud_\(Keys.alwaysOnTop)")
        ubiquitousDefaults.set(interfaceScale, forKey: "iCloud_\(Keys.interfaceScale)")
        ubiquitousDefaults.set(defaultSkinID, forKey: "iCloud_\(Keys.defaultSkinID)")
        
        if let themeData = try? JSONEncoder().encode(interfaceTheme) {
            ubiquitousDefaults.set(themeData, forKey: "iCloud_\(Keys.interfaceTheme)")
        }
        
        ubiquitousDefaults.synchronize()
    }
    
    @objc private func iCloudSettingsChanged() {
        // Update local settings from iCloud
        alwaysOnTop = ubiquitousDefaults.bool(forKey: "iCloud_\(Keys.alwaysOnTop)")
        interfaceScale = ubiquitousDefaults.double(forKey: "iCloud_\(Keys.interfaceScale)")
        defaultSkinID = ubiquitousDefaults.string(forKey: "iCloud_\(Keys.defaultSkinID)")
        
        if let themeData = ubiquitousDefaults.data(forKey: "iCloud_\(Keys.interfaceTheme)"),
           let theme = try? JSONDecoder().decode(InterfaceTheme.self, from: themeData) {
            interfaceTheme = theme
        }
    }
}