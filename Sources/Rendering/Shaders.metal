#include <metal_stdlib>
using namespace metal;

// Vertex input structure
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 textureCoord [[attribute(1)]];
    float4 color [[attribute(2)]];
};

// Vertex output structure / Fragment input
struct VertexOut {
    float4 position [[position]];
    float2 textureCoord;
    float4 color;
    float time;
    float opacity;
};

// Uniform buffer structure
struct SpriteUniforms {
    float4x4 projectionMatrix;
    float4x4 modelViewMatrix;
    float time;
    float opacity;
};

// MARK: - Vertex Shader for Sprite Rendering
vertex VertexOut sprite_vertex(VertexIn in [[stage_in]],
                              constant SpriteUniforms& uniforms [[buffer(1)]],
                              uint vertexID [[vertex_id]]) {
    VertexOut out;
    
    // Transform vertex position to clip space
    float4 worldPosition = uniforms.modelViewMatrix * float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * worldPosition;
    
    // Pass through texture coordinates and color
    out.textureCoord = in.textureCoord;
    out.color = in.color;
    out.time = uniforms.time;
    out.opacity = uniforms.opacity;
    
    return out;
}

// MARK: - Fragment Shader for Sprite Rendering with Color Space Conversion
fragment float4 sprite_fragment(VertexOut in [[stage_in]],
                               texture2d<float> spriteTexture [[texture(0)]],
                               sampler spriteSampler [[sampler(0)]]) {
    // Sample the sprite texture
    float4 texColor = spriteTexture.sample(spriteSampler, in.textureCoord);
    
    // Apply vertex color tinting
    texColor *= in.color;
    
    // Apply global opacity
    texColor.a *= in.opacity;
    
    // Windows to macOS color space conversion (sRGB gamma correction)
    // Windows typically uses linear RGB while macOS expects sRGB
    texColor.rgb = pow(texColor.rgb, float3(1.0 / 2.2));
    
    return texColor;
}

// MARK: - Visualization Shaders for Spectrum/Oscilloscope Effects

struct VisualizationVertex {
    float2 position [[attribute(0)]];
    float amplitude [[attribute(1)]];
    float frequency [[attribute(2)]];
    float4 color [[attribute(3)]];
};

struct VisualizationOut {
    float4 position [[position]];
    float amplitude;
    float frequency;
    float4 color;
    float time;
};

vertex VisualizationOut visualization_vertex(VisualizationVertex in [[stage_in]],
                                           constant SpriteUniforms& uniforms [[buffer(1)]],
                                           uint vertexID [[vertex_id]]) {
    VisualizationOut out;
    
    // Animate vertex position based on audio amplitude
    float2 animatedPosition = in.position;
    
    // Apply wave effect for oscilloscope
    if (in.frequency > 0.0) {
        float wave = sin(uniforms.time * 3.14159 * in.frequency + in.position.x * 10.0) * in.amplitude * 0.1;
        animatedPosition.y += wave;
    }
    
    // Transform to clip space
    float4 worldPosition = uniforms.modelViewMatrix * float4(animatedPosition, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * worldPosition;
    
    out.amplitude = in.amplitude;
    out.frequency = in.frequency;
    out.color = in.color;
    out.time = uniforms.time;
    
    return out;
}

fragment float4 visualization_fragment(VisualizationOut in [[stage_in]]) {
    float4 color = in.color;
    
    // Create glow effect based on amplitude
    float glow = smoothstep(0.0, 1.0, in.amplitude);
    color.rgb *= (1.0 + glow * 2.0);
    
    // Add time-based pulsing
    float pulse = sin(in.time * 6.28318) * 0.1 + 0.9;
    color.rgb *= pulse;
    
    // Fade edges for smoother visualization
    float edgeFade = smoothstep(0.0, 0.1, in.amplitude) * smoothstep(1.0, 0.9, in.amplitude);
    color.a *= edgeFade;
    
    return color;
}

// MARK: - Advanced Effects Shaders

// Gaussian blur for drop shadows and glows
kernel void gaussian_blur(texture2d<float, access::read> inputTexture [[texture(0)]],
                         texture2d<float, access::write> outputTexture [[texture(1)]],
                         constant float& blurRadius [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 color = float4(0.0);
    float totalWeight = 0.0;
    
    int radius = int(blurRadius);
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            int2 coord = int2(gid) + int2(dx, dy);
            
            if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                
                float distance = sqrt(float(dx * dx + dy * dy));
                float weight = exp(-distance * distance / (2.0 * blurRadius * blurRadius));
                
                color += inputTexture.read(uint2(coord)) * weight;
                totalWeight += weight;
            }
        }
    }
    
    outputTexture.write(color / totalWeight, gid);
}

// Color adjustment for Windows skin compatibility
fragment float4 color_adjustment_fragment(VertexOut in [[stage_in]],
                                        texture2d<float> sourceTexture [[texture(0)]],
                                        sampler sourceSampler [[sampler(0)]],
                                        constant float& brightness [[buffer(0)]],
                                        constant float& contrast [[buffer(1)]],
                                        constant float& saturation [[buffer(2)]]) {
    
    float4 color = sourceTexture.sample(sourceSampler, in.textureCoord);
    
    // Brightness adjustment
    color.rgb += brightness;
    
    // Contrast adjustment
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;
    
    // Saturation adjustment
    float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
    color.rgb = mix(float3(gray), color.rgb, saturation);
    
    // Clamp values
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    
    return color;
}

// High-performance text rendering for skin labels
struct TextVertex {
    float2 position [[attribute(0)]];
    float2 textureCoord [[attribute(1)]];
    float4 color [[attribute(2)]];
    float sdfThreshold [[attribute(3)]];
};

struct TextOut {
    float4 position [[position]];
    float2 textureCoord;
    float4 color;
    float sdfThreshold;
};

vertex TextOut text_vertex(TextVertex in [[stage_in]],
                          constant SpriteUniforms& uniforms [[buffer(1)]]) {
    TextOut out;
    
    float4 worldPosition = uniforms.modelViewMatrix * float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * worldPosition;
    out.textureCoord = in.textureCoord;
    out.color = in.color;
    out.sdfThreshold = in.sdfThreshold;
    
    return out;
}

fragment float4 text_fragment(TextOut in [[stage_in]],
                             texture2d<float> fontAtlas [[texture(0)]],
                             sampler fontSampler [[sampler(0)]]) {
    
    // Sample signed distance field from font atlas
    float distance = fontAtlas.sample(fontSampler, in.textureCoord).r;
    
    // Create smooth edges using SDF
    float alpha = smoothstep(in.sdfThreshold - 0.1, in.sdfThreshold + 0.1, distance);
    
    float4 color = in.color;
    color.a *= alpha;
    
    return color;
}