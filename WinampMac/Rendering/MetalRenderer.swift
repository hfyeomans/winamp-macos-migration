import Metal
import MetalKit
import Foundation
import CoreVideo
import QuartzCore

/// High-performance Metal rendering system for Winamp skin graphics
/// Optimized for Apple Silicon with 120Hz ProMotion support
@MainActor
public final class MetalRenderer: NSObject, ObservableObject {
    
    // MARK: - Core Metal Objects
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // MARK: - Rendering Pipeline
    private var skinRenderPipelineState: MTLRenderPipelineState?
    private var visualizationPipelineState: MTLRenderPipelineState?
    
    // MARK: - Sprite Batching System
    private var spriteBatch: SpriteBatch
    private var textureAtlas: TextureAtlas
    
    // MARK: - ProMotion Support
    private var displayLink: CVDisplayLink?
    private var preferredFramesPerSecond: Int = 120
    
    // MARK: - Performance Tracking
    private var frameTime: CFTimeInterval = 0
    private var lastFrameTime: CFTimeInterval = 0
    
    public init() throws {
        // Initialize Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw WinampError.metalInitializationFailed(reason: "No Metal-capable device found")
        }
        
        guard device.supportsFeatureSet(.macOS_GPUFamily2_v1) else {
            throw WinampError.metalInitializationFailed(reason: "Device does not support required Metal features")
        }
        
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            throw WinampError.metalInitializationFailed(reason: "Failed to create command queue")
        }
        self.commandQueue = commandQueue
        
        // Load shader library
        guard let library = device.makeDefaultLibrary() else {
            throw WinampError.metalInitializationFailed(reason: "Failed to load shader library")
        }
        self.library = library
        
        // Initialize sprite batching system
        self.spriteBatch = try SpriteBatch(device: device)
        self.textureAtlas = try TextureAtlas(device: device)
        
        super.init()
        
        try setupRenderingPipelines()
        setupDisplayLink()
    }
    
    deinit {
        stopDisplayLink()
    }
    
    // MARK: - Pipeline Setup
    private func setupRenderingPipelines() throws {
        try setupSkinRenderingPipeline()
        try setupVisualizationPipeline()
    }
    
    private func setupSkinRenderingPipeline() throws {
        guard let vertexFunction = library.makeFunction(name: "skinVertexShader"),
              let fragmentFunction = library.makeFunction(name: "skinFragmentShader") else {
            throw WinampError.shaderCompilationFailed(
                shader: "skin",
                error: "Failed to load shader functions"
            )
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable alpha blending for skin transparency
        let colorAttachment = pipelineDescriptor.colorAttachments[0]!
        colorAttachment.isBlendingEnabled = true
        colorAttachment.rgbBlendOperation = .add
        colorAttachment.alphaBlendOperation = .add
        colorAttachment.sourceRGBBlendFactor = .sourceAlpha
        colorAttachment.sourceAlphaBlendFactor = .sourceAlpha
        colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            skinRenderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            throw WinampError.shaderCompilationFailed(
                shader: "skin",
                error: error.localizedDescription
            )
        }
    }
    
    private func setupVisualizationPipeline() throws {
        guard let vertexFunction = library.makeFunction(name: "visualizationVertexShader"),
              let fragmentFunction = library.makeFunction(name: "visualizationFragmentShader") else {
            throw WinampError.shaderCompilationFailed(
                shader: "visualization",
                error: "Failed to load visualization shader functions"
            )
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Additive blending for visualizations
        let colorAttachment = pipelineDescriptor.colorAttachments[0]!
        colorAttachment.isBlendingEnabled = true
        colorAttachment.rgbBlendOperation = .add
        colorAttachment.alphaBlendOperation = .add
        colorAttachment.sourceRGBBlendFactor = .one
        colorAttachment.destinationRGBBlendFactor = .one
        
        do {
            visualizationPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            throw WinampError.shaderCompilationFailed(
                shader: "visualization",
                error: error.localizedDescription
            )
        }
    }
    
    // MARK: - ProMotion Display Link
    private func setupDisplayLink() {
        var displayLink: CVDisplayLink?
        let displayLinkOutputCallback: CVDisplayLinkOutputCallback = { (displayLink, now, outputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
            
            let renderer = Unmanaged<MetalRenderer>.fromOpaque(displayLinkContext!).takeUnretainedValue()
            
            DispatchQueue.main.async {
                renderer.updateFrame(outputTime: outputTime.pointee)
            }
            
            return kCVReturnSuccess
        }
        
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, displayLinkOutputCallback, Unmanaged.passUnretained(self).toOpaque())
            CVDisplayLinkStart(displayLink)
            self.displayLink = displayLink
        }
    }
    
    private func stopDisplayLink() {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
            self.displayLink = nil
        }
    }
    
    private func updateFrame(outputTime: CVTimeStamp) {
        let currentTime = CACurrentMediaTime()
        frameTime = currentTime - lastFrameTime
        lastFrameTime = currentTime
        
        // Record performance metrics
        PerformanceMonitor.shared.recordMetric("frameTime", value: frameTime * 1000)
        
        // Trigger render if needed
        objectWillChange.send()
    }
    
    // MARK: - Rendering Interface
    public func render(in mtkView: MTKView, skinElements: [SkinElement], visualizationData: [Float] = []) throws {
        let startTime = CACurrentMediaTime()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = mtkView.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw WinampError.renderingPipelineFailed(reason: "Failed to create render encoder")
        }
        
        renderEncoder.label = "Winamp Skin Renderer"
        
        // Clear background
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        
        // Render skin elements
        try renderSkinElements(encoder: renderEncoder, elements: skinElements, viewSize: mtkView.bounds.size)
        
        // Render visualization if data is available
        if !visualizationData.isEmpty {
            try renderVisualization(encoder: renderEncoder, data: visualizationData, viewSize: mtkView.bounds.size)
        }
        
        renderEncoder.endEncoding()
        
        if let drawable = mtkView.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
        
        // Record render time
        let renderTime = (CACurrentMediaTime() - startTime) * 1000
        PerformanceMonitor.shared.recordMetric("renderTime", value: renderTime)
    }
    
    private func renderSkinElements(encoder: MTLRenderCommandEncoder, elements: [SkinElement], viewSize: CGSize) throws {
        guard let pipelineState = skinRenderPipelineState else {
            throw WinampError.renderingPipelineFailed(reason: "Skin pipeline not initialized")
        }
        
        encoder.setRenderPipelineState(pipelineState)
        
        // Batch skin elements for efficient rendering
        spriteBatch.begin(viewSize: viewSize)
        
        for element in elements {
            if let texture = try? textureAtlas.getTexture(for: element.textureKey) {
                spriteBatch.draw(
                    texture: texture,
                    position: element.position,
                    size: element.size,
                    sourceRect: element.sourceRect,
                    color: element.tintColor
                )
            }
        }
        
        try spriteBatch.end(encoder: encoder)
    }
    
    private func renderVisualization(encoder: MTLRenderCommandEncoder, data: [Float], viewSize: CGSize) throws {
        guard let pipelineState = visualizationPipelineState else {
            throw WinampError.renderingPipelineFailed(reason: "Visualization pipeline not initialized")
        }
        
        encoder.setRenderPipelineState(pipelineState)
        
        // Create vertex buffer for visualization data
        let vertexCount = data.count * 2 // Two vertices per bar
        let vertexBuffer = device.makeBuffer(
            length: vertexCount * MemoryLayout<simd_float2>.stride,
            options: .storageModeShared
        )
        
        guard let buffer = vertexBuffer else {
            throw WinampError.renderingPipelineFailed(reason: "Failed to create vertex buffer")
        }
        
        // Generate vertices for spectrum bars
        let vertices = buffer.contents().bindMemory(to: simd_float2.self, capacity: vertexCount)
        let barWidth = Float(viewSize.width) / Float(data.count)
        
        for (index, amplitude) in data.enumerated() {
            let x = Float(index) * barWidth
            let height = amplitude * Float(viewSize.height) * 0.5
            
            vertices[index * 2] = simd_float2(x, Float(viewSize.height) - height)
            vertices[index * 2 + 1] = simd_float2(x, Float(viewSize.height))
        }
        
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
    }
}

// MARK: - Supporting Types
public struct SkinElement: Sendable {
    public let textureKey: String
    public let position: CGPoint
    public let size: CGSize
    public let sourceRect: CGRect
    public let tintColor: simd_float4
    
    public init(textureKey: String, position: CGPoint, size: CGSize, sourceRect: CGRect = .zero, tintColor: simd_float4 = simd_float4(1, 1, 1, 1)) {
        self.textureKey = textureKey
        self.position = position
        self.size = size
        self.sourceRect = sourceRect
        self.tintColor = tintColor
    }
}

// MARK: - Sprite Batching
@MainActor
private final class SpriteBatch {
    private let device: MTLDevice
    private var vertices: [SpriteVertex] = []
    private var indices: [UInt16] = []
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    
    private struct SpriteVertex {
        let position: simd_float2
        let texCoord: simd_float2
        let color: simd_float4
    }
    
    init(device: MTLDevice) throws {
        self.device = device
        reserveCapacity(1000) // Pre-allocate for typical usage
    }
    
    func begin(viewSize: CGSize) {
        vertices.removeAll(keepingCapacity: true)
        indices.removeAll(keepingCapacity: true)
    }
    
    func draw(texture: MTLTexture, position: CGPoint, size: CGSize, sourceRect: CGRect, color: simd_float4) {
        let vertexIndex = UInt16(vertices.count)
        
        // Convert to normalized device coordinates
        let x1 = Float(position.x / size.width) * 2 - 1
        let y1 = Float(position.y / size.height) * 2 - 1
        let x2 = Float((position.x + size.width) / size.width) * 2 - 1
        let y2 = Float((position.y + size.height) / size.height) * 2 - 1
        
        // Texture coordinates
        let u1 = Float(sourceRect.minX / CGFloat(texture.width))
        let v1 = Float(sourceRect.minY / CGFloat(texture.height))
        let u2 = Float(sourceRect.maxX / CGFloat(texture.width))
        let v2 = Float(sourceRect.maxY / CGFloat(texture.height))
        
        // Add vertices
        vertices.append(SpriteVertex(position: simd_float2(x1, y1), texCoord: simd_float2(u1, v1), color: color))
        vertices.append(SpriteVertex(position: simd_float2(x2, y1), texCoord: simd_float2(u2, v1), color: color))
        vertices.append(SpriteVertex(position: simd_float2(x1, y2), texCoord: simd_float2(u1, v2), color: color))
        vertices.append(SpriteVertex(position: simd_float2(x2, y2), texCoord: simd_float2(u2, v2), color: color))
        
        // Add indices for two triangles
        indices.append(contentsOf: [
            vertexIndex, vertexIndex + 1, vertexIndex + 2,
            vertexIndex + 1, vertexIndex + 3, vertexIndex + 2
        ])
    }
    
    func end(encoder: MTLRenderCommandEncoder) throws {
        guard !vertices.isEmpty else { return }
        
        // Create or update vertex buffer
        let vertexBufferSize = vertices.count * MemoryLayout<SpriteVertex>.stride
        if let buffer = vertexBuffer, buffer.length >= vertexBufferSize {
            buffer.contents().copyMemory(from: vertices, byteCount: vertexBufferSize)
        } else {
            vertexBuffer = device.makeBuffer(bytes: vertices, length: vertexBufferSize, options: .storageModeShared)
        }
        
        // Create or update index buffer
        let indexBufferSize = indices.count * MemoryLayout<UInt16>.stride
        if let buffer = indexBuffer, buffer.length >= indexBufferSize {
            buffer.contents().copyMemory(from: indices, byteCount: indexBufferSize)
        } else {
            indexBuffer = device.makeBuffer(bytes: indices, length: indexBufferSize, options: .storageModeShared)
        }
        
        guard let vertexBuffer = vertexBuffer,
              let indexBuffer = indexBuffer else {
            throw WinampError.renderingPipelineFailed(reason: "Failed to create buffers")
        }
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indices.count,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
    }
    
    private func reserveCapacity(_ capacity: Int) {
        vertices.reserveCapacity(capacity * 4) // 4 vertices per sprite
        indices.reserveCapacity(capacity * 6)  // 6 indices per sprite
    }
}

// MARK: - Texture Atlas
@MainActor
private final class TextureAtlas {
    private let device: MTLDevice
    private var textures: [String: MTLTexture] = [:]
    private let textureLoader: MTKTextureLoader
    
    init(device: MTLDevice) throws {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)
    }
    
    func loadTexture(key: String, data: Data) throws -> MTLTexture {
        let texture = try textureLoader.newTexture(data: data, options: [
            .SRGB: false,
            .generateMipmaps: false
        ])
        
        textures[key] = texture
        return texture
    }
    
    func getTexture(for key: String) throws -> MTLTexture {
        guard let texture = textures[key] else {
            throw WinampError.textureCreationFailed(reason: "Texture not found: \(key)")
        }
        return texture
    }
    
    func removeTexture(key: String) {
        textures.removeValue(forKey: key)
    }
    
    func clearAll() {
        textures.removeAll()
    }
}