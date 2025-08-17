//
//  SkinShaders.metal
//  WinampMac
//
//  Metal shaders for Winamp skin rendering with optimized performance
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Data Structures

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Uniforms

struct SkinUniforms {
    float4x4 projectionMatrix;
    float4x4 modelViewMatrix;
    float2 atlasSize;
    float opacity;
    float time;
};

struct ButtonUniforms {
    float2 position;
    float2 size;
    float2 uvMin;
    float2 uvMax;
    bool isPressed;
    bool isHovered;
};

// MARK: - Vertex Shaders

/// Main skin vertex shader
vertex VertexOut skinVertexShader(VertexIn in [[stage_in]],
                                  constant SkinUniforms& uniforms [[buffer(0)]]) {
    VertexOut out;
    
    float4 worldPosition = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * worldPosition;
    out.texCoord = in.texCoord;
    
    return out;
}

/// Button-specific vertex shader with hover/press effects
vertex VertexOut buttonVertexShader(VertexIn in [[stage_in]],
                                    constant SkinUniforms& uniforms [[buffer(0)]],
                                    constant ButtonUniforms& buttonUniforms [[buffer(1)]]) {
    VertexOut out;
    
    float2 position = in.position;
    
    // Apply button press effect
    if (buttonUniforms.isPressed) {
        position += float2(1.0, -1.0); // Slight offset for press effect
    }
    
    // Apply hover scaling
    if (buttonUniforms.isHovered && !buttonUniforms.isPressed) {
        position *= 1.02; // Slight scale up on hover
    }
    
    float4 worldPosition = float4(position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * worldPosition;
    
    // Map texture coordinates to button's UV region in atlas
    float2 uv = in.texCoord;
    out.texCoord = buttonUniforms.uvMin + uv * (buttonUniforms.uvMax - buttonUniforms.uvMin);
    
    return out;
}

// MARK: - Fragment Shaders

/// Main skin fragment shader with color space correction
fragment float4 skinFragmentShader(VertexOut in [[stage_in]],
                                   texture2d<float> skinTexture [[texture(0)]],
                                   constant SkinUniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear,
                                     mip_filter::linear,
                                     address::clamp_to_edge);
    
    float4 color = skinTexture.sample(textureSampler, in.texCoord);
    
    // Apply opacity
    color.a *= uniforms.opacity;
    
    // Handle transparency - Winamp uses magenta (255, 0, 255) as transparent
    float3 magenta = float3(1.0, 0.0, 1.0);
    float magentaDistance = distance(color.rgb, magenta);
    if (magentaDistance < 0.01) {
        color.a = 0.0;
    }
    
    // Color space correction for better macOS display
    color.rgb = pow(color.rgb, 1.0/2.2); // Gamma correction
    
    return color;
}

/// Button fragment shader with state-based effects
fragment float4 buttonFragmentShader(VertexOut in [[stage_in]],
                                     texture2d<float> buttonTexture [[texture(0)]],
                                     constant SkinUniforms& uniforms [[buffer(0)]],
                                     constant ButtonUniforms& buttonUniforms [[buffer(1)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear,
                                     address::clamp_to_edge);
    
    float4 color = buttonTexture.sample(textureSampler, in.texCoord);
    
    // Handle transparency
    float3 magenta = float3(1.0, 0.0, 1.0);
    float magentaDistance = distance(color.rgb, magenta);
    if (magentaDistance < 0.01) {
        color.a = 0.0;
    }
    
    // Apply button state effects
    if (buttonUniforms.isPressed) {
        color.rgb *= 0.8; // Darken when pressed
    } else if (buttonUniforms.isHovered) {
        color.rgb *= 1.1; // Brighten on hover
        color.rgb = min(color.rgb, 1.0); // Clamp to prevent overflow
    }
    
    color.a *= uniforms.opacity;
    color.rgb = pow(color.rgb, 1.0/2.2); // Gamma correction
    
    return color;
}

/// Visualizer fragment shader for spectrum display
fragment float4 visualizerFragmentShader(VertexOut in [[stage_in]],
                                         texture2d<float> spectrumTexture [[texture(0)]],
                                         constant SkinUniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear,
                                     address::clamp_to_edge);
    
    float4 color = spectrumTexture.sample(textureSampler, in.texCoord);
    
    // Add pulsing effect based on time
    float pulse = 0.5 + 0.5 * sin(uniforms.time * 3.14159);
    color.rgb *= (0.8 + 0.2 * pulse);
    
    color.a *= uniforms.opacity;
    color.rgb = pow(color.rgb, 1.0/2.2);
    
    return color;
}

/// Text rendering fragment shader with proper font rendering
fragment float4 textFragmentShader(VertexOut in [[stage_in]],
                                   texture2d<float> fontTexture [[texture(0)]],
                                   constant SkinUniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear,
                                     address::clamp_to_edge);
    
    float4 color = fontTexture.sample(textureSampler, in.texCoord);
    
    // Text rendering - use alpha channel for text mask
    if (color.a < 0.1) {
        discard_fragment();
    }
    
    // Apply text color (typically white or green for classic Winamp)
    color.rgb = float3(0.0, 1.0, 0.0); // Classic Winamp green
    color.a *= uniforms.opacity;
    
    return color;
}

// MARK: - Compute Shaders for Post-Processing

/// Compute shader for real-time color space conversion
kernel void colorSpaceConversionKernel(texture2d<float, access::read> sourceTexture [[texture(0)]],
                                       texture2d<float, access::write> destinationTexture [[texture(1)]],
                                       uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= sourceTexture.get_width() || gid.y >= sourceTexture.get_height()) {
        return;
    }
    
    float4 sourceColor = sourceTexture.read(gid);
    
    // Convert from Windows RGB to macOS sRGB
    // This is a simplified conversion - in practice you'd use ICC profiles
    float3x3 conversionMatrix = float3x3(
        float3(1.04, -0.02, -0.02),
        float3(-0.01, 1.03, -0.02),
        float3(-0.01, -0.01, 1.02)
    );
    
    float3 convertedColor = conversionMatrix * sourceColor.rgb;
    convertedColor = clamp(convertedColor, 0.0, 1.0);
    
    float4 destinationColor = float4(convertedColor, sourceColor.a);
    destinationTexture.write(destinationColor, gid);
}

/// Compute shader for generating texture atlases
kernel void atlasPackingKernel(texture2d_array<float, access::read> sourceTextures [[texture(0)]],
                               texture2d<float, access::write> atlasTexture [[texture(1)]],
                               constant uint2* offsets [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]],
                               uint textureIndex [[thread_position_in_threadgroup_z]]) {
    
    if (gid.x >= sourceTextures.get_width() || gid.y >= sourceTextures.get_height()) {
        return;
    }
    
    float4 sourceColor = sourceTextures.read(gid, textureIndex);
    uint2 atlasPosition = gid + offsets[textureIndex];
    
    if (atlasPosition.x < atlasTexture.get_width() && atlasPosition.y < atlasTexture.get_height()) {
        atlasTexture.write(sourceColor, atlasPosition);
    }
}

// MARK: - Utility Functions

/// Sample texture with proper filtering for pixel art
float4 samplePixelPerfect(texture2d<float> tex, float2 uv, float2 textureSize) {
    constexpr sampler pixelSampler(mag_filter::nearest,
                                   min_filter::nearest,
                                   address::clamp_to_edge);
    
    // Snap to pixel centers for crisp pixel art rendering
    float2 pixelUV = floor(uv * textureSize + 0.5) / textureSize;
    return tex.sample(pixelSampler, pixelUV);
}

/// Apply Winamp-style transparency (magenta = transparent)
float4 applyWinampTransparency(float4 color) {
    float3 magenta = float3(1.0, 0.0, 1.0);
    float magentaDistance = distance(color.rgb, magenta);
    
    if (magentaDistance < 0.01) {
        color.a = 0.0;
    }
    
    return color;
}

/// Convert coordinates from Windows to macOS coordinate system
float2 convertCoordinates(float2 windowsCoord, float windowHeight) {
    return float2(windowsCoord.x, windowHeight - windowsCoord.y);
}