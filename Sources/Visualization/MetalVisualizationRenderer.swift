import Metal
import MetalKit
import Accelerate
import CoreAudio
import simd

/// High-performance Metal-based audio visualization renderer
/// Optimized for real-time spectrum analysis and oscilloscope rendering at up to 120Hz
class MetalVisualizationRenderer {
    
    // MARK: - Core Metal Resources
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Pipeline states for different visualization types
    private var spectrumPipelineState: MTLRenderPipelineState
    private var oscilloscopePipelineState: MTLRenderPipelineState
    private var particlePipelineState: MTLRenderPipelineState
    
    // Compute pipeline for FFT processing
    private var fftComputePipelineState: MTLComputePipelineState
    
    // Buffer management
    private var audioDataBuffer: MTLBuffer
    private var spectrumVertexBuffer: MTLBuffer
    private var oscilloscopeVertexBuffer: MTLBuffer
    private var uniformBuffer: MTLBuffer
    
    // FFT configuration using Accelerate framework
    private var fftSetup: FFTSetup
    private let fftSize: Int = 512
    private let log2FFTSize: vDSP_Length
    private var fftInputReal: [Float]
    private var fftInputImag: [Float]
    private var fftOutputReal: [Float]
    private var fftOutputImag: [Float]
    private var magnitudes: [Float]
    
    // Visualization parameters
    private var spectrumBars: [SpectrumBar] = []
    private var oscilloscopePoints: [OscilloscopePoint] = []
    private let maxSpectrumBars: Int = 64
    private let maxOscilloscopePoints: Int = 256
    
    // Performance optimization
    private var frameCounter: Int = 0
    private var lastUpdateTime: CFTimeInterval = 0
    private var isHighPerformanceMode: Bool = false
    
    // Audio processing
    private let audioProcessingQueue = DispatchQueue(label: "visualization.audio", qos: .userInitiated)
    private var smoothingFactor: Float = 0.8
    private var decayRate: Float = 0.05
    
    struct VisualizationUniforms {
        var projectionMatrix: simd_float4x4
        var time: Float
        var deltaTime: Float
        var barCount: Int32
        var amplitude: Float
        var colorLow: simd_float3
        var colorMid: simd_float3
        var colorHigh: simd_float3
        var glowIntensity: Float
    }
    
    struct SpectrumBar {
        var position: simd_float2
        var height: Float
        var color: simd_float4
        var velocity: Float
        var peak: Float
        var peakDecay: Float
    }
    
    struct OscilloscopePoint {
        var position: simd_float2
        var amplitude: Float
        var color: simd_float4
        var timestamp: Float
    }
    
    init(device: MTLDevice) throws {
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw VisualizationError.metalResourceCreationFailed
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            throw VisualizationError.metalResourceCreationFailed
        }
        self.library = library
        
        // Initialize FFT
        log2FFTSize = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2FFTSize, FFTRadix(kFFTRadix2))!
        
        fftInputReal = Array(repeating: 0.0, count: fftSize)
        fftInputImag = Array(repeating: 0.0, count: fftSize)
        fftOutputReal = Array(repeating: 0.0, count: fftSize)
        fftOutputImag = Array(repeating: 0.0, count: fftSize)
        magnitudes = Array(repeating: 0.0, count: fftSize / 2)
        
        // Create render pipeline states
        spectrumPipelineState = try Self.createSpectrumPipelineState(device: device, library: library)
        oscilloscopePipelineState = try Self.createOscilloscopePipelineState(device: device, library: library)
        particlePipelineState = try Self.createParticlePipelineState(device: device, library: library)
        
        // Create compute pipeline for FFT
        fftComputePipelineState = try Self.createFFTComputePipelineState(device: device, library: library)
        
        // Create buffers
        guard let audioBuffer = device.makeBuffer(length: fftSize * MemoryLayout<Float>.stride, options: .storageModeShared),
              let spectrumBuffer = device.makeBuffer(length: maxSpectrumBars * MemoryLayout<SpectrumBar>.stride, options: .storageModeShared),
              let oscilloscopeBuffer = device.makeBuffer(length: maxOscilloscopePoints * MemoryLayout<OscilloscopePoint>.stride, options: .storageModeShared),
              let uniformsBuffer = device.makeBuffer(length: MemoryLayout<VisualizationUniforms>.stride, options: .storageModeShared) else {
            throw VisualizationError.bufferCreationFailed
        }
        
        self.audioDataBuffer = audioBuffer
        self.spectrumVertexBuffer = spectrumBuffer
        self.oscilloscopeVertexBuffer = oscilloscopeBuffer
        self.uniformBuffer = uniformsBuffer
        
        initializeSpectrumBars()
        initializeOscilloscopePoints()
    }
    
    // MARK: - Pipeline State Creation
    
    private static func createSpectrumPipelineState(device: MTLDevice, library: MTLLibrary) throws -> MTLRenderPipelineState {
        guard let vertexFunction = library.makeFunction(name: "spectrum_vertex"),
              let fragmentFunction = library.makeFunction(name: "spectrum_fragment") else {
            throw VisualizationError.shaderLoadFailed
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable blending for glow effects
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private static func createOscilloscopePipelineState(device: MTLDevice, library: MTLLibrary) throws -> MTLRenderPipelineState {
        guard let vertexFunction = library.makeFunction(name: "oscilloscope_vertex"),
              let fragmentFunction = library.makeFunction(name: "oscilloscope_fragment") else {
            throw VisualizationError.shaderLoadFailed
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Configure for line rendering
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private static func createParticlePipelineState(device: MTLDevice, library: MTLLibrary) throws -> MTLRenderPipelineState {
        guard let vertexFunction = library.makeFunction(name: "particle_vertex"),
              let fragmentFunction = library.makeFunction(name: "particle_fragment") else {
            throw VisualizationError.shaderLoadFailed
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private static func createFFTComputePipelineState(device: MTLDevice, library: MTLLibrary) throws -> MTLComputePipelineState {
        guard let computeFunction = library.makeFunction(name: "fft_compute") else {
            throw VisualizationError.shaderLoadFailed
        }
        
        return try device.makeComputePipelineState(function: computeFunction)
    }
    
    // MARK: - Initialization
    
    private func initializeSpectrumBars() {
        let barWidth: Float = 2.0 / Float(maxSpectrumBars)
        
        for i in 0..<maxSpectrumBars {
            let x = -1.0 + Float(i) * barWidth + barWidth * 0.5
            spectrumBars.append(SpectrumBar(
                position: simd_float2(x, -1.0),
                height: 0.0,
                color: simd_float4(0, 1, 0, 1),
                velocity: 0.0,
                peak: 0.0,
                peakDecay: 0.0
            ))
        }
    }
    
    private func initializeOscilloscopePoints() {
        let stepX: Float = 2.0 / Float(maxOscilloscopePoints)
        
        for i in 0..<maxOscilloscopePoints {
            let x = -1.0 + Float(i) * stepX
            oscilloscopePoints.append(OscilloscopePoint(
                position: simd_float2(x, 0.0),
                amplitude: 0.0,
                color: simd_float4(0, 1, 0, 1),
                timestamp: 0.0
            ))
        }
    }
    
    // MARK: - Audio Processing
    
    /// Process audio data and update visualizations
    func updateAudioData(_ audioSamples: [Float]) {
        audioProcessingQueue.async { [weak self] in
            self?.processAudioSamples(audioSamples)
        }
    }
    
    private func processAudioSamples(_ samples: [Float]) {
        let sampleCount = min(samples.count, fftSize)
        
        // Copy samples to FFT input buffer
        for i in 0..<sampleCount {
            fftInputReal[i] = samples[i]
            fftInputImag[i] = 0.0
        }
        
        // Zero pad if necessary
        for i in sampleCount..<fftSize {
            fftInputReal[i] = 0.0
            fftInputImag[i] = 0.0
        }
        
        // Perform FFT using Accelerate framework
        performFFT()
        
        // Update spectrum bars
        updateSpectrumBars()
        
        // Update oscilloscope
        updateOscilloscope(samples)
    }
    
    private func performFFT() {
        var splitComplex = DSPSplitComplex(realp: &fftOutputReal, imagp: &fftOutputImag)
        var inputComplex = DSPSplitComplex(realp: &fftInputReal, imagp: &fftInputImag)
        
        // Perform forward FFT
        vDSP_fft_zop(fftSetup, &inputComplex, 1, &splitComplex, 1, log2FFTSize, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitudes
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(magnitudes.count))
        
        // Apply logarithmic scaling for better visualization
        var logMagnitudes = magnitudes
        var one: Float = 1.0
        vDSP_vdbcon(&magnitudes, 1, &one, &logMagnitudes, 1, vDSP_Length(magnitudes.count), 0)
        
        // Normalize to 0-1 range
        var minValue: Float = 0
        var maxValue: Float = 0
        vDSP_minv(&logMagnitudes, 1, &minValue, vDSP_Length(logMagnitudes.count))
        vDSP_maxv(&logMagnitudes, 1, &maxValue, vDSP_Length(logMagnitudes.count))
        
        if maxValue > minValue {
            var range = maxValue - minValue
            var negMinValue = -minValue
            vDSP_vsadd(&logMagnitudes, 1, &negMinValue, &logMagnitudes, 1, vDSP_Length(logMagnitudes.count))
            vDSP_vsdiv(&logMagnitudes, 1, &range, &magnitudes, 1, vDSP_Length(magnitudes.count))
        }
    }
    
    private func updateSpectrumBars() {
        let barsToUpdate = min(spectrumBars.count, magnitudes.count)
        let deltaTime = Float(CACurrentMediaTime() - lastUpdateTime)
        
        for i in 0..<barsToUpdate {
            let targetHeight = magnitudes[i] * 2.0 // Scale to -1 to 1 range
            let currentHeight = spectrumBars[i].height
            
            // Apply smoothing
            let smoothedHeight = currentHeight * smoothingFactor + targetHeight * (1.0 - smoothingFactor)
            
            // Apply physics-based animation
            let heightDiff = smoothedHeight - currentHeight
            spectrumBars[i].velocity += heightDiff * 10.0 // Spring constant
            spectrumBars[i].velocity *= 0.9 // Damping
            spectrumBars[i].height += spectrumBars[i].velocity * deltaTime
            
            // Peak hold logic
            if spectrumBars[i].height > spectrumBars[i].peak {
                spectrumBars[i].peak = spectrumBars[i].height
                spectrumBars[i].peakDecay = 0.0
            } else {
                spectrumBars[i].peakDecay += deltaTime
                if spectrumBars[i].peakDecay > 0.5 { // Hold peak for 0.5 seconds
                    spectrumBars[i].peak -= decayRate * deltaTime
                }
            }
            
            // Color mapping based on frequency and amplitude
            spectrumBars[i].color = calculateSpectrumColor(frequency: Float(i) / Float(barsToUpdate), amplitude: spectrumBars[i].height)
        }
    }
    
    private func updateOscilloscope(_ samples: [Float]) {
        let pointsToUpdate = min(oscilloscopePoints.count, samples.count)
        let currentTime = Float(CACurrentMediaTime())
        
        for i in 0..<pointsToUpdate {
            oscilloscopePoints[i].amplitude = samples[i]
            oscilloscopePoints[i].position.y = samples[i] * 0.8 // Scale amplitude
            oscilloscopePoints[i].timestamp = currentTime
            
            // Fade older points
            let age = currentTime - oscilloscopePoints[i].timestamp
            let alpha = max(0.0, 1.0 - age * 2.0)
            oscilloscopePoints[i].color.w = alpha
        }
    }
    
    private func calculateSpectrumColor(frequency: Float, amplitude: Float) -> simd_float4 {
        // Create color gradient based on frequency
        var color = simd_float4(0, 0, 0, 1)
        
        if frequency < 0.33 {
            // Low frequencies: Green to Yellow
            let t = frequency / 0.33
            color = simd_float4(t, 1.0, 0.0, 1.0)
        } else if frequency < 0.66 {
            // Mid frequencies: Yellow to Orange
            let t = (frequency - 0.33) / 0.33
            color = simd_float4(1.0, 1.0 - t * 0.5, 0.0, 1.0)
        } else {
            // High frequencies: Orange to Red
            let t = (frequency - 0.66) / 0.34
            color = simd_float4(1.0, 0.5 - t * 0.5, 0.0, 1.0)
        }
        
        // Modulate intensity based on amplitude
        color.xyz *= amplitude
        
        return color
    }
    
    // MARK: - Rendering
    
    /// Render spectrum analyzer visualization
    func renderSpectrum(in renderPassDescriptor: MTLRenderPassDescriptor, projectionMatrix: simd_float4x4) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw VisualizationError.renderingFailed
        }
        
        renderEncoder.setRenderPipelineState(spectrumPipelineState)
        
        // Update uniforms
        var uniforms = VisualizationUniforms(
            projectionMatrix: projectionMatrix,
            time: Float(CACurrentMediaTime()),
            deltaTime: Float(CACurrentMediaTime() - lastUpdateTime),
            barCount: Int32(spectrumBars.count),
            amplitude: 1.0,
            colorLow: simd_float3(0, 1, 0),
            colorMid: simd_float3(1, 1, 0),
            colorHigh: simd_float3(1, 0, 0),
            glowIntensity: 0.5
        )
        
        uniformBuffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<VisualizationUniforms>.stride)
        
        // Update spectrum vertex buffer
        let spectrumData = spectrumBars.withUnsafeBufferPointer { $0 }
        spectrumVertexBuffer.contents().copyMemory(from: spectrumData.baseAddress!, byteCount: spectrumBars.count * MemoryLayout<SpectrumBar>.stride)
        
        // Set buffers and draw
        renderEncoder.setVertexBuffer(spectrumVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        // Draw instanced quads for spectrum bars
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: spectrumBars.count)
        
        renderEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    /// Render oscilloscope visualization
    func renderOscilloscope(in renderPassDescriptor: MTLRenderPassDescriptor, projectionMatrix: simd_float4x4) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw VisualizationError.renderingFailed
        }
        
        renderEncoder.setRenderPipelineState(oscilloscopePipelineState)
        
        // Update uniforms
        var uniforms = VisualizationUniforms(
            projectionMatrix: projectionMatrix,
            time: Float(CACurrentMediaTime()),
            deltaTime: Float(CACurrentMediaTime() - lastUpdateTime),
            barCount: Int32(oscilloscopePoints.count),
            amplitude: 1.0,
            colorLow: simd_float3(0, 1, 0),
            colorMid: simd_float3(0, 1, 0),
            colorHigh: simd_float3(0, 1, 0),
            glowIntensity: 0.8
        )
        
        uniformBuffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<VisualizationUniforms>.stride)
        
        // Update oscilloscope vertex buffer
        let oscilloscopeData = oscilloscopePoints.withUnsafeBufferPointer { $0 }
        oscilloscopeVertexBuffer.contents().copyMemory(from: oscilloscopeData.baseAddress!, byteCount: oscilloscopePoints.count * MemoryLayout<OscilloscopePoint>.stride)
        
        // Set buffers and draw
        renderEncoder.setVertexBuffer(oscilloscopeVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        // Draw line strip for oscilloscope
        renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: oscilloscopePoints.count)
        
        renderEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    // MARK: - Performance Optimization
    
    func setHighPerformanceMode(_ enabled: Bool) {
        isHighPerformanceMode = enabled
        
        if enabled {
            smoothingFactor = 0.6 // Less smoothing for more responsive visuals
            decayRate = 0.08     // Faster decay
        } else {
            smoothingFactor = 0.8 // More smoothing for smoother visuals
            decayRate = 0.05     // Slower decay
        }
    }
    
    func getPerformanceMetrics() -> VisualizationPerformanceMetrics {
        return VisualizationPerformanceMetrics(
            frameRate: Float(frameCounter) / Float(CACurrentMediaTime() - lastUpdateTime),
            audioLatency: 0.0, // Would measure actual audio latency
            renderTime: 0.0    // Would measure render time
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
}

// MARK: - Supporting Types

struct VisualizationPerformanceMetrics {
    let frameRate: Float
    let audioLatency: Float
    let renderTime: Float
}

enum VisualizationError: Error, LocalizedError {
    case metalResourceCreationFailed
    case shaderLoadFailed
    case bufferCreationFailed
    case renderingFailed
    
    var errorDescription: String? {
        switch self {
        case .metalResourceCreationFailed:
            return "Failed to create Metal resources"
        case .shaderLoadFailed:
            return "Failed to load visualization shaders"
        case .bufferCreationFailed:
            return "Failed to create Metal buffers"
        case .renderingFailed:
            return "Visualization rendering failed"
        }
    }
}