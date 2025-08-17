//
//  ModernWinampCore.swift
//  WinampMac
//
//  Comprehensive integration of all modern components
//  Central coordinator for the modernized Winamp macOS application
//

import Foundation
import AppKit
import AVFoundation
import Metal
import MetalKit
import OSLog
import Combine

/// Modern Winamp core integration class
@available(macOS 15.0, *)
@MainActor
public final class ModernWinampCore: ObservableObject {
    
    // MARK: - Core Components
    public let skinLoader = ModernSkinLoader()
    public let assetCache = ModernAssetCache()
    public let errorHandler = ModernErrorHandling()
    public let optimizations = MacOSOptimizations.shared
    public let futureProofing = FutureProofing.shared
    
    // MARK: - Audio System
    private var audioEngine: AVAudioEngine
    private var audioPlayer: AVAudioPlayerNode
    private var audioAnalyzer: AudioAnalyzer
    
    // MARK: - Visual System
    private var visualizerView: ModernVisualizerView?
    private var skinWindow: ModernSkinWindow?
    
    // MARK: - State Management
    @Published public private(set) var currentSkin: ModernSkinLoader.SkinAssets?
    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var playbackPosition: TimeInterval = 0
    @Published public private(set) var volume: Float = 0.8
    @Published public private(set) var visualizationData: [Float] = []
    
    // MARK: - Configuration
    @Published public var configuration = Configuration()
    
    public struct Configuration {
        public var visualizationMode: ModernVisualizerView.VisualizationMode = .spectrumBars
        public var colorScheme: ModernVisualizerView.VisualizationColorScheme = .classic
        public var audioBufferSize: Int = 512
        public var enableLowLatencyMode = false
        public var enableHighQualityMode = true
        public var adaptiveQuality = true
    }
    
    // MARK: - Track Information
    public struct Track {
        public let title: String
        public let artist: String?
        public let album: String?
        public let duration: TimeInterval
        public let url: URL
        public let format: AudioFormat
        
        public enum AudioFormat: String, CaseIterable {
            case mp3 = "mp3"
            case aac = "aac"
            case flac = "flac"
            case wav = "wav"
            case aiff = "aiff"
            case alac = "alac"
            case opus = "opus"
        }
    }
    
    // MARK: - Logger
    private static let logger = Logger(subsystem: "com.winamp.mac.core", category: "Integration")
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init() {
        self.audioEngine = AVAudioEngine()
        self.audioPlayer = AVAudioPlayerNode()
        self.audioAnalyzer = AudioAnalyzer()
        
        setupAudioEngine()
        setupBindings()
        setupNotificationObservers()
        configureSystems()
        
        Self.logger.info("ModernWinampCore initialized successfully")
    }
    
    deinit {
        audioEngine.stop()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup Methods
    private func setupAudioEngine() {
        // Attach audio nodes
        audioEngine.attach(audioPlayer)
        audioEngine.attach(audioAnalyzer)
        
        // Configure audio format based on system capabilities
        let format = configureOptimalAudioFormat()
        
        // Connect audio chain: Player -> Analyzer -> Output
        audioEngine.connect(audioPlayer, to: audioAnalyzer, format: format)
        audioEngine.connect(audioAnalyzer, to: audioEngine.mainMixerNode, format: format)
        
        // Set up analysis callback
        audioAnalyzer.analysisCallback = { [weak self] data in
            Task { @MainActor in
                self?.visualizationData = data
                self?.visualizerView?.updateSpectrum(data)
            }
        }
        
        // Start audio engine
        do {
            try audioEngine.start()
            Self.logger.info("Audio engine started successfully")
        } catch {
            Self.logger.error("Failed to start audio engine: \(error)")
        }
    }
    
    private func configureOptimalAudioFormat() -> AVAudioFormat {
        let sampleRate: Double
        let bufferSize: Int
        
        // Optimize based on system capabilities
        if optimizations.systemCapabilities.isAppleSilicon {
            sampleRate = 48000.0
            bufferSize = configuration.enableLowLatencyMode ? 256 : 512
        } else {
            sampleRate = 44100.0
            bufferSize = 1024
        }
        
        configuration.audioBufferSize = bufferSize
        
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        ) else {
            fatalError("Failed to create audio format")
        }
        
        return format
    }
    
    private func setupBindings() {
        // Bind optimization changes to configuration updates
        optimizations.$adaptiveConfig
            .sink { [weak self] adaptiveConfig in
                self?.updateConfigurationFromOptimizations(adaptiveConfig)
            }
            .store(in: &cancellables)
        
        // Bind future-proofing changes
        futureProofing.$adaptiveConfig
            .sink { [weak self] futureConfig in
                self?.updateConfigurationFromFutureProofing(futureConfig)
            }
            .store(in: &cancellables)
    }
    
    private func setupNotificationObservers() {
        // System notifications
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleApplicationDidBecomeActive()
        }
        
        // Error recovery notifications
        NotificationCenter.default.addObserver(
            forName: .clearCaches,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleClearCaches()
        }
        
        NotificationCenter.default.addObserver(
            forName: .reinitializeAudio,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleReinitializeAudio()
        }
        
        NotificationCenter.default.addObserver(
            forName: .loadDefaultSkin,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.loadDefaultSkin()
            }
        }
    }
    
    private func configureSystems() {
        // Configure asset cache based on system capabilities
        let cacheConfig: ModernAssetCache.CacheConfiguration
        if optimizations.systemCapabilities.totalMemory > 16 * 1024 * 1024 * 1024 { // 16GB+
            cacheConfig = .highPerformance
        } else if optimizations.systemCapabilities.totalMemory > 8 * 1024 * 1024 * 1024 { // 8GB+
            cacheConfig = .default
        } else {
            cacheConfig = .lowMemory
        }
        
        // Register error handlers
        errorHandler.registerHandler(AudioErrorHandler())
        errorHandler.registerHandler(SkinErrorHandler())
        errorHandler.registerHandler(PerformanceErrorHandler())
    }
    
    // MARK: - Public Interface
    public func loadSkin(from url: URL) async {
        do {
            let assets = try await skinLoader.loadSkin(from: url)
            self.currentSkin = assets
            
            await applySkinToInterface(assets)
            
            Self.logger.info("Successfully loaded skin: \(assets.metadata.name)")
            
        } catch let error as ModernErrorHandling.WinampError {
            await errorHandler.reportError(
                error,
                context: ModernErrorHandling.ErrorContext(
                    operation: "load_skin",
                    userInfo: ["url": url.absoluteString]
                )
            )
        } catch {
            await errorHandler.reportError(
                .skinCorrupted(url.lastPathComponent, underlying: error.localizedDescription),
                context: ModernErrorHandling.ErrorContext(
                    operation: "load_skin",
                    userInfo: ["url": url.absoluteString]
                )
            )
        }
    }
    
    public func loadTrack(from url: URL) async {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let track = Track(
                title: extractTitle(from: url),
                artist: extractArtist(from: audioFile),
                album: extractAlbum(from: audioFile),
                duration: Double(audioFile.length) / audioFile.fileFormat.sampleRate,
                url: url,
                format: determineFormat(from: url)
            )
            
            self.currentTrack = track
            
            // Schedule audio file for playback
            audioPlayer.scheduleFile(audioFile, at: nil)
            
            Self.logger.info("Loaded track: \(track.title)")
            
        } catch {
            await errorHandler.reportError(
                .audioFormatUnsupported(url.pathExtension),
                context: ModernErrorHandling.ErrorContext(
                    operation: "load_track",
                    userInfo: ["url": url.absoluteString]
                )
            )
        }
    }
    
    public func play() async {
        guard !isPlaying else { return }
        
        do {
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            
            audioPlayer.play()
            self.isPlaying = true
            
            Self.logger.info("Playback started")
            
        } catch {
            await errorHandler.reportError(
                .audioPlaybackFailed(error.localizedDescription),
                context: ModernErrorHandling.ErrorContext(operation: "play")
            )
        }
    }
    
    public func pause() {
        guard isPlaying else { return }
        
        audioPlayer.pause()
        self.isPlaying = false
        
        Self.logger.info("Playback paused")
    }
    
    public func stop() {
        audioPlayer.stop()
        self.isPlaying = false
        self.playbackPosition = 0
        
        Self.logger.info("Playback stopped")
    }
    
    public func setVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        audioEngine.mainMixerNode.outputVolume = clampedVolume
        self.volume = clampedVolume
    }
    
    public func createMainWindow() -> ModernSkinWindow {
        let window = ModernSkinWindow(
            contentRect: NSRect(x: 100, y: 100, width: 275, height: 116),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Winamp"
        self.skinWindow = window
        
        // Add visualizer view if Metal is supported
        if optimizations.systemCapabilities.hasMetalSupport {
            let visualizer = ModernVisualizerView(
                frame: NSRect(x: 24, y: 43, width: 76, height: 16),
                device: MTLCreateSystemDefaultDevice()
            )
            
            visualizer.setVisualizationMode(configuration.visualizationMode)
            visualizer.setColorScheme(configuration.colorScheme)
            
            window.contentView?.addSubview(visualizer)
            self.visualizerView = visualizer
        }
        
        return window
    }
    
    public func setVisualizationMode(_ mode: ModernVisualizerView.VisualizationMode) {
        configuration.visualizationMode = mode
        visualizerView?.setVisualizationMode(mode)
    }
    
    public func setColorScheme(_ scheme: ModernVisualizerView.VisualizationColorScheme) {
        configuration.colorScheme = scheme
        visualizerView?.setColorScheme(scheme)
    }
    
    // MARK: - Private Methods
    private func applySkinToInterface(_ assets: ModernSkinLoader.SkinAssets) async {
        guard let window = skinWindow else { return }
        
        // Apply main skin image
        if let mainImage = assets.sprites["main"] {
            window.applySkin(mainImage)
        }
        
        // Configure hit test regions based on skin configuration
        setupHitTestRegions(for: assets, in: window)
        
        // Update UI elements with skin assets
        updateUIElements(with: assets)
    }
    
    private func setupHitTestRegions(for assets: ModernSkinLoader.SkinAssets, in window: ModernSkinWindow) {
        // Add button regions
        for (buttonId, mapping) in assets.configuration.buttonMappings {
            let region = ModernSkinWindow.HitTestRegion(
                path: NSBezierPath(rect: mapping.hitTestPath.bounds),
                action: .button(buttonId),
                cursor: .pointingHand,
                tooltip: mapping.tooltip
            )
            window.addHitTestRegion(region, named: buttonId)
        }
        
        // Add drag regions
        for (regionName, windowRegion) in assets.configuration.windowRegions {
            if windowRegion.dragBehavior == .moveWindow {
                let dragRegion = ModernSkinWindow.DragRegion(
                    path: windowRegion.hitTestPath ?? NSBezierPath(rect: windowRegion.frame),
                    behavior: .moveWindow
                )
                window.addDragRegion(dragRegion)
            }
        }
    }
    
    private func updateUIElements(with assets: ModernSkinLoader.SkinAssets) {
        // Update visualization colors if available
        if !assets.colorScheme.visualization.isEmpty {
            // Apply custom visualization colors
        }
        
        // Cache frequently used assets
        for (name, image) in assets.sprites {
            assetCache.cacheSkinAsset(image, skinName: assets.metadata.name, assetType: name)
        }
    }
    
    private func loadDefaultSkin() async {
        // Try to load a bundled default skin
        if let defaultSkinURL = Bundle.main.url(forResource: "default", withExtension: "wsz") {
            await loadSkin(from: defaultSkinURL)
        } else {
            // Create a minimal programmatic skin
            createMinimalSkin()
        }
    }
    
    private func createMinimalSkin() {
        // Create a basic skin programmatically
        let mainImage = NSImage(size: NSSize(width: 275, height: 116))
        mainImage.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: mainImage.size).fill()
        mainImage.unlockFocus()
        
        skinWindow?.applySkin(mainImage)
    }
    
    // MARK: - Audio Metadata Extraction
    private func extractTitle(from url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
    
    private func extractArtist(from audioFile: AVAudioFile) -> String? {
        return audioFile.fileFormat.settings["artist"] as? String
    }
    
    private func extractAlbum(from audioFile: AVAudioFile) -> String? {
        return audioFile.fileFormat.settings["album"] as? String
    }
    
    private func determineFormat(from url: URL) -> Track.AudioFormat {
        return Track.AudioFormat(rawValue: url.pathExtension.lowercased()) ?? .mp3
    }
    
    // MARK: - Configuration Updates
    private func updateConfigurationFromOptimizations(_ adaptiveConfig: MacOSOptimizations.AdaptiveConfiguration) {
        configuration.adaptiveQuality = true
        
        switch adaptiveConfig.energyMode {
        case .powerSaver:
            configuration.enableHighQualityMode = false
            configuration.audioBufferSize = 1024
        case .balanced:
            configuration.enableHighQualityMode = true
            configuration.audioBufferSize = 512
        case .performance:
            configuration.enableHighQualityMode = true
            configuration.audioBufferSize = 256
        }
    }
    
    private func updateConfigurationFromFutureProofing(_ futureConfig: FutureProofing.AdaptiveConfig) {
        // Enable experimental features if available
        if futureConfig.experimentalFeatures && futureProofing.isFeatureAvailable("neuralAudioProcessing") {
            // Enable neural audio processing when available
        }
        
        if futureConfig.quantumFeatures && futureProofing.isFeatureAvailable("quantumRendering") {
            // Enable quantum rendering when available
        }
    }
    
    // MARK: - Event Handlers
    private func handleApplicationDidBecomeActive() {
        // Resume audio processing if needed
        if isPlaying && !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                Self.logger.error("Failed to restart audio engine: \(error)")
            }
        }
    }
    
    private func handleClearCaches() {
        assetCache.removeAllObjects()
        Self.logger.info("Cleared all caches")
    }
    
    private func handleReinitializeAudio() {
        audioEngine.stop()
        setupAudioEngine()
        Self.logger.info("Reinitialized audio engine")
    }
}

// MARK: - Audio Analyzer
@available(macOS 15.0, *)
private final class AudioAnalyzer: AVAudioNode {
    var analysisCallback: (([Float]) -> Void)?
    
    override var numberOfInputs: Int { return 1 }
    override var numberOfOutputs: Int { return 1 }
    
    override init() {
        super.init()
        
        // Install audio tap for analysis
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.analyzeBuffer(buffer)
        }
    }
    
    private func analyzeBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
        let spectrumData = performFFT(on: channelData, frameCount: frameCount)
        
        DispatchQueue.main.async { [weak self] in
            self?.analysisCallback?(spectrumData)
        }
    }
    
    private func performFFT(on data: UnsafeMutablePointer<Float>, frameCount: Int) -> [Float] {
        // Simplified FFT - in production use Accelerate framework
        var spectrum: [Float] = []
        let binsPerBar = frameCount / 75
        
        for i in 0..<75 {
            let startIndex = i * binsPerBar
            let endIndex = min(startIndex + binsPerBar, frameCount)
            
            var sum: Float = 0
            for j in startIndex..<endIndex {
                sum += abs(data[j])
            }
            
            let average = sum / Float(endIndex - startIndex)
            spectrum.append(min(average * 10, 1.0))
        }
        
        return spectrum
    }
}

// MARK: - Error Handlers
@available(macOS 15.0, *)
private struct AudioErrorHandler: ModernErrorHandling.ErrorHandler {
    func handle(_ error: ModernErrorHandling.WinampError, context: ModernErrorHandling.ErrorContext) async {
        switch error {
        case .audioInitializationFailed, .audioPlaybackFailed:
            // Try to recover by reinitializing audio
            NotificationCenter.default.post(name: .reinitializeAudio, object: nil)
        default:
            break
        }
    }
    
    func canHandle(_ error: ModernErrorHandling.WinampError) -> Bool {
        switch error {
        case .audioInitializationFailed, .audioFormatUnsupported, .audioDeviceNotFound, .audioPlaybackFailed:
            return true
        default:
            return false
        }
    }
}

@available(macOS 15.0, *)
private struct SkinErrorHandler: ModernErrorHandling.ErrorHandler {
    func handle(_ error: ModernErrorHandling.WinampError, context: ModernErrorHandling.ErrorContext) async {
        switch error {
        case .skinCorrupted, .skinNotFound:
            // Fall back to default skin
            NotificationCenter.default.post(name: .loadDefaultSkin, object: nil)
        default:
            break
        }
    }
    
    func canHandle(_ error: ModernErrorHandling.WinampError) -> Bool {
        switch error {
        case .skinNotFound, .skinCorrupted, .skinIncompatible, .skinMissingAssets:
            return true
        default:
            return false
        }
    }
}

@available(macOS 15.0, *)
private struct PerformanceErrorHandler: ModernErrorHandling.ErrorHandler {
    func handle(_ error: ModernErrorHandling.WinampError, context: ModernErrorHandling.ErrorContext) async {
        switch error {
        case .memoryPressureCritical:
            // Clear caches and reduce quality
            NotificationCenter.default.post(name: .clearCaches, object: nil)
            MacOSOptimizations.shared.enableLowPowerMode()
        default:
            break
        }
    }
    
    func canHandle(_ error: ModernErrorHandling.WinampError) -> Bool {
        switch error {
        case .memoryAllocationFailed, .memoryPressureCritical, .cacheEvictionFailed:
            return true
        default:
            return false
        }
    }
}