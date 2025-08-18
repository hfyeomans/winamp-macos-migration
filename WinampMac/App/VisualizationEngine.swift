import Foundation
import MetalKit
import AVFoundation
import Combine

/// Advanced Visualization Engine with Metal rendering and multiple modes
/// Handles real-time audio visualization with recording and screenshot capabilities
@MainActor
final class VisualizationEngine: NSObject, ObservableObject {
    
    @Published var currentMode: VisualizationMode = .spectrum
    @Published var currentColorScheme: VisualizationColorScheme = .rainbow
    @Published var sensitivity: Float = 0.7
    @Published var smoothing: Float = 0.5
    @Published var currentFrameRate: Double = 60.0
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    
    // Metal rendering
    private var metalDevice: MTLDevice?
    private var metalCommandQueue: MTLCommandQueue?
    private var renderPipelineStates: [VisualizationMode: MTLRenderPipelineState] = [:]
    
    // Audio data
    private var audioData: [Float] = Array(repeating: 0, count: 512)
    private var smoothedData: [Float] = Array(repeating: 0, count: 512)
    private var previousData: [Float] = Array(repeating: 0, count: 512)
    
    // Recording
    private var videoWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingStartTime: CFTimeInterval = 0
    private var recordingTimer: Timer?
    
    // Performance monitoring
    private var frameTimeHistory: [CFTimeInterval] = []
    private var lastFrameTime: CFTimeInterval = 0
    
    // Rendering state
    private var isInitialized = false
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupMetal()
        setupShaders()
    }
    
    // MARK: - Public Methods
    
    func setMode(_ mode: VisualizationMode) {
        currentMode = mode
        // Trigger shader recompilation if needed
        NotificationCenter.default.post(
            name: NSNotification.Name("VisualizationModeChanged"),
            object: mode
        )
    }
    
    func setColorScheme(_ scheme: VisualizationColorScheme) {
        currentColorScheme = scheme
    }
    
    func setSensitivity(_ value: Float) {
        sensitivity = max(0, min(2, value))
    }
    
    func setSmoothing(_ value: Float) {
        smoothing = max(0, min(1, value))
    }
    
    func updateAudioData(_ newData: [Float]) {
        // Apply sensitivity
        let amplifiedData = newData.map { $0 * sensitivity }
        
        // Apply smoothing
        for i in 0..<min(smoothedData.count, amplifiedData.count) {
            smoothedData[i] = smoothedData[i] * smoothing + amplifiedData[i] * (1 - smoothing)
        }
        
        audioData = smoothedData
        previousData = audioData
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        recordingStartTime = CACurrentMediaTime()
        recordingDuration = 0
        
        setupVideoRecording()
        startRecordingTimer()
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }
        
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        finishVideoRecording(completion: completion)
    }
    
    func captureScreenshot(completion: @escaping (NSImage?) -> Void) {
        // Capture current visualization frame
        guard let metalDevice = metalDevice else {
            completion(nil)
            return
        }
        
        // Create render target for screenshot
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1920,
            height: 1080,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        
        guard let texture = metalDevice.makeTexture(descriptor: descriptor) else {
            completion(nil)
            return
        }
        
        // Render current frame to texture
        renderToTexture(texture) { success in
            if success {
                let image = self.createImageFromTexture(texture)
                completion(image)
            } else {
                completion(nil)
            }
        }
    }
    
    func resetToDefaults() {
        currentMode = .spectrum
        currentColorScheme = .rainbow
        sensitivity = 0.7
        smoothing = 0.5
    }
    
    // MARK: - Metal Setup
    
    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        guard let device = metalDevice else {
            print("Metal is not supported on this device")
            return
        }
        
        metalCommandQueue = device.makeCommandQueue()
        
        print("Metal device initialized: \(device.name)")
        isInitialized = true
    }
    
    private func setupShaders() {
        guard let device = metalDevice else { return }
        
        // Load shader library
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }
        
        // Create render pipeline states for each visualization mode
        for mode in VisualizationMode.allCases {
            createRenderPipelineState(for: mode, library: library)
        }
    }
    
    private func createRenderPipelineState(for mode: VisualizationMode, library: MTLLibrary) {
        guard let device = metalDevice else { return }
        
        let vertexFunctionName = "\(mode.shaderPrefix)_vertex"
        let fragmentFunctionName = "\(mode.shaderPrefix)_fragment"
        
        guard let vertexFunction = library.makeFunction(name: vertexFunctionName),
              let fragmentFunction = library.makeFunction(name: fragmentFunctionName) else {
            print("Failed to create shader functions for \(mode)")
            return
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable blending for some visualization modes
        if mode.requiresBlending {
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        
        do {
            let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            renderPipelineStates[mode] = pipelineState
        } catch {
            print("Failed to create render pipeline state for \(mode): \(error)")
        }
    }
    
    // MARK: - Rendering
    
    func render(to metalView: MTKView, in size: CGSize) {
        guard let device = metalDevice,
              let commandQueue = metalCommandQueue,
              let pipelineState = renderPipelineStates[currentMode],
              let drawable = metalView.currentDrawable else {
            return
        }
        
        let startTime = CACurrentMediaTime()
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Create render encoder
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Set pipeline state
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Encode visualization-specific rendering
        encodeVisualization(renderEncoder, mode: currentMode, size: size)
        
        renderEncoder.endEncoding()
        
        // Present drawable
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Update performance metrics
        updatePerformanceMetrics(startTime: startTime)
        
        // Add frame to recording if active
        if isRecording {
            addFrameToRecording(drawable.texture)
        }
    }
    
    private func encodeVisualization(_ encoder: MTLRenderCommandEncoder, mode: VisualizationMode, size: CGSize) {
        switch mode {
        case .spectrum:
            encodeSpectrumVisualization(encoder, size: size)
        case .oscilloscope:
            encodeOscilloscopeVisualization(encoder, size: size)
        case .bars3D:
            encode3DBarsVisualization(encoder, size: size)
        case .particles:
            encodeParticleVisualization(encoder, size: size)
        case .waveform:
            encodeWaveformVisualization(encoder, size: size)
        case .circular:
            encodeCircularVisualization(encoder, size: size)
        case .milkdrop:
            encodeMilkdropVisualization(encoder, size: size)
        }
    }
    
    private func encodeSpectrumVisualization(_ encoder: MTLRenderCommandEncoder, size: CGSize) {
        // Create vertex buffer for spectrum bars
        guard let device = metalDevice else { return }
        
        let barCount = min(audioData.count, 128)
        var vertices: [SpectrumVertex] = []
        
        let barWidth = Float(size.width) / Float(barCount)
        
        for i in 0..<barCount {
            let x = Float(i) * barWidth
            let height = audioData[i] * Float(size.height) * 0.8
            
            // Create two triangles for each bar
            let color = getColorForFrequency(Float(i) / Float(barCount))
            
            // Bottom left
            vertices.append(SpectrumVertex(position: [x, 0], color: color))
            // Bottom right
            vertices.append(SpectrumVertex(position: [x + barWidth, 0], color: color))
            // Top left
            vertices.append(SpectrumVertex(position: [x, height], color: color))
            
            // Top left
            vertices.append(SpectrumVertex(position: [x, height], color: color))
            // Bottom right
            vertices.append(SpectrumVertex(position: [x + barWidth, 0], color: color))
            // Top right
            vertices.append(SpectrumVertex(position: [x + barWidth, height], color: color))
        }
        
        let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<SpectrumVertex>.stride,
            options: []
        )
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }
    
    private func encodeOscilloscopeVisualization(_ encoder: MTLRenderCommandEncoder, size: CGSize) {
        // Implementation for oscilloscope visualization
        guard let device = metalDevice else { return }
        
        var vertices: [WaveformVertex] = []
        let stepX = Float(size.width) / Float(audioData.count - 1)
        
        for (index, value) in audioData.enumerated() {
            let x = Float(index) * stepX
            let y = Float(size.height) / 2 + value * Float(size.height) / 4
            let color = getColorForFrequency(Float(index) / Float(audioData.count))
            
            vertices.append(WaveformVertex(position: [x, y], color: color))
        }
        
        let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<WaveformVertex>.stride,
            options: []
        )
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertices.count)
    }
    
    private func encode3DBarsVisualization(_ encoder: MTLRenderCommandEncoder, size: CGSize) {
        // Implementation for 3D bars visualization
        // This would create a more complex 3D representation
    }
    
    private func encodeParticleVisualization(_ encoder: MTLRenderCommandEncoder, size: CGSize) {
        // Implementation for particle-based visualization
    }
    
    private func encodeWaveformVisualization(_ encoder: MTLRenderCommandEncoder, size: CGSize) {
        // Implementation for waveform visualization
    }
    
    private func encodeCircularVisualization(_ encoder: MTLRenderCommandEncoder, size: CGSize) {
        // Implementation for circular visualization
    }
    
    private func encodeMilkdropVisualization(_ encoder: MTLRenderCommandEncoder, size: CGSize) {
        // Implementation for MilkDrop-style visualization
    }
    
    // MARK: - Helper Methods
    
    private func getColorForFrequency(_ normalizedFrequency: Float) -> [Float] {
        let colors = currentColorScheme.colors
        let scaledFreq = normalizedFrequency * Float(colors.count - 1)
        let index = Int(scaledFreq)
        let fraction = scaledFreq - Float(index)
        
        if index >= colors.count - 1 {
            let color = colors.last!
            return [Float(color.cgColor?.components?[0] ?? 1),
                    Float(color.cgColor?.components?[1] ?? 1),
                    Float(color.cgColor?.components?[2] ?? 1),
                    1.0]
        }
        
        let color1 = colors[index]
        let color2 = colors[index + 1]
        
        // Interpolate between colors
        let r1 = Float(color1.cgColor?.components?[0] ?? 1)
        let g1 = Float(color1.cgColor?.components?[1] ?? 1)
        let b1 = Float(color1.cgColor?.components?[2] ?? 1)
        
        let r2 = Float(color2.cgColor?.components?[0] ?? 1)
        let g2 = Float(color2.cgColor?.components?[1] ?? 1)
        let b2 = Float(color2.cgColor?.components?[2] ?? 1)
        
        let r = r1 + (r2 - r1) * fraction
        let g = g1 + (g2 - g1) * fraction
        let b = b1 + (b2 - b1) * fraction
        
        return [r, g, b, 1.0]
    }
    
    private func updatePerformanceMetrics(startTime: CFTimeInterval) {
        let frameTime = CACurrentMediaTime() - startTime
        frameTimeHistory.append(frameTime)
        
        // Keep only last 60 frames for averaging
        if frameTimeHistory.count > 60 {
            frameTimeHistory.removeFirst()
        }
        
        let averageFrameTime = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        currentFrameRate = 1.0 / averageFrameTime
    }
    
    // MARK: - Recording
    
    private func setupVideoRecording() {
        let documentsPath = FileManager.default.urls(for: .documentsDirectory, in: .userDomainMask).first!
        let videoURL = documentsPath.appendingPathComponent("Visualization_\(Date().timeIntervalSince1970).mov")
        
        do {
            videoWriter = try AVAssetWriter(outputURL: videoURL, fileType: .mov)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 6000000
                ]
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 1920,
                kCVPixelBufferHeightKey as String: 1080
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: pixelBufferAttributes
            )
            
            if let videoInput = videoInput {
                videoWriter?.add(videoInput)
            }
            
            videoWriter?.startWriting()
            videoWriter?.startSession(atSourceTime: CMTime.zero)
            
        } catch {
            print("Failed to setup video recording: \(error)")
            isRecording = false
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration = CACurrentMediaTime() - self.recordingStartTime
        }
    }
    
    private func addFrameToRecording(_ texture: MTLTexture) {
        guard let videoInput = videoInput,
              let pixelBufferAdaptor = pixelBufferAdaptor,
              videoInput.isReadyForMoreMediaData else {
            return
        }
        
        let presentationTime = CMTime(seconds: recordingDuration, preferredTimescale: 600)
        
        // Convert Metal texture to CVPixelBuffer
        if let pixelBuffer = createPixelBuffer(from: texture) {
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }
    }
    
    private func createPixelBuffer(from texture: MTLTexture) -> CVPixelBuffer? {
        // Implementation would convert Metal texture to CVPixelBuffer
        // This is complex and would require additional Metal processing
        return nil
    }
    
    private func finishVideoRecording(completion: @escaping (URL?) -> Void) {
        guard let videoWriter = videoWriter else {
            completion(nil)
            return
        }
        
        videoInput?.markAsFinished()
        
        videoWriter.finishWriting { [weak self] in
            DispatchQueue.main.async {
                if videoWriter.status == .completed {
                    completion(videoWriter.outputURL)
                } else {
                    print("Video recording failed: \(videoWriter.error?.localizedDescription ?? "Unknown error")")
                    completion(nil)
                }
                
                self?.videoWriter = nil
                self?.videoInput = nil
                self?.pixelBufferAdaptor = nil
            }
        }
    }
    
    // MARK: - Screenshot
    
    private func renderToTexture(_ texture: MTLTexture, completion: @escaping (Bool) -> Void) {
        // Implementation would render current frame to provided texture
        completion(true)
    }
    
    private func createImageFromTexture(_ texture: MTLTexture) -> NSImage? {
        // Implementation would convert Metal texture to NSImage
        // This requires reading back texture data from GPU
        return nil
    }
}

// MARK: - Metal Vertex Structures

struct SpectrumVertex {
    let position: [Float]
    let color: [Float]
}

struct WaveformVertex {
    let position: [Float]
    let color: [Float]
}

// MARK: - Visualization Mode Extensions

extension VisualizationMode {
    var shaderPrefix: String {
        switch self {
        case .spectrum: return "spectrum"
        case .oscilloscope: return "oscilloscope"
        case .bars3D: return "bars3d"
        case .particles: return "particles"
        case .waveform: return "waveform"
        case .circular: return "circular"
        case .milkdrop: return "milkdrop"
        }
    }
    
    var requiresBlending: Bool {
        switch self {
        case .particles, .milkdrop: return true
        default: return false
        }
    }
}

// MARK: - Metal Renderer

final class MetalSkinRenderer: NSObject, MTKViewDelegate {
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var currentSkin: WinampSkin?
    private var currentSize: CGSize = .zero
    private var isShadeMode = false
    
    override init() {
        super.init()
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
    }
    
    func updateSkin(_ skin: WinampSkin, size: CGSize, isShadeMode: Bool) {
        currentSkin = skin
        currentSize = size
        self.isShadeMode = isShadeMode
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        currentSize = size
    }
    
    func draw(in view: MTKView) {
        guard let device = device,
              let commandQueue = commandQueue,
              let drawable = view.currentDrawable else {
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Render skin here
        if let skin = currentSkin {
            renderSkin(skin, encoder: renderEncoder, size: currentSize)
        }
        
        renderEncoder.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
    private func renderSkin(_ skin: WinampSkin, encoder: MTLRenderCommandEncoder, size: CGSize) {
        // Implementation would render the Winamp skin using Metal
        // This would involve texture mapping, bitmap rendering, etc.
    }
}