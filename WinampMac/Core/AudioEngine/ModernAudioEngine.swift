import Foundation
import AVFoundation
import Accelerate
import CoreAudio
import MediaPlayer
import Combine
import AppKit

/// Modern audio engine for WinampMac using AVAudioEngine with 10-band EQ and FFT
/// Optimized for Apple Silicon with hardware acceleration
@MainActor
public final class ModernAudioEngine: NSObject, ObservableObject {
    
    // MARK: - Core Audio Components
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let equalizer = AVAudioUnitEQ(numberOfBands: 10)
    private let mixer = AVAudioMixerNode()
    
    // MARK: - Audio Processing
    private var audioFile: AVAudioFile?
    private var audioBuffer: AVAudioPCMBuffer?
    private var currentPosition: AVAudioFramePosition = 0
    
    // MARK: - FFT Processing
    private let fftSetup: vDSP_DFT_Setup?
    private let fftSize: Int = 1024
    private var fftBuffer: [Float] = []
    private var spectrumData: [Float] = Array(repeating: 0, count: 64)
    private var waveformData: [Float] = Array(repeating: 0, count: 512)
    
    // MARK: - Audio Analysis
    private var isAudioTapInstalled: Bool = false
    private let analysisQueue = DispatchQueue(label: "com.winamp.audio.analysis", qos: .userInteractive)
    
    // MARK: - Playback State
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0
    @Published public private(set) var volume: Float = 1.0
    @Published public private(set) var balance: Float = 0.0
    
    // MARK: - Equalizer State
    @Published public private(set) var equalizerBands: [EqualizerBand] = []
    @Published public private(set) var isEqualizerEnabled: Bool = true
    
    // MARK: - Visualization Data
    @Published public private(set) var spectrumAnalysis: [Float] = Array(repeating: 0, count: 64)
    @Published public private(set) var waveformAnalysis: [Float] = Array(repeating: 0, count: 512)
    @Published public private(set) var vuLevels: (left: Float, right: Float) = (0, 0)
    
    // MARK: - Supported Formats
    public let supportedFormats: Set<String> = [
        "mp3", "m4a", "wav", "aiff", "flac", "aac", "m4p", "mp4"
    ]
    
    public override init() {
        // Initialize FFT setup
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        fftBuffer = Array(repeating: 0, count: fftSize * 2)
        
        super.init()
        
        setupEqualizer()
        setupAudioEngine()
        setupAudioSession()
        setupMediaRemoteCommands()
    }
    
    deinit {
        stopEngine()
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }
    
    // MARK: - Engine Setup
    private func setupAudioEngine() {
        // Attach nodes to engine
        audioEngine.attach(playerNode)
        audioEngine.attach(equalizer)
        audioEngine.attach(mixer)
        
        // Connect audio nodes
        audioEngine.connect(playerNode, to: equalizer, format: nil)
        audioEngine.connect(equalizer, to: mixer, format: nil)
        audioEngine.connect(mixer, to: audioEngine.outputNode, format: nil)
        
        // Prepare engine
        audioEngine.prepare()
    }
    
    private func setupEqualizer() {
        // Configure 10-band equalizer with standard frequencies
        let frequencies: [Float] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        
        for (index, frequency) in frequencies.enumerated() {
            let band = equalizer.bands[index]
            band.frequency = frequency
            band.gain = 0.0
            band.bandwidth = 1.0
            band.filterType = .parametric
            band.bypass = false
            
            let equalizerBand = EqualizerBand(
                frequency: frequency,
                gain: 0.0,
                index: index
            )
            equalizerBands.append(equalizerBand)
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            Task {
                await ErrorReporter.shared.reportError(
                    .audioEngineInitializationFailed(reason: error.localizedDescription),
                    context: "Audio session setup"
                )
            }
        }
    }
    
    private func setupMediaRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
    }
    
    // MARK: - Audio Loading
    public func loadAudioFile(from url: URL) async throws {
        // Validate file format
        let fileExtension = url.pathExtension.lowercased()
        guard supportedFormats.contains(fileExtension) else {
            throw WinampError.audioFormatUnsupported(format: fileExtension)
        }
        
        // Load audio file
        do {
            let audioFile = try AVAudioFile(forReading: url)
            self.audioFile = audioFile
            
            // Update duration
            let sampleRate = audioFile.processingFormat.sampleRate
            duration = Double(audioFile.length) / sampleRate
            
            // Reset position
            currentPosition = 0
            currentTime = 0
            
            // Setup audio tap for analysis
            setupAudioTap()
            
            // Update Now Playing info
            updateNowPlayingInfo(for: url)
            
        } catch {
            throw WinampError.audioEngineInitializationFailed(reason: error.localizedDescription)
        }
    }
    
    private func setupAudioTap() {
        // Remove existing tap
        if isAudioTapInstalled {
            playerNode.removeTap(onBus: 0)
            isAudioTapInstalled = false
        }
        
        guard let audioFile = audioFile else { return }
        
        let format = audioFile.processingFormat
        
        playerNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        isAudioTapInstalled = true
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        analysisQueue.async { [weak self] in
            self?.performFFTAnalysis(buffer)
            self?.calculateVULevels(buffer)
        }
    }
    
    // MARK: - FFT Analysis
    nonisolated private func performFFTAnalysis(_ buffer: AVAudioPCMBuffer) {
        guard let fftSetup = fftSetup,
              let channelData = buffer.floatChannelData else { return }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Mix channels to mono if stereo
        var monoData = Array(repeating: Float(0), count: min(frameCount, fftSize))
        
        if channelCount == 1 {
            // Mono
            for i in 0..<monoData.count {
                monoData[i] = channelData[0][i]
            }
        } else {
            // Stereo - mix to mono
            for i in 0..<monoData.count {
                monoData[i] = (channelData[0][i] + channelData[1][i]) * 0.5
            }
        }
        
        // Apply window function (Hann window)
        var windowedData = Array(repeating: Float(0), count: fftSize)
        for i in 0..<min(monoData.count, fftSize) {
            let window = 0.5 * (1.0 - cos(2.0 * .pi * Float(i) / Float(fftSize - 1)))
            windowedData[i] = monoData[i] * window
        }
        
        // Prepare complex data for FFT
        var realPart = Array(repeating: Float(0), count: fftSize)
        var imagPart = Array(repeating: Float(0), count: fftSize)
        
        for i in 0..<fftSize {
            realPart[i] = windowedData[i]
        }
        
        // Perform FFT
        vDSP_DFT_Execute(fftSetup, &realPart, &imagPart, &realPart, &imagPart)
        
        // Calculate magnitude spectrum
        var magnitudes = Array(repeating: Float(0), count: fftSize / 2)
        for i in 0..<magnitudes.count {
            magnitudes[i] = sqrt(realPart[i] * realPart[i] + imagPart[i] * imagPart[i])
        }
        
        // Update on main queue
        Task { @MainActor in
            // Bin frequencies into 64 bands for visualization
            let spectrumBands = self.binFrequenciesToBands(magnitudes)
            self.spectrumAnalysis = spectrumBands
            self.waveformAnalysis = Array(monoData.prefix(512))
        }
    }
    
    private func binFrequenciesToBands(_ magnitudes: [Float]) -> [Float] {
        let bandCount = 64
        let bandsPerMagnitude = magnitudes.count / bandCount
        var bands = Array(repeating: Float(0), count: bandCount)
        
        for i in 0..<bandCount {
            let startIndex = i * bandsPerMagnitude
            let endIndex = min(startIndex + bandsPerMagnitude, magnitudes.count)
            
            var sum: Float = 0
            for j in startIndex..<endIndex {
                sum += magnitudes[j]
            }
            
            bands[i] = sum / Float(endIndex - startIndex)
            
            // Apply logarithmic scaling for better visualization
            bands[i] = log10(max(bands[i], 0.001)) * 0.2 + 1.0
            bands[i] = max(0, min(1, bands[i]))
        }
        
        return bands
    }
    
    nonisolated private func calculateVULevels(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        var leftLevel: Float = 0
        var rightLevel: Float = 0
        
        // Calculate RMS levels
        if channelCount >= 1 {
            var sum: Float = 0
            for i in 0..<frameCount {
                let sample = channelData[0][i]
                sum += sample * sample
            }
            leftLevel = sqrt(sum / Float(frameCount))
        }
        
        if channelCount >= 2 {
            var sum: Float = 0
            for i in 0..<frameCount {
                let sample = channelData[1][i]
                sum += sample * sample
            }
            rightLevel = sqrt(sum / Float(frameCount))
        } else {
            rightLevel = leftLevel
        }
        
        // Update on main queue
        DispatchQueue.main.async { [weak self] in
            self?.vuLevels = (leftLevel, rightLevel)
        }
    }
    
    // MARK: - Playback Control
    public func play() {
        guard let audioFile = audioFile else { return }
        
        do {
            // Start engine if needed
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            
            // Schedule audio file
            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    self?.currentPosition = 0
                    self?.currentTime = 0
                }
            }
            
            // Start playback
            playerNode.play()
            isPlaying = true
            
            // Start position tracking
            startPositionTracking()
            
        } catch {
            Task {
                await ErrorReporter.shared.reportError(
                    .audioEngineInitializationFailed(reason: error.localizedDescription),
                    context: "Starting playback"
                )
            }
        }
    }
    
    public func pause() {
        playerNode.pause()
        isPlaying = false
        stopPositionTracking()
    }
    
    public func stop() {
        playerNode.stop()
        isPlaying = false
        currentPosition = 0
        currentTime = 0
        stopPositionTracking()
    }
    
    public func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }
        
        let sampleRate = audioFile.processingFormat.sampleRate
        let targetFrame = AVAudioFramePosition(time * sampleRate)
        
        // Stop current playback
        playerNode.stop()
        
        // Create new buffer from seek position
        let frameCount = audioFile.length - targetFrame
        guard frameCount > 0 else { return }
        
        do {
            audioFile.framePosition = targetFrame
            
            // Schedule remaining audio
            playerNode.scheduleFile(audioFile, at: nil)
            
            currentPosition = targetFrame
            currentTime = time
            
            // Resume playback if was playing
            if isPlaying {
                playerNode.play()
            }
            
        } catch {
            Task {
                await ErrorReporter.shared.reportError(
                    .audioEngineInitializationFailed(reason: error.localizedDescription),
                    context: "Seeking to \(time)s"
                )
            }
        }
    }
    
    // MARK: - Position Tracking
    private var positionTimer: Timer?
    
    private func startPositionTracking() {
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCurrentPosition()
        }
    }
    
    private func stopPositionTracking() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
    
    private func updateCurrentPosition() {
        guard let audioFile = audioFile,
              let lastRenderTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime) else { return }
        
        let sampleRate = audioFile.processingFormat.sampleRate
        currentTime = Double(playerTime.sampleTime) / sampleRate
    }
    
    // MARK: - Volume and Balance
    public func setVolume(_ volume: Float) {
        let clampedVolume = max(0, min(1, volume))
        self.volume = clampedVolume
        mixer.outputVolume = clampedVolume
    }
    
    public func setBalance(_ balance: Float) {
        let clampedBalance = max(-1, min(1, balance))
        self.balance = clampedBalance
        
        // Apply balance to mixer
        mixer.pan = clampedBalance
    }
    
    // MARK: - Equalizer Control
    public func setEqualizerBandGain(_ gain: Float, for bandIndex: Int) {
        guard bandIndex < equalizer.bands.count else { return }
        
        let clampedGain = max(-12, min(12, gain))
        equalizer.bands[bandIndex].gain = clampedGain
        
        // Update local state
        if bandIndex < equalizerBands.count {
            equalizerBands[bandIndex].gain = clampedGain
        }
    }
    
    public func setEqualizerEnabled(_ enabled: Bool) {
        isEqualizerEnabled = enabled
        equalizer.bypass = !enabled
    }
    
    public func resetEqualizer() {
        for (index, band) in equalizer.bands.enumerated() {
            band.gain = 0.0
            if index < equalizerBands.count {
                equalizerBands[index].gain = 0.0
            }
        }
    }
    
    // MARK: - Playlist Control (Placeholder)
    public func nextTrack() {
        // To be implemented with playlist functionality
    }
    
    public func previousTrack() {
        // To be implemented with playlist functionality
    }
    
    // MARK: - Engine Management
    public func startEngine() throws {
        guard !audioEngine.isRunning else { return }
        try audioEngine.start()
    }
    
    public func stopEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        stopPositionTracking()
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo(for url: URL) {
        let fileName = url.deletingPathExtension().lastPathComponent
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: fileName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        // Add artwork if available
        if let artwork = extractArtwork(from: url) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                return artwork
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func extractArtwork(from url: URL) -> NSImage? {
        // Basic implementation - could be enhanced to extract embedded artwork
        return nil
    }
}

// MARK: - Supporting Types
public struct EqualizerBand: Identifiable, Sendable {
    public let id = UUID()
    public let frequency: Float
    public var gain: Float
    public let index: Int
    
    public init(frequency: Float, gain: Float, index: Int) {
        self.frequency = frequency
        self.gain = gain
        self.index = index
    }
}