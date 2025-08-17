//
//  ModernVisualizerView.swift
//  WinampMac
//
//  Modern Metal-based visualization replacing deprecated NSOpenGLView
//  Compatible with macOS 15.0+ and future-proofed for macOS 26.x
//

import MetalKit
import Metal
import simd
import AVFoundation

/// Modern Metal-based visualizer view replacing deprecated NSOpenGLView
@available(macOS 15.0, *)
public final class ModernVisualizerView: MTKView {
    
    // MARK: - Metal Resources
    private var metalDevice: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState?
    private var spectrumBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?
    private var vertexBuffer: MTLBuffer?
    
    // MARK: - Visualization Data
    private var spectrumData: [Float] = Array(repeating: 0.0, count: 75)
    private var smoothedSpectrum: [Float] = Array(repeating: 0.0, count: 75)
    private let spectrumSmoothingFactor: Float = 0.8
    
    // MARK: - Visualization Settings
    private var visualizationMode: VisualizationMode = .spectrumBars
    private var colorScheme: VisualizationColorScheme = .classic
    private var isAnimating = true
    
    // MARK: - Performance Monitoring
    private var frameCount = 0
    private var lastFPSUpdate = CACurrentMediaTime()
    
    public enum VisualizationMode: CaseIterable {
        case spectrumBars
        case oscilloscope
        case dots
        case fire
        case tunnel
        
        var description: String {
            switch self {
            case .spectrumBars: return "Spectrum Bars"
            case .oscilloscope: return "Oscilloscope"
            case .dots: return "Dots"
            case .fire: return "Fire"
            case .tunnel: return "Tunnel"
            }
        }
    }
    
    public enum VisualizationColorScheme: CaseIterable {
        case classic
        case rainbow
        case fire
        case ice
        case matrix
        
        var colors: [simd_float3] {
            switch self {
            case .classic:
                return [
                    simd_float3(0.0, 1.0, 0.0),  // Green
                    simd_float3(0.0, 0.8, 0.2),
                    simd_float3(0.2, 0.6, 0.4),
                    simd_float3(0.4, 1.0, 0.0),
                    simd_float3(1.0, 1.0, 0.0),  // Yellow
                    simd_float3(1.0, 0.5, 0.0),  // Orange
                    simd_float3(1.0, 0.0, 0.0)   // Red
                ]
            case .rainbow:
                return [
                    simd_float3(1.0, 0.0, 0.0),  // Red
                    simd_float3(1.0, 0.5, 0.0),  // Orange
                    simd_float3(1.0, 1.0, 0.0),  // Yellow
                    simd_float3(0.0, 1.0, 0.0),  // Green
                    simd_float3(0.0, 0.0, 1.0),  // Blue
                    simd_float3(0.3, 0.0, 0.7),  // Indigo
                    simd_float3(0.5, 0.0, 1.0)   // Violet
                ]
            case .fire:
                return [
                    simd_float3(0.1, 0.0, 0.0),  // Dark red
                    simd_float3(0.5, 0.0, 0.0),  // Red
                    simd_float3(1.0, 0.3, 0.0),  // Orange-red
                    simd_float3(1.0, 0.6, 0.0),  // Orange
                    simd_float3(1.0, 1.0, 0.0),  // Yellow
                    simd_float3(1.0, 1.0, 0.5),  // Light yellow
                    simd_float3(1.0, 1.0, 1.0)   // White
                ]
            case .ice:
                return [
                    simd_float3(0.0, 0.0, 0.3),  // Dark blue
                    simd_float3(0.0, 0.2, 0.8),  // Blue
                    simd_float3(0.0, 0.6, 1.0),  // Light blue
                    simd_float3(0.2, 0.8, 1.0),  // Cyan
                    simd_float3(0.6, 1.0, 1.0),  // Light cyan
                    simd_float3(0.8, 1.0, 1.0),  // Very light cyan
                    simd_float3(1.0, 1.0, 1.0)   // White
                ]
            case .matrix:
                return [
                    simd_float3(0.0, 0.1, 0.0),  // Dark green
                    simd_float3(0.0, 0.3, 0.0),  // Green
                    simd_float3(0.0, 0.6, 0.0),  // Bright green
                    simd_float3(0.2, 0.8, 0.0),  // Yellow-green
                    simd_float3(0.4, 1.0, 0.0),  // Lime
                    simd_float3(0.6, 1.0, 0.2),  // Light lime
                    simd_float3(0.8, 1.0, 0.8)   // Very light green
                ]
            }
        }
    }
    
    // MARK: - Uniforms Structure
    struct Uniforms {
        var projectionMatrix: simd_float4x4
        var time: Float
        var barCount: Int32
        var visualizationMode: Int32
        var colorScheme: Int32
        var amplitude: Float
        var smoothing: Float
        var reserved: Int32 // For future expansion
    }
    
    // MARK: - Initialization
    public override init(frame frameRect: NSRect, device: MTLDevice?) {
        guard let device = device ?? MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        self.metalDevice = device
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = commandQueue
        
        super.init(frame: frameRect, device: device)
        
        self.device = device
        self.colorPixelFormat = .bgra8Unorm
        self.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        self.isOpaque = false
        self.framebufferOnly = false
        
        setupMetal()
        setupBuffers()
        
        // Enable high refresh rate on supported displays
        if #available(macOS 12.0, *) {
            self.preferredFramesPerSecond = 120
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Metal Setup
    private func setupMetal() {
        guard let library = metalDevice.makeDefaultLibrary() else {
            fatalError("Failed to create Metal library")
        }
        
        guard let vertexFunction = library.makeFunction(name: "visualizer_vertex"),
              let fragmentFunction = library.makeFunction(name: "visualizer_fragment") else {
            fatalError("Failed to load Metal functions")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        
        // Enable blending for transparency
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            renderPipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create Metal render pipeline state: \(error)")
        }
    }
    
    private func setupBuffers() {
        // Create spectrum data buffer
        let spectrumBufferSize = spectrumData.count * MemoryLayout<Float>.size
        spectrumBuffer = metalDevice.makeBuffer(length: spectrumBufferSize, options: .storageModeShared)
        spectrumBuffer?.label = "Spectrum Data Buffer"
        
        // Create uniforms buffer
        let uniformsBufferSize = MemoryLayout<Uniforms>.size
        uniformBuffer = metalDevice.makeBuffer(length: uniformsBufferSize, options: .storageModeShared)
        uniformBuffer?.label = "Uniforms Buffer"
        
        // Create vertex buffer for bar geometry
        setupVertexBuffer()
    }
    
    private func setupVertexBuffer() {
        // Create vertices for spectrum bars
        var vertices: [simd_float2] = []
        
        let barCount = spectrumData.count
        let barWidth = 2.0 / Float(barCount)
        
        for i in 0..<barCount {
            let x = Float(i) * barWidth - 1.0 + barWidth * 0.5
            
            // Each bar is a quad (2 triangles)
            vertices.append(simd_float2(x - barWidth * 0.4, 0.0))  // Bottom left
            vertices.append(simd_float2(x + barWidth * 0.4, 0.0))  // Bottom right
            vertices.append(simd_float2(x - barWidth * 0.4, 1.0))  // Top left
            
            vertices.append(simd_float2(x + barWidth * 0.4, 0.0))  // Bottom right
            vertices.append(simd_float2(x + barWidth * 0.4, 1.0))  // Top right
            vertices.append(simd_float2(x - barWidth * 0.4, 1.0))  // Top left
        }
        
        let vertexBufferSize = vertices.count * MemoryLayout<simd_float2>.size
        vertexBuffer = metalDevice.makeBuffer(bytes: vertices, length: vertexBufferSize, options: .storageModeShared)
        vertexBuffer?.label = "Vertex Buffer"
    }
    
    // MARK: - Public Interface
    public func updateSpectrum(_ newData: [Float]) {
        guard newData.count > 0 else { return }
        
        // Resample data to match our bar count if necessary
        let targetData: [Float]
        if newData.count == spectrumData.count {
            targetData = newData
        } else {
            targetData = resampleSpectrum(newData, targetCount: spectrumData.count)
        }
        
        // Apply smoothing to reduce flickering
        for i in 0..<spectrumData.count {
            let target = min(targetData[i], 1.0) // Clamp to [0, 1]
            smoothedSpectrum[i] = smoothedSpectrum[i] * spectrumSmoothingFactor + target * (1.0 - spectrumSmoothingFactor)
            spectrumData[i] = smoothedSpectrum[i]
        }
        
        // Update Metal buffer
        updateSpectrumBuffer()
        
        // Trigger redraw if needed
        if isAnimating {
            needsDisplay = true
        }
    }
    
    private func resampleSpectrum(_ data: [Float], targetCount: Int) -> [Float] {
        guard data.count > 0 else { return Array(repeating: 0.0, count: targetCount) }
        
        var resampled: [Float] = []
        let ratio = Float(data.count) / Float(targetCount)
        
        for i in 0..<targetCount {
            let sourceIndex = Int(Float(i) * ratio)
            let clampedIndex = min(sourceIndex, data.count - 1)
            resampled.append(data[clampedIndex])
        }
        
        return resampled
    }
    
    private func updateSpectrumBuffer() {
        guard let buffer = spectrumBuffer else { return }
        
        let bufferPointer = buffer.contents().bindMemory(to: Float.self, capacity: spectrumData.count)
        for i in 0..<spectrumData.count {
            bufferPointer[i] = spectrumData[i]
        }
    }
    
    public func setVisualizationMode(_ mode: VisualizationMode) {
        visualizationMode = mode
        needsDisplay = true
    }
    
    public func setColorScheme(_ scheme: VisualizationColorScheme) {
        colorScheme = scheme
        needsDisplay = true
    }
    
    public func setAnimating(_ animating: Bool) {
        isAnimating = animating
        if animating {
            needsDisplay = true
        }
    }
    
    // MARK: - MTKView Delegate
    public override func draw(_ rect: NSRect) {
        autoreleasepool {
            guard let drawable = currentDrawable,
                  let renderPassDescriptor = currentRenderPassDescriptor,
                  let pipelineState = renderPipelineState else {
                return
            }
            
            // Update uniforms
            updateUniforms()
            
            // Create command buffer
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            commandBuffer.label = "Visualization Render Command"
            
            // Create render encoder
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            renderEncoder.label = "Visualization Render Encoder"
            
            // Set render state
            renderEncoder.setRenderPipelineState(pipelineState)
            
            // Bind buffers
            if let vertexBuffer = vertexBuffer {
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            }
            if let spectrumBuffer = spectrumBuffer {
                renderEncoder.setVertexBuffer(spectrumBuffer, offset: 0, index: 1)
                renderEncoder.setFragmentBuffer(spectrumBuffer, offset: 0, index: 0)
            }
            if let uniformBuffer = uniformBuffer {
                renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 2)
                renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
            }
            
            // Draw based on visualization mode
            drawVisualization(with: renderEncoder)
            
            // Finish encoding
            renderEncoder.endEncoding()
            
            // Present drawable
            commandBuffer.present(drawable)
            commandBuffer.commit()
            
            // Update performance metrics
            updatePerformanceMetrics()
        }
    }
    
    private func drawVisualization(with encoder: MTLRenderCommandEncoder) {
        switch visualizationMode {
        case .spectrumBars:
            drawSpectrumBars(with: encoder)
        case .oscilloscope:
            drawOscilloscope(with: encoder)
        case .dots:
            drawDots(with: encoder)
        case .fire:
            drawFire(with: encoder)
        case .tunnel:
            drawTunnel(with: encoder)
        }
    }
    
    private func drawSpectrumBars(with encoder: MTLRenderCommandEncoder) {
        let barCount = spectrumData.count
        let verticesPerBar = 6  // 2 triangles per bar
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: barCount * verticesPerBar)
    }
    
    private func drawOscilloscope(with encoder: MTLRenderCommandEncoder) {
        // Draw as line strip
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: spectrumData.count)
    }
    
    private func drawDots(with encoder: MTLRenderCommandEncoder) {
        // Draw as points
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: spectrumData.count)
    }
    
    private func drawFire(with encoder: MTLRenderCommandEncoder) {
        // Custom fire effect - similar to spectrum bars but with fire shader
        drawSpectrumBars(with: encoder)
    }
    
    private func drawTunnel(with encoder: MTLRenderCommandEncoder) {
        // 3D tunnel effect
        drawSpectrumBars(with: encoder)
    }
    
    private func updateUniforms() {
        guard let uniformBuffer = uniformBuffer else { return }
        
        let uniforms = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        
        let aspectRatio = Float(bounds.width / bounds.height)
        let projectionMatrix = simd_float4x4.orthographic(
            left: -aspectRatio, right: aspectRatio,
            bottom: -1.0, top: 1.0,
            near: -1.0, far: 1.0
        )
        
        uniforms.pointee = Uniforms(
            projectionMatrix: projectionMatrix,
            time: Float(CACurrentMediaTime()),
            barCount: Int32(spectrumData.count),
            visualizationMode: Int32(visualizationMode.rawValue),
            colorScheme: Int32(colorScheme.rawValue),
            amplitude: 1.0,
            smoothing: spectrumSmoothingFactor,
            reserved: 0
        )
    }
    
    private func updatePerformanceMetrics() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        
        if currentTime - lastFPSUpdate >= 1.0 {
            let fps = Double(frameCount) / (currentTime - lastFPSUpdate)
            
            #if DEBUG
            if fps < 30 {
                print("Visualization FPS warning: \(Int(fps)) fps")
            }
            #endif
            
            frameCount = 0
            lastFPSUpdate = currentTime
        }
    }
}

// MARK: - Matrix Extensions
extension simd_float4x4 {
    static func orthographic(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
        let ral = right + left
        let rsl = right - left
        let tab = top + bottom
        let tsb = top - bottom
        let fan = far + near
        let fsn = far - near
        
        return simd_float4x4(columns: (
            simd_float4(2.0 / rsl, 0.0, 0.0, 0.0),
            simd_float4(0.0, 2.0 / tsb, 0.0, 0.0),
            simd_float4(0.0, 0.0, -2.0 / fsn, 0.0),
            simd_float4(-ral / rsl, -tab / tsb, -fan / fsn, 1.0)
        ))
    }
}

// MARK: - Raw Value Extensions
extension ModernVisualizerView.VisualizationMode: RawRepresentable {
    public var rawValue: Int {
        switch self {
        case .spectrumBars: return 0
        case .oscilloscope: return 1
        case .dots: return 2
        case .fire: return 3
        case .tunnel: return 4
        }
    }
    
    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .spectrumBars
        case 1: self = .oscilloscope
        case 2: self = .dots
        case 3: self = .fire
        case 4: self = .tunnel
        default: return nil
        }
    }
}

extension ModernVisualizerView.VisualizationColorScheme: RawRepresentable {
    public var rawValue: Int {
        switch self {
        case .classic: return 0
        case .rainbow: return 1
        case .fire: return 2
        case .ice: return 3
        case .matrix: return 4
        }
    }
    
    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .classic
        case 1: self = .rainbow
        case 2: self = .fire
        case 3: self = .ice
        case 4: self = .matrix
        default: return nil
        }
    }
}