//
//  ComprehensiveVisualizationSystem.swift
//  Winamp for macOS - Complete 5-Mode Visualization System
//
//  Implements all classic Winamp visualization modes with Metal rendering
//

import Foundation
import Metal
import MetalKit
import Accelerate
import AVFoundation

/// Complete visualization system with all 5 classic Winamp modes
@MainActor
public final class ComprehensiveVisualizationSystem: NSObject {
    
    // MARK: - Visualization Modes
    
    public enum VisualizationMode: CaseIterable, Sendable {
        case spectrumBars      // Classic frequency bars
        case oscilloscope      // Waveform display
        case dots             // Scattered dots
        case fire             // Fire effect
        case tunnel           // 3D tunnel effect
        
        var displayName: String {
            switch self {
            case .spectrumBars: return "Spectrum Analyzer"
            case .oscilloscope: return "Oscilloscope"
            case .dots: return "Dot Matrix"
            case .fire: return "Fire Effect"
            case .tunnel: return "3D Tunnel"
            }
        }
        
        var description: String {
            switch self {
            case .spectrumBars: return "Classic Winamp frequency bars"
            case .oscilloscope: return "Real-time audio waveform"
            case .dots: return "Reactive dot visualization"
            case .fire: return "Audio-reactive flame effect"
            case .tunnel: return "Hypnotic 3D tunnel"
            }
        }
    }
    
    // MARK: - Properties
    
    private let metalView: MTKView
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineStates: [VisualizationMode: MTLRenderPipelineState] = [:]
    private var computePipelineStates: [VisualizationMode: MTLComputePipelineState] = [:]
    
    // Audio processing
    private let fftSetup: vDSP_DFT_Setup
    private let fftSize = 512
    private var audioBuffer: [Float] = []
    private var frequencyData: [Float] = []
    private var magnitudes: [Float] = []
    
    // Current state
    private(set) var currentMode: VisualizationMode = .spectrumBars
    private var isAnimating = false
    private var frameCount: UInt64 = 0
    
    // Performance monitoring
    private var lastFrameTime: CFTimeInterval = 0
    private var fps: Double = 0
    
    // MARK: - Color Schemes
    
    public struct ColorScheme: Sendable {
        let name: String
        let colors: [SIMD4<Float>]
        
        static let classic = ColorScheme(
            name: "Classic",
            colors: [
                SIMD4<Float>(0.0, 1.0, 0.0, 1.0),  // Green
                SIMD4<Float>(0.0, 0.8, 0.0, 1.0),
                SIMD4<Float>(0.0, 0.6, 0.0, 1.0)
            ]
        )
        
        static let fire = ColorScheme(
            name: "Fire",
            colors: [
                SIMD4<Float>(1.0, 0.0, 0.0, 1.0),  // Red
                SIMD4<Float>(1.0, 0.5, 0.0, 1.0),  // Orange
                SIMD4<Float>(1.0, 1.0, 0.0, 1.0)   // Yellow
            ]
        )
        
        static let ice = ColorScheme(
            name: "Ice",
            colors: [
                SIMD4<Float>(0.0, 0.5, 1.0, 1.0),  // Light blue
                SIMD4<Float>(0.0, 0.3, 0.8, 1.0),  // Medium blue
                SIMD4<Float>(0.0, 0.1, 0.6, 1.0)   // Dark blue
            ]
        )
        
        static let rainbow = ColorScheme(
            name: "Rainbow",
            colors: [
                SIMD4<Float>(1.0, 0.0, 0.0, 1.0),  // Red
                SIMD4<Float>(1.0, 0.5, 0.0, 1.0),  // Orange
                SIMD4<Float>(1.0, 1.0, 0.0, 1.0),  // Yellow
                SIMD4<Float>(0.0, 1.0, 0.0, 1.0),  // Green
                SIMD4<Float>(0.0, 0.0, 1.0, 1.0),  // Blue
                SIMD4<Float>(0.5, 0.0, 1.0, 1.0)   // Purple
            ]
        )
    }
    
    private var currentColorScheme = ColorScheme.classic
    
    // MARK: - Initialization
    
    public init(metalView: MTKView) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw VisualizationError.metalNotAvailable
        }
        
        self.device = device
        self.metalView = metalView
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw VisualizationError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
        
        // Initialize FFT
        guard let fftSetup = vDSP_DFT_zrop_CreateSetup(nil, UInt(fftSize), .FORWARD) else {
            throw VisualizationError.fftSetupFailed
        }
        self.fftSetup = fftSetup
        
        // Initialize buffers
        audioBuffer = Array(repeating: 0, count: fftSize)
        frequencyData = Array(repeating: 0, count: fftSize / 2)
        magnitudes = Array(repeating: 0, count: fftSize / 2)
        
        super.init()
        
        // Setup Metal view
        metalView.device = device
        metalView.delegate = self
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        // Configure for ProMotion displays
        metalView.preferredFramesPerSecond = 120
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        
        // Load shaders and create pipeline states
        try loadShaders()
    }
    
    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }
    
    // MARK: - Shader Loading
    
    private func loadShaders() throws {
        guard let library = device.makeDefaultLibrary() else {
            throw VisualizationError.shaderLibraryNotFound
        }
        
        // Load shaders for each visualization mode
        for mode in VisualizationMode.allCases {
            let vertexFunctionName = "\(mode)VertexShader"
            let fragmentFunctionName = "\(mode)FragmentShader"
            
            // Try to load shaders, use defaults if specific ones don't exist
            let vertexFunction = library.makeFunction(name: vertexFunctionName) 
                ?? library.makeFunction(name: "defaultVertexShader")
            let fragmentFunction = library.makeFunction(name: fragmentFunctionName)
                ?? library.makeFunction(name: "defaultFragmentShader")
            
            if let vertexFunction = vertexFunction,
               let fragmentFunction = fragmentFunction {
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertexFunction
                pipelineDescriptor.fragmentFunction = fragmentFunction
                pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
                
                // Enable blending for transparency
                pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
                pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                
                do {
                    let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                    pipelineStates[mode] = pipelineState
                } catch {
                    print("Failed to create pipeline state for \(mode): \(error)")
                }
            }
            
            // Create compute pipeline for effects that need it
            if mode == .fire || mode == .tunnel {
                let computeFunctionName = "\(mode)ComputeShader"
                if let computeFunction = library.makeFunction(name: computeFunctionName) {
                    do {
                        let computePipelineState = try device.makeComputePipelineState(function: computeFunction)
                        computePipelineStates[mode] = computePipelineState
                    } catch {
                        print("Failed to create compute pipeline for \(mode): \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Mode Switching
    
    public func setVisualizationMode(_ mode: VisualizationMode, animated: Bool = true) {
        guard mode != currentMode else { return }
        
        if animated {
            // Animate transition between modes
            isAnimating = true
            
            Task { @MainActor in
                // Fade out current visualization
                metalView.alpha = 0.0
                
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
                
                currentMode = mode
                
                // Fade in new visualization
                metalView.alpha = 1.0
                
                isAnimating = false
            }
        } else {
            currentMode = mode
        }
    }
    
    public func setColorScheme(_ scheme: ColorScheme) {
        currentColorScheme = scheme
    }
    
    // MARK: - Audio Processing
    
    public func updateAudioData(_ samples: [Float]) {
        guard samples.count >= fftSize else { return }
        
        // Copy audio data
        audioBuffer = Array(samples.prefix(fftSize))
        
        // Perform FFT
        performFFT()
        
        // Trigger redraw
        metalView.setNeedsDisplay()
    }
    
    private func performFFT() {
        var real = audioBuffer
        var imaginary = [Float](repeating: 0, count: fftSize)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imaginary)
        
        // Apply window function (Hamming)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hamm_window(&window, vDSP_Length(fftSize), 0)
        vDSP_vmul(audioBuffer, 1, window, 1, &real, 1, vDSP_Length(fftSize))
        
        // Perform FFT
        vDSP_DFT_Execute(fftSetup, 
                        splitComplex.realp, splitComplex.imagp,
                        splitComplex.realp, splitComplex.imagp)
        
        // Calculate magnitudes
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
        
        // Convert to dB scale and normalize
        var reference: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &reference, &frequencyData, 1, vDSP_Length(fftSize / 2), 1)
        
        // Normalize to 0-1 range
        var min: Float = 0
        var max: Float = 0
        vDSP_minv(frequencyData, 1, &min, vDSP_Length(fftSize / 2))
        vDSP_maxv(frequencyData, 1, &max, vDSP_Length(fftSize / 2))
        
        let range = max - min
        if range > 0 {
            var negMin = -min
            var scale = 1.0 / range
            vDSP_vsadd(frequencyData, 1, &negMin, &frequencyData, 1, vDSP_Length(fftSize / 2))
            vDSP_vsmul(frequencyData, 1, &scale, &frequencyData, 1, vDSP_Length(fftSize / 2))
        }
    }
    
    // MARK: - Rendering
    
    private func renderVisualization(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let pipelineState = pipelineStates[currentMode] else {
            return
        }
        
        // Update frame count
        frameCount += 1
        
        // Calculate FPS
        let currentTime = CACurrentMediaTime()
        if lastFrameTime > 0 {
            fps = 1.0 / (currentTime - lastFrameTime)
        }
        lastFrameTime = currentTime
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Render based on current mode
        switch currentMode {
        case .spectrumBars:
            renderSpectrumBars(encoder: renderEncoder)
        case .oscilloscope:
            renderOscilloscope(encoder: renderEncoder)
        case .dots:
            renderDots(encoder: renderEncoder)
        case .fire:
            renderFire(encoder: renderEncoder)
        case .tunnel:
            renderTunnel(encoder: renderEncoder)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - Individual Visualization Renderers
    
    private func renderSpectrumBars(encoder: MTLRenderCommandEncoder) {
        let barCount = 75 // Classic Winamp bar count
        let barWidth: Float = 2.0 / Float(barCount)
        
        var vertices: [Float] = []
        var colors: [Float] = []
        
        for i in 0..<barCount {
            let frequencyIndex = min(i * (fftSize / 2) / barCount, fftSize / 2 - 1)
            let magnitude = frequencyData[frequencyIndex]
            
            let x = Float(i) * barWidth - 1.0
            let height = magnitude * 2.0 - 1.0
            
            // Create bar vertices (two triangles)
            vertices.append(contentsOf: [
                x, -1.0,
                x + barWidth * 0.8, -1.0,
                x, height,
                x + barWidth * 0.8, height
            ])
            
            // Color based on height
            let colorIndex = min(Int(magnitude * Float(currentColorScheme.colors.count - 1)), 
                                currentColorScheme.colors.count - 1)
            let color = currentColorScheme.colors[colorIndex]
            
            for _ in 0..<4 {
                colors.append(contentsOf: [color.x, color.y, color.z, color.w])
            }
        }
        
        if !vertices.isEmpty {
            encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Float>.size, index: 0)
            encoder.setVertexBytes(colors, length: colors.count * MemoryLayout<Float>.size, index: 1)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count / 2)
        }
    }
    
    private func renderOscilloscope(encoder: MTLRenderCommandEncoder) {
        var vertices: [Float] = []
        let sampleCount = min(audioBuffer.count, 256)
        
        for i in 0..<sampleCount {
            let x = Float(i) / Float(sampleCount - 1) * 2.0 - 1.0
            let y = audioBuffer[i] * 0.8 // Scale to fit
            vertices.append(contentsOf: [x, y])
        }
        
        if !vertices.isEmpty {
            let color = currentColorScheme.colors[0]
            encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Float>.size, index: 0)
            encoder.setVertexBytes([color.x, color.y, color.z, color.w], 
                                 length: 4 * MemoryLayout<Float>.size, index: 1)
            encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertices.count / 2)
        }
    }
    
    private func renderDots(encoder: MTLRenderCommandEncoder) {
        var vertices: [Float] = []
        var colors: [Float] = []
        let dotCount = 64
        
        for i in 0..<dotCount {
            let frequencyIndex = i * (fftSize / 2) / dotCount
            let magnitude = frequencyData[frequencyIndex]
            
            // Scatter dots based on frequency and magnitude
            let angle = Float(i) / Float(dotCount) * Float.pi * 2
            let radius = magnitude
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            
            vertices.append(contentsOf: [x, y])
            
            // Vary color based on magnitude
            let colorIntensity = magnitude
            let color = SIMD4<Float>(
                currentColorScheme.colors[0].x * colorIntensity,
                currentColorScheme.colors[0].y * colorIntensity,
                currentColorScheme.colors[0].z * colorIntensity,
                1.0
            )
            colors.append(contentsOf: [color.x, color.y, color.z, color.w])
        }
        
        if !vertices.isEmpty {
            encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Float>.size, index: 0)
            encoder.setVertexBytes(colors, length: colors.count * MemoryLayout<Float>.size, index: 1)
            encoder.drawPrimitives(type: .points, vertexStart: 0, vertexCount: vertices.count / 2)
        }
    }
    
    private func renderFire(encoder: MTLRenderCommandEncoder) {
        // Fire effect would use compute shaders for particle simulation
        // For now, render a simplified version using frequency data
        
        var vertices: [Float] = []
        var colors: [Float] = []
        
        for i in 0..<32 {
            let frequencyIndex = i * (fftSize / 2) / 32
            let magnitude = frequencyData[frequencyIndex]
            
            // Create flame-like shapes
            let x = Float(i) / 31.0 * 2.0 - 1.0
            let baseY: Float = -1.0
            let height = magnitude * 1.5
            
            // Multiple layers for flame effect
            for layer in 0..<3 {
                let layerOffset = Float(layer) * 0.1
                let layerHeight = height * (1.0 - Float(layer) * 0.3)
                
                vertices.append(contentsOf: [
                    x - 0.03, baseY,
                    x + 0.03, baseY,
                    x, baseY + layerHeight
                ])
                
                // Fire colors
                let colorIndex = min(layer, currentColorScheme.colors.count - 1)
                let color = ColorScheme.fire.colors[colorIndex]
                let alpha = 1.0 - Float(layer) * 0.3
                
                for _ in 0..<3 {
                    colors.append(contentsOf: [color.x, color.y, color.z, alpha])
                }
            }
        }
        
        if !vertices.isEmpty {
            encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Float>.size, index: 0)
            encoder.setVertexBytes(colors, length: colors.count * MemoryLayout<Float>.size, index: 1)
            encoder.drawPrimitives(type: .triangles, vertexStart: 0, vertexCount: vertices.count / 2)
        }
    }
    
    private func renderTunnel(encoder: MTLRenderCommandEncoder) {
        // 3D tunnel effect with rotation based on audio
        let rings = 16
        let segments = 32
        var vertices: [Float] = []
        var colors: [Float] = []
        
        let time = Float(frameCount) * 0.01
        let audioIntensity = frequencyData.reduce(0, +) / Float(frequencyData.count)
        
        for ring in 0..<rings {
            let z = Float(ring) / Float(rings - 1) * 2.0 - 1.0
            let radius = 0.5 + audioIntensity * 0.3 * sin(z * 3 + time)
            
            for segment in 0..<segments {
                let angle = Float(segment) / Float(segments) * Float.pi * 2
                let x = cos(angle + time * 0.5) * radius
                let y = sin(angle + time * 0.5) * radius
                
                vertices.append(contentsOf: [x, y, z])
                
                // Color based on position and audio
                let colorIntensity = (z + 1.0) * 0.5 * audioIntensity
                let color = currentColorScheme.colors[ring % currentColorScheme.colors.count]
                colors.append(contentsOf: [
                    color.x * colorIntensity,
                    color.y * colorIntensity,
                    color.z * colorIntensity,
                    1.0
                ])
            }
        }
        
        if !vertices.isEmpty {
            encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Float>.size, index: 0)
            encoder.setVertexBytes(colors, length: colors.count * MemoryLayout<Float>.size, index: 1)
            encoder.drawPrimitives(type: .points, vertexStart: 0, vertexCount: vertices.count / 3)
        }
    }
    
    // MARK: - Performance Monitoring
    
    public func getCurrentFPS() -> Double {
        return fps
    }
    
    public func getVisualizationMetrics() -> VisualizationMetrics {
        return VisualizationMetrics(
            fps: fps,
            mode: currentMode,
            frameCount: frameCount,
            audioBufferSize: audioBuffer.count,
            frequencyBins: frequencyData.count
        )
    }
}

// MARK: - MTKViewDelegate

extension ComprehensiveVisualizationSystem: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view resize if needed
    }
    
    public func draw(in view: MTKView) {
        renderVisualization(in: view)
    }
}

// MARK: - Supporting Types

public struct VisualizationMetrics: Sendable {
    public let fps: Double
    public let mode: ComprehensiveVisualizationSystem.VisualizationMode
    public let frameCount: UInt64
    public let audioBufferSize: Int
    public let frequencyBins: Int
}

public enum VisualizationError: LocalizedError {
    case metalNotAvailable
    case commandQueueCreationFailed
    case shaderLibraryNotFound
    case pipelineStateCreationFailed
    case fftSetupFailed
    
    public var errorDescription: String? {
        switch self {
        case .metalNotAvailable:
            return "Metal is not available on this device"
        case .commandQueueCreationFailed:
            return "Failed to create Metal command queue"
        case .shaderLibraryNotFound:
            return "Failed to load shader library"
        case .pipelineStateCreationFailed:
            return "Failed to create render pipeline state"
        case .fftSetupFailed:
            return "Failed to setup FFT for audio processing"
        }
    }
}