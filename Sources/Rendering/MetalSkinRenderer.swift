import Metal
import MetalKit
import CoreAnimation
import QuartzCore

/// Modern Metal-based skin renderer for macOS 15.0+ and Apple Silicon optimization
/// Replaces deprecated NSOpenGLView with MTKView for efficient sprite rendering
class MetalSkinRenderer: NSObject {
    
    // MARK: - Core Metal Resources
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var library: MTLLibrary
    private var renderPipelineState: MTLRenderPipelineState
    private var depthStencilState: MTLDepthStencilState
    
    // MARK: - Texture Management
    private var textureLoader: MTKTextureLoader
    private let textureCache = NSCache<NSString, MTLTexture>()
    private var spriteAtlas: MTLTexture?
    
    // MARK: - Vertex Buffers for Batch Rendering
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private let maxSpritesPerBatch = 1000
    
    // MARK: - Display Optimization
    private var isProMotionDisplay = false
    private var targetFrameRate: Int = 60
    private var lastFrameTime: CFTimeInterval = 0
    
    struct SpriteVertex {
        var position: simd_float2
        var textureCoord: simd_float2
        var color: simd_float4
    }
    
    struct SpriteUniforms {
        var projectionMatrix: simd_float4x4
        var modelViewMatrix: simd_float4x4
        var time: Float
        var opacity: Float
    }
    
    init() throws {
        // Create Metal device - prefer dedicated GPU on Apple Silicon
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalError.deviceCreationFailed
        }
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
        
        // Load Metal library
        guard let library = device.makeDefaultLibrary() else {
            throw MetalError.libraryCreationFailed
        }
        self.library = library
        
        // Initialize texture loader with optimal settings for Retina displays
        self.textureLoader = MTKTextureLoader(device: device)
        
        super.init()
        
        try setupRenderPipeline()
        try setupBuffers()
        configureTextureCache()
        detectDisplayCapabilities()
    }
    
    private func setupRenderPipeline() throws {
        guard let vertexFunction = library.makeFunction(name: "sprite_vertex"),
              let fragmentFunction = library.makeFunction(name: "sprite_fragment") else {
            throw MetalError.shaderLoadFailed
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable alpha blending for sprite transparency
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        // Configure vertex descriptor for batched sprite rendering
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2 // position
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float2 // texCoord
        vertexDescriptor.attributes[1].offset = MemoryLayout<simd_float2>.size
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.attributes[2].format = .float4 // color
        vertexDescriptor.attributes[2].offset = MemoryLayout<simd_float2>.size * 2
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<SpriteVertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            throw MetalError.pipelineCreationFailed(error)
        }
        
        // Create depth stencil state for proper sprite layering
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        
        guard let depthState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw MetalError.depthStencilCreationFailed
        }
        self.depthStencilState = depthState
    }
    
    private func setupBuffers() throws {
        let vertexBufferSize = maxSpritesPerBatch * 4 * MemoryLayout<SpriteVertex>.stride
        guard let vBuffer = device.makeBuffer(length: vertexBufferSize, options: .storageModeShared) else {
            throw MetalError.bufferCreationFailed
        }
        self.vertexBuffer = vBuffer
        
        // Create index buffer for sprite quads (6 indices per sprite: 2 triangles)
        var indices: [UInt16] = []
        for i in 0..<maxSpritesPerBatch {
            let baseIndex = UInt16(i * 4)
            indices.append(contentsOf: [
                baseIndex, baseIndex + 1, baseIndex + 2,
                baseIndex + 1, baseIndex + 3, baseIndex + 2
            ])
        }
        
        let indexBufferSize = indices.count * MemoryLayout<UInt16>.size
        guard let iBuffer = device.makeBuffer(bytes: indices, length: indexBufferSize, options: .storageModeShared) else {
            throw MetalError.bufferCreationFailed
        }
        self.indexBuffer = iBuffer
    }
    
    private func configureTextureCache() {
        textureCache.countLimit = 100 // Limit cached textures for memory efficiency
        textureCache.totalCostLimit = 256 * 1024 * 1024 // 256MB limit
        textureCache.evictsObjectsWithDiscardedContent = true
    }
    
    private func detectDisplayCapabilities() {
        if let screen = NSScreen.main {
            // Detect ProMotion displays (120Hz)
            let refreshRate = screen.maximumFramesPerSecond
            isProMotionDisplay = refreshRate > 60
            targetFrameRate = isProMotionDisplay ? 120 : 60
            
            print("Display capabilities detected - Refresh rate: \(refreshRate)Hz, ProMotion: \(isProMotionDisplay)")
        }
    }
    
    /// Load and cache texture with automatic Retina scaling
    func loadTexture(from url: URL, generateMipmaps: Bool = false) throws -> MTLTexture {
        let cacheKey = url.absoluteString as NSString
        
        if let cachedTexture = textureCache.object(forKey: cacheKey) {
            return cachedTexture
        }
        
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .generateMipmaps: generateMipmaps,
            .SRGB: false // Handle color space conversion manually
        ]
        
        let texture = try textureLoader.newTexture(URL: url, options: options)
        
        // Cache with cost based on texture size
        let textureCost = texture.width * texture.height * 4 // Assume 4 bytes per pixel
        textureCache.setObject(texture, forKey: cacheKey, cost: textureCost)
        
        return texture
    }
    
    /// Create sprite atlas from individual texture files for efficient batching
    func createSpriteAtlas(from textures: [MTLTexture], atlasSize: Int = 2048) throws -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: atlasSize,
            height: atlasSize,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .renderTarget]
        textureDescriptor.storageMode = .private
        
        guard let atlas = device.makeTexture(descriptor: textureDescriptor) else {
            throw MetalError.textureCreationFailed
        }
        
        // Use blit encoder to efficiently copy textures to atlas
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw MetalError.commandBufferCreationFailed
        }
        
        var x = 0, y = 0, maxHeight = 0
        
        for texture in textures {
            if x + texture.width > atlasSize {
                x = 0
                y += maxHeight
                maxHeight = 0
            }
            
            if y + texture.height > atlasSize {
                break // Atlas full
            }
            
            blitEncoder.copy(
                from: texture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                to: atlas,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: x, y: y, z: 0)
            )
            
            x += texture.width
            maxHeight = max(maxHeight, texture.height)
        }
        
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        self.spriteAtlas = atlas
        return atlas
    }
    
    /// Render sprites using batched draw calls for optimal performance
    func render(sprites: [SkinSprite], in renderPassDescriptor: MTLRenderPassDescriptor, viewMatrix: simd_float4x4) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let vertexBuffer = vertexBuffer else {
            throw MetalError.renderingFailed
        }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Batch sprites by texture to minimize state changes
        let batchedSprites = Dictionary(grouping: sprites) { $0.texture }
        
        for (texture, spriteGroup) in batchedSprites {
            renderEncoder.setFragmentTexture(texture, index: 0)
            
            let chunks = spriteGroup.chunked(into: maxSpritesPerBatch)
            
            for chunk in chunks {
                // Fill vertex buffer with sprite data
                let vertices = createVerticesForSprites(chunk)
                let vertexDataSize = vertices.count * MemoryLayout<SpriteVertex>.stride
                
                vertexBuffer.contents().copyMemory(
                    from: vertices,
                    byteCount: vertexDataSize
                )
                
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                
                // Set uniforms
                var uniforms = SpriteUniforms(
                    projectionMatrix: viewMatrix,
                    modelViewMatrix: matrix_identity_float4x4,
                    time: Float(CACurrentMediaTime()),
                    opacity: 1.0
                )
                
                renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<SpriteUniforms>.stride, index: 1)
                
                // Draw indexed primitives
                let indexCount = chunk.count * 6 // 6 indices per sprite quad
                renderEncoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: indexCount,
                    indexType: .uint16,
                    indexBuffer: indexBuffer!,
                    indexBufferOffset: 0
                )
            }
        }
        
        renderEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    private func createVerticesForSprites(_ sprites: [SkinSprite]) -> [SpriteVertex] {
        var vertices: [SpriteVertex] = []
        
        for sprite in sprites {
            let bounds = sprite.bounds
            let texCoords = sprite.textureCoordinates
            let color = sprite.tintColor
            
            // Create quad vertices (2 triangles)
            vertices.append(contentsOf: [
                SpriteVertex(position: simd_float2(bounds.minX, bounds.minY), textureCoord: simd_float2(texCoords.minX, texCoords.maxY), color: color),
                SpriteVertex(position: simd_float2(bounds.maxX, bounds.minY), textureCoord: simd_float2(texCoords.maxX, texCoords.maxY), color: color),
                SpriteVertex(position: simd_float2(bounds.minX, bounds.maxY), textureCoord: simd_float2(texCoords.minX, texCoords.minY), color: color),
                SpriteVertex(position: simd_float2(bounds.maxX, bounds.maxY), textureCoord: simd_float2(texCoords.maxX, texCoords.minY), color: color)
            ])
        }
        
        return vertices
    }
    
    /// Check if frame rate limiting is needed for battery optimization
    func shouldLimitFrameRate() -> Bool {
        guard isProMotionDisplay else { return false }
        
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        let targetInterval = 1.0 / Double(targetFrameRate)
        
        if deltaTime >= targetInterval {
            lastFrameTime = currentTime
            return false
        }
        
        return true
    }
}

// MARK: - Error Handling
enum MetalError: Error {
    case deviceCreationFailed
    case commandQueueCreationFailed
    case libraryCreationFailed
    case shaderLoadFailed
    case pipelineCreationFailed(Error)
    case depthStencilCreationFailed
    case bufferCreationFailed
    case textureCreationFailed
    case commandBufferCreationFailed
    case renderingFailed
    
    var localizedDescription: String {
        switch self {
        case .deviceCreationFailed:
            return "Failed to create Metal device"
        case .commandQueueCreationFailed:
            return "Failed to create command queue"
        case .libraryCreationFailed:
            return "Failed to load Metal library"
        case .shaderLoadFailed:
            return "Failed to load shader functions"
        case .pipelineCreationFailed(let error):
            return "Failed to create render pipeline: \(error.localizedDescription)"
        case .depthStencilCreationFailed:
            return "Failed to create depth stencil state"
        case .bufferCreationFailed:
            return "Failed to create Metal buffer"
        case .textureCreationFailed:
            return "Failed to create Metal texture"
        case .commandBufferCreationFailed:
            return "Failed to create command buffer"
        case .renderingFailed:
            return "Rendering operation failed"
        }
    }
}

// MARK: - Helper Extensions
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}