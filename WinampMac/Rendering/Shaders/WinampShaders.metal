#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Input Structures
struct SkinVertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float4 color [[attribute(2)]];
};

struct VisualizationVertexIn {
    float2 position [[attribute(0)]];
};

// MARK: - Vertex Output Structures
struct SkinVertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

struct VisualizationVertexOut {
    float4 position [[position]];
    float4 color;
};

// MARK: - Uniforms
struct Uniforms {
    float4x4 projectionMatrix;
    float time;
    float2 resolution;
};

// MARK: - Skin Rendering Shaders
vertex SkinVertexOut skinVertexShader(SkinVertexIn in [[stage_in]],
                                     constant Uniforms &uniforms [[buffer(1)]]) {
    SkinVertexOut out;
    
    // Transform position to clip space
    out.position = uniforms.projectionMatrix * float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    out.color = in.color;
    
    return out;
}

fragment float4 skinFragmentShader(SkinVertexOut in [[stage_in]],
                                  texture2d<float> skinTexture [[texture(0)]],
                                  sampler textureSampler [[sampler(0)]]) {
    // Sample the skin texture
    float4 texColor = skinTexture.sample(textureSampler, in.texCoord);
    
    // Apply vertex color tinting
    float4 finalColor = texColor * in.color;
    
    // Preserve alpha for transparency
    return finalColor;
}

// MARK: - Advanced Skin Shaders with Effects
fragment float4 skinFragmentShaderWithEffects(SkinVertexOut in [[stage_in]],
                                             texture2d<float> skinTexture [[texture(0)]],
                                             sampler textureSampler [[sampler(0)]],
                                             constant Uniforms &uniforms [[buffer(0)]]) {
    float4 texColor = skinTexture.sample(textureSampler, in.texCoord);
    
    // Apply hover effect (subtle brightness increase)
    float hoverEffect = 1.0 + 0.1 * smoothstep(0.8, 1.0, in.color.a);
    texColor.rgb *= hoverEffect;
    
    // Apply pressed effect (darken)
    float pressedEffect = 1.0 - 0.2 * step(0.5, in.color.a);
    texColor.rgb *= pressedEffect;
    
    return texColor * in.color;
}

// MARK: - Visualization Shaders
vertex VisualizationVertexOut visualizationVertexShader(VisualizationVertexIn in [[stage_in]],
                                                       constant Uniforms &uniforms [[buffer(1)]],
                                                       uint vertexID [[vertex_id]]) {
    VisualizationVertexOut out;
    
    // Transform position to clip space
    out.position = uniforms.projectionMatrix * float4(in.position, 0.0, 1.0);
    
    // Generate color based on frequency (lower frequencies = red, higher = blue)
    float frequency = float(vertexID) / uniforms.resolution.x;
    out.color = float4(
        1.0 - frequency,        // Red decreases with frequency
        frequency * (1.0 - frequency) * 4.0,  // Green peaks in middle
        frequency,              // Blue increases with frequency
        0.8                     // Slight transparency
    );
    
    return out;
}

fragment float4 visualizationFragmentShader(VisualizationVertexOut in [[stage_in]],
                                           constant Uniforms &uniforms [[buffer(0)]]) {
    // Add time-based color cycling for dynamic effect
    float timeEffect = sin(uniforms.time * 2.0) * 0.2 + 0.8;
    float4 color = in.color * timeEffect;
    
    return color;
}

// MARK: - Spectrum Analyzer Shader
vertex VisualizationVertexOut spectrumVertexShader(uint vertexID [[vertex_id]],
                                                  constant float *amplitudes [[buffer(0)]],
                                                  constant Uniforms &uniforms [[buffer(1)]]) {
    VisualizationVertexOut out;
    
    uint barIndex = vertexID / 2;  // Two vertices per bar
    bool isTop = (vertexID % 2) == 0;
    
    float barWidth = uniforms.resolution.x / 64.0;  // 64 frequency bands
    float x = float(barIndex) * barWidth;
    float amplitude = amplitudes[barIndex];
    
    float y = isTop ? 
        uniforms.resolution.y * (1.0 - amplitude) :  // Top of bar
        uniforms.resolution.y;                       // Bottom of bar
    
    // Convert to normalized device coordinates
    float2 position = float2(x / uniforms.resolution.x * 2.0 - 1.0,
                            y / uniforms.resolution.y * 2.0 - 1.0);
    
    out.position = float4(position, 0.0, 1.0);
    
    // Color based on amplitude and frequency
    float frequency = float(barIndex) / 64.0;
    float intensity = amplitude;
    
    out.color = float4(
        intensity * (1.0 - frequency * 0.5),  // Red decreases with frequency
        intensity * frequency,                 // Green increases with frequency  
        intensity * frequency * frequency,     // Blue increases quadratically
        0.9
    );
    
    return out;
}

// MARK: - Oscilloscope Shader
vertex VisualizationVertexOut oscilloscopeVertexShader(uint vertexID [[vertex_id]],
                                                      constant float *waveform [[buffer(0)]],
                                                      constant Uniforms &uniforms [[buffer(1)]]) {
    VisualizationVertexOut out;
    
    float x = float(vertexID) / 512.0;  // 512 samples
    float sample = waveform[vertexID];
    
    // Center the waveform vertically
    float y = 0.5 + sample * 0.4;  // Scale to 40% of height
    
    // Convert to normalized device coordinates
    float2 position = float2(x * 2.0 - 1.0, y * 2.0 - 1.0);
    out.position = float4(position, 0.0, 1.0);
    
    // Green color for classic oscilloscope look
    float intensity = abs(sample) * 2.0 + 0.3;
    out.color = float4(0.0, intensity, 0.2, 0.8);
    
    return out;
}

// MARK: - Window Shape Shader (for custom window shapes)
vertex float4 windowShapeVertexShader(uint vertexID [[vertex_id]],
                                     constant float2 *positions [[buffer(0)]],
                                     constant Uniforms &uniforms [[buffer(1)]]) {
    float2 position = positions[vertexID];
    return uniforms.projectionMatrix * float4(position, 0.0, 1.0);
}

fragment float4 windowShapeFragmentShader(float4 position [[position]],
                                         texture2d<float> alphaTexture [[texture(0)]],
                                         sampler textureSampler [[sampler(0)]],
                                         constant Uniforms &uniforms [[buffer(0)]]) {
    // Sample alpha from texture to determine window shape
    float2 uv = position.xy / uniforms.resolution;
    float alpha = alphaTexture.sample(textureSampler, uv).a;
    
    // Threshold for crisp edges
    alpha = step(0.5, alpha);
    
    return float4(0.0, 0.0, 0.0, alpha);
}

// MARK: - Text Rendering Shader
struct TextVertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

vertex TextVertexOut textVertexShader(SkinVertexIn in [[stage_in]],
                                     constant Uniforms &uniforms [[buffer(1)]]) {
    TextVertexOut out;
    out.position = uniforms.projectionMatrix * float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    out.color = in.color;
    return out;
}

fragment float4 textFragmentShader(TextVertexOut in [[stage_in]],
                                  texture2d<float> fontTexture [[texture(0)]],
                                  sampler textureSampler [[sampler(0)]]) {
    // Sample signed distance field for sharp text at any scale
    float distance = fontTexture.sample(textureSampler, in.texCoord).a;
    
    // Convert distance to alpha with smooth edges
    float alpha = smoothstep(0.4, 0.6, distance);
    
    return float4(in.color.rgb, in.color.a * alpha);
}

// MARK: - Button State Shader
fragment float4 buttonFragmentShader(SkinVertexOut in [[stage_in]],
                                    texture2d<float> buttonTexture [[texture(0)]],
                                    sampler textureSampler [[sampler(0)]],
                                    constant float &buttonState [[buffer(0)]]) {
    float4 texColor = buttonTexture.sample(textureSampler, in.texCoord);
    
    // buttonState: 0.0 = normal, 1.0 = hover, 2.0 = pressed
    float brightness = 1.0;
    
    if (buttonState > 1.5) {
        // Pressed state - darken
        brightness = 0.8;
    } else if (buttonState > 0.5) {
        // Hover state - brighten
        brightness = 1.2;
    }
    
    texColor.rgb *= brightness;
    return texColor * in.color;
}

// MARK: - Equalizer Visualizer Shader
vertex VisualizationVertexOut equalizerVertexShader(uint vertexID [[vertex_id]],
                                                   constant float *eqValues [[buffer(0)]],
                                                   constant Uniforms &uniforms [[buffer(1)]]) {
    VisualizationVertexOut out;
    
    uint bandIndex = vertexID / 4;  // 4 vertices per EQ band (quad)
    uint vertexInQuad = vertexID % 4;
    
    float bandWidth = uniforms.resolution.x / 10.0;  // 10 EQ bands
    float x = float(bandIndex) * bandWidth;
    float eqValue = eqValues[bandIndex];  // -12.0 to +12.0 dB
    
    // Convert dB to visual height
    float normalizedEQ = (eqValue + 12.0) / 24.0;  // 0.0 to 1.0
    float barHeight = normalizedEQ * uniforms.resolution.y * 0.8;
    
    float2 position;
    switch (vertexInQuad) {
        case 0: position = float2(x, uniforms.resolution.y * 0.5 - barHeight * 0.5); break;
        case 1: position = float2(x + bandWidth * 0.8, uniforms.resolution.y * 0.5 - barHeight * 0.5); break;
        case 2: position = float2(x, uniforms.resolution.y * 0.5 + barHeight * 0.5); break;
        case 3: position = float2(x + bandWidth * 0.8, uniforms.resolution.y * 0.5 + barHeight * 0.5); break;
    }
    
    // Convert to NDC
    position = position / uniforms.resolution * 2.0 - 1.0;
    out.position = float4(position, 0.0, 1.0);
    
    // Color based on EQ value
    if (eqValue > 0.0) {
        // Boost - yellow to red
        float intensity = eqValue / 12.0;
        out.color = float4(1.0, 1.0 - intensity * 0.5, 0.0, 0.9);
    } else {
        // Cut - blue to cyan
        float intensity = abs(eqValue) / 12.0;
        out.color = float4(0.0, intensity * 0.5, 1.0, 0.9);
    }
    
    return out;
}