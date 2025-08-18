import Foundation
import AVFoundation
import Accelerate
import MediaPlayer
import Combine

/// Comprehensive Audio Player Manager with visualization data, playlist support, and media controls
/// Provides real-time audio analysis for visualization and full playback control
@MainActor
final class AudioPlayerManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.7
    @Published var balance: Float = 0.0
    @Published var isRepeatEnabled = false
    @Published var isShuffleEnabled = false
    @Published var currentTrack: AudioTrack?
    @Published var playlist: [AudioTrack] = []
    @Published var currentTrackIndex = 0
    @Published var playbackError: AudioPlayerError?
    
    // Audio analysis data for visualizations
    @Published var frequencyData: [Float] = Array(repeating: 0, count: 512)
    @Published var waveformData: [Float] = Array(repeating: 0, count: 1024)
    @Published var currentAudioData: [Float] = []
    
    // Equalizer
    @Published var equalizerBands: [Float] = Array(repeating: 0, count: 10)
    @Published var isEqualizerEnabled = false
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    private var fftSetup: FFTSetup?
    private var audioFormat: AVAudioFormat?
    
    // Analysis
    private var analysisBuffer: AVAudioPCMBuffer?
    private let fftSize = 1024
    private var fftLog2n: vDSP_Length
    private var fftWeights: [Float]
    private var fftMagnitudes: [Float]
    
    // Playback state
    private var playbackStartTime: TimeInterval = 0
    private var pausedTime: TimeInterval = 0
    private var displayLink: CADisplayLink?
    
    // Media remote control
    private var remoteCommandCenter: MPRemoteCommandCenter
    private var nowPlayingInfoCenter: MPNowPlayingInfoCenter
    
    // Equalizer
    private var equalizerNode: AVAudioUnitEQ
    
    // Timer for updates
    private var updateTimer: Timer?
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        self.fftLog2n = vDSP_Length(log2(Float(fftSize)))
        self.fftWeights = Array(repeating: 0, count: fftSize / 2)
        self.fftMagnitudes = Array(repeating: 0, count: fftSize / 2)
        self.remoteCommandCenter = MPRemoteCommandCenter.shared()
        self.nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        self.equalizerNode = AVAudioUnitEQ(numberOfBands: 10)
        
        super.init()
        
        setupAudioEngine()
        setupFFT()
        setupMediaRemoteControls()
        setupEqualizer()
        startAnalysisTimer()
        
        // Load user preferences
        loadUserPreferences()
    }
    
    deinit {
        stopAnalysisTimer()
        audioEngine.stop()
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(equalizerNode)
        
        // Connect nodes: playerNode -> equalizer -> mainMixer -> output
        audioEngine.connect(playerNode, to: equalizerNode, format: nil)
        audioEngine.connect(equalizerNode, to: audioEngine.mainMixerNode, format: nil)
        
        // Setup tap for audio analysis
        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        // Start the engine
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
            playbackError = .engineFailure(error)
        }
    }
    
    private func setupFFT() {
        fftSetup = vDSP_create_fftsetup(fftLog2n, FFTRadix(kFFTRadix2))
        
        // Initialize analysis buffer
        if let format = audioEngine.mainMixerNode.outputFormat(forBus: 0) {
            analysisBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(fftSize))
        }
    }
    
    private func setupMediaRemoteControls() {
        // Play command
        remoteCommandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        // Pause command
        remoteCommandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // Stop command
        remoteCommandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        
        // Next track command
        remoteCommandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        // Previous track command
        remoteCommandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        
        // Seek command
        remoteCommandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: positionEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
        
        // Enable commands
        remoteCommandCenter.playCommand.isEnabled = true
        remoteCommandCenter.pauseCommand.isEnabled = true
        remoteCommandCenter.stopCommand.isEnabled = true
        remoteCommandCenter.nextTrackCommand.isEnabled = true
        remoteCommandCenter.previousTrackCommand.isEnabled = true
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
    }
    
    private func setupEqualizer() {
        // Setup 10-band equalizer with common frequencies
        let frequencies: [Float] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        
        for (index, frequency) in frequencies.enumerated() {
            let band = equalizerNode.bands[index]
            band.frequency = frequency
            band.bandwidth = 1.0
            band.filterType = .parametric
            band.gain = 0.0
            band.bypass = false
        }
    }
    
    private func startAnalysisTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }
    
    private func stopAnalysisTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Public Playback Methods
    
    func loadAudioFile(from url: URL) async throws {
        do {
            // Stop current playback
            stop()
            
            // Load the audio file
            let audioFile = try AVAudioFile(forReading: url)
            self.audioFile = audioFile
            self.audioFormat = audioFile.processingFormat
            
            // Create track object
            let track = try await AudioTrack(url: url, audioFile: audioFile)
            
            // Update state
            currentTrack = track
            duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            currentTime = 0
            
            // Update Now Playing info
            updateNowPlayingInfo()
            
            // Schedule the file for playback
            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                Task { @MainActor in
                    self?.handlePlaybackCompletion()
                }
            }
            
        } catch {
            throw AudioPlayerError.fileLoadingFailed(error)
        }
    }
    
    func play() {
        guard audioFile != nil else { return }
        
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                playbackError = .engineFailure(error)
                return
            }
        }
        
        playerNode.play()
        isPlaying = true
        playbackStartTime = CACurrentMediaTime() - pausedTime
        
        updateNowPlayingInfo()
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
        pausedTime = currentTime
        
        updateNowPlayingInfo()
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
        currentTime = 0
        pausedTime = 0
        playbackStartTime = 0
        
        // Reschedule the file if we have one
        if let audioFile = audioFile {
            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                Task { @MainActor in
                    self?.handlePlaybackCompletion()
                }
            }
        }
        
        updateNowPlayingInfo()
    }
    
    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }
        
        let wasPlaying = isPlaying
        stop()
        
        // Calculate frame position
        let sampleRate = audioFile.fileFormat.sampleRate
        let framePosition = AVAudioFramePosition(time * sampleRate)
        
        // Schedule from the new position
        playerNode.scheduleSegment(
            audioFile,
            startingFrame: framePosition,
            frameCount: AVAudioFrameCount(audioFile.length - framePosition),
            at: nil
        ) { [weak self] in
            Task { @MainActor in
                self?.handlePlaybackCompletion()
            }
        }
        
        currentTime = time
        pausedTime = time
        
        if wasPlaying {
            play()
        }
        
        updateNowPlayingInfo()
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        audioEngine.mainMixerNode.outputVolume = volume
        
        // Save preference
        UserDefaults.standard.set(volume, forKey: "AudioPlayerVolume")
    }
    
    func setBalance(_ newBalance: Float) {
        balance = max(-1, min(1, newBalance))
        audioEngine.mainMixerNode.pan = balance
        
        // Save preference
        UserDefaults.standard.set(balance, forKey: "AudioPlayerBalance")
    }
    
    // MARK: - Playlist Management
    
    func addToPlaylist(_ track: AudioTrack) {
        playlist.append(track)
    }
    
    func removeFromPlaylist(at index: Int) {
        guard index < playlist.count else { return }
        playlist.remove(at: index)
        
        // Adjust current index if necessary
        if currentTrackIndex > index {
            currentTrackIndex -= 1
        } else if currentTrackIndex == index && !playlist.isEmpty {
            currentTrackIndex = min(currentTrackIndex, playlist.count - 1)
        }
    }
    
    func clearPlaylist() {
        playlist.removeAll()
        currentTrackIndex = 0
    }
    
    func nextTrack() {
        guard !playlist.isEmpty else { return }
        
        if isShuffleEnabled {
            currentTrackIndex = Int.random(in: 0..<playlist.count)
        } else {
            currentTrackIndex = (currentTrackIndex + 1) % playlist.count
        }
        
        loadCurrentPlaylistTrack()
    }
    
    func previousTrack() {
        guard !playlist.isEmpty else { return }
        
        if isShuffleEnabled {
            currentTrackIndex = Int.random(in: 0..<playlist.count)
        } else {
            currentTrackIndex = currentTrackIndex > 0 ? currentTrackIndex - 1 : playlist.count - 1
        }
        
        loadCurrentPlaylistTrack()
    }
    
    private func loadCurrentPlaylistTrack() {
        guard currentTrackIndex < playlist.count else { return }
        
        let track = playlist[currentTrackIndex]
        Task {
            try await loadAudioFile(from: track.url)
            if isPlaying {
                play()
            }
        }
    }
    
    // MARK: - Equalizer
    
    func setEqualizerBand(_ band: Int, gain: Float) {
        guard band < equalizerBands.count else { return }
        
        equalizerBands[band] = gain
        equalizerNode.bands[band].gain = gain
        
        // Save preferences
        UserDefaults.standard.set(equalizerBands, forKey: "EqualizerBands")
    }
    
    func setEqualizerEnabled(_ enabled: Bool) {
        isEqualizerEnabled = enabled
        equalizerNode.bypass = !enabled
        
        UserDefaults.standard.set(enabled, forKey: "EqualizerEnabled")
    }
    
    func resetEqualizer() {
        for i in 0..<equalizerBands.count {
            setEqualizerBand(i, gain: 0)
        }
    }
    
    func loadEqualizerPreset(_ preset: EqualizerPreset) {
        for (index, gain) in preset.gains.enumerated() {
            setEqualizerBand(index, gain: gain)
        }
    }
    
    // MARK: - Audio Analysis
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData,
              let fftSetup = fftSetup else { return }
        
        let frameCount = Int(buffer.frameLength)
        let channelData = floatChannelData[0]
        
        // Prepare data for FFT
        var realParts = Array(UnsafeBufferPointer(start: channelData, count: min(frameCount, fftSize)))
        var imaginaryParts = Array(repeating: Float(0), count: fftSize)
        
        // Pad with zeros if necessary
        while realParts.count < fftSize {
            realParts.append(0)
        }
        
        // Perform FFT
        realParts.withUnsafeMutableBufferPointer { realPtr in
            imaginaryParts.withUnsafeMutableBufferPointer { imagPtr in
                var complex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(fftSetup, &complex, 1, fftLog2n, FFTDirection(FFT_FORWARD))
                
                // Calculate magnitudes
                vDSP_zvmags(&complex, 1, &fftMagnitudes, 1, vDSP_Length(fftSize / 2))
                
                // Convert to decibels and normalize
                var normalizedMagnitudes = fftMagnitudes.map { magnitude in
                    return magnitude > 0 ? log10(magnitude) * 10 : -80
                }
                
                // Normalize to 0-1 range
                let maxDB: Float = 0
                let minDB: Float = -80
                normalizedMagnitudes = normalizedMagnitudes.map { db in
                    return max(0, min(1, (db - minDB) / (maxDB - minDB)))
                }
                
                // Update frequency data on main thread
                Task { @MainActor in
                    self.frequencyData = Array(normalizedMagnitudes.prefix(512))
                    self.waveformData = Array(realParts.prefix(1024))
                    self.currentAudioData = self.frequencyData
                    
                    // Notify visualization system
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AudioDataUpdated"),
                        object: self.frequencyData
                    )
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateCurrentTime() {
        guard isPlaying else { return }
        
        let currentMediaTime = CACurrentMediaTime()
        currentTime = currentMediaTime - playbackStartTime
        
        if currentTime >= duration - 0.1 {
            handlePlaybackCompletion()
        }
    }
    
    private func handlePlaybackCompletion() {
        if isRepeatEnabled {
            seek(to: 0)
            play()
        } else if !playlist.isEmpty {
            nextTrack()
        } else {
            stop()
        }
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo: [String: Any] = [:]
        
        if let track = currentTrack {
            nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            
            if let artwork = track.artwork {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                    return artwork
                }
            }
        }
        
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    private func loadUserPreferences() {
        // Load volume and balance
        volume = UserDefaults.standard.float(forKey: "AudioPlayerVolume")
        if volume == 0 { volume = 0.7 } // Default value
        
        balance = UserDefaults.standard.float(forKey: "AudioPlayerBalance")
        
        // Load equalizer settings
        if let savedBands = UserDefaults.standard.array(forKey: "EqualizerBands") as? [Float] {
            equalizerBands = savedBands
            for (index, gain) in savedBands.enumerated() {
                if index < equalizerNode.bands.count {
                    equalizerNode.bands[index].gain = gain
                }
            }
        }
        
        isEqualizerEnabled = UserDefaults.standard.bool(forKey: "EqualizerEnabled")
        equalizerNode.bypass = !isEqualizerEnabled
        
        // Apply loaded settings
        setVolume(volume)
        setBalance(balance)
    }
}

// MARK: - Supporting Types

struct AudioTrack: Identifiable, Codable {
    let id = UUID()
    let url: URL
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let fileSize: Int64
    let format: String
    let sampleRate: Double
    let bitRate: Int
    let artwork: NSImage?
    
    init(url: URL, audioFile: AVAudioFile) async throws {
        self.url = url
        self.duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        self.format = audioFile.fileFormat.formatDescription.description
        self.sampleRate = audioFile.fileFormat.sampleRate
        self.bitRate = Int(audioFile.fileFormat.sampleRate * Double(audioFile.fileFormat.channelCount * 16))
        
        // Get file size
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        self.fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        // Extract metadata
        let asset = AVAsset(url: url)
        let metadata = try await asset.load(.metadata)
        
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var artwork: NSImage?
        
        for item in metadata {
            if let key = item.commonKey {
                switch key {
                case .commonKeyTitle:
                    if let titleValue = try? await item.load(.stringValue) {
                        title = titleValue
                    }
                case .commonKeyArtist:
                    if let artistValue = try? await item.load(.stringValue) {
                        artist = artistValue
                    }
                case .commonKeyAlbumName:
                    if let albumValue = try? await item.load(.stringValue) {
                        album = albumValue
                    }
                case .commonKeyArtwork:
                    if let artworkData = try? await item.load(.dataValue),
                       let image = NSImage(data: artworkData) {
                        artwork = image
                    }
                default:
                    break
                }
            }
        }
        
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
    }
}

enum AudioPlayerError: LocalizedError {
    case fileLoadingFailed(Error)
    case engineFailure(Error)
    case unsupportedFormat
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .fileLoadingFailed(let error):
            return "Failed to load audio file: \(error.localizedDescription)"
        case .engineFailure(let error):
            return "Audio engine error: \(error.localizedDescription)"
        case .unsupportedFormat:
            return "Unsupported audio format"
        case .permissionDenied:
            return "Permission denied to access audio file"
        }
    }
}

struct EqualizerPreset {
    let name: String
    let gains: [Float]
    
    static let presets: [EqualizerPreset] = [
        EqualizerPreset(name: "Flat", gains: Array(repeating: 0, count: 10)),
        EqualizerPreset(name: "Rock", gains: [4, 3, -1, -2, 1, 2, 4, 5, 5, 5]),
        EqualizerPreset(name: "Pop", gains: [2, 1, 0, -1, -2, -1, 0, 1, 2, 3]),
        EqualizerPreset(name: "Jazz", gains: [3, 2, 1, 0, -1, -1, 0, 1, 2, 3]),
        EqualizerPreset(name: "Classical", gains: [4, 3, 2, 1, -1, -2, 0, 2, 3, 4]),
        EqualizerPreset(name: "Bass Boost", gains: [6, 5, 3, 1, -1, -1, 0, 1, 2, 3]),
        EqualizerPreset(name: "Treble Boost", gains: [0, -1, -1, 0, 1, 2, 4, 5, 6, 6]),
        EqualizerPreset(name: "Vocal", gains: [-2, -1, 1, 3, 3, 2, 1, 0, -1, -2])
    ]
}