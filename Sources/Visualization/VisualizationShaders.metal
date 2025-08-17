#include <metal_stdlib>
using namespace metal;

// Shared structures for visualization rendering
struct VisualizationUniforms {
    float4x4 projectionMatrix;
    float time;
    float deltaTime;
    int barCount;
    float amplitude;
    float3 colorLow;
    float3 colorMid;
    float3 colorHigh;
    float glowIntensity;
};

struct SpectrumBar {
    float2 position;
    float height;
    float4 color;
    float velocity;
    float peak;
    float peakDecay;
};

struct OscilloscopePoint {
    float2 position;
    float amplitude;
    float4 color;
    float timestamp;
};

// MARK: - Spectrum Analyzer Shaders

struct SpectrumVertexOut {
    float4 position [[position]];
    float4 color;
    float2 barPosition;
    float height;
    float glow;
};

vertex SpectrumVertexOut spectrum_vertex(uint vertexID [[vertex_id]],
                                        uint instanceID [[instance_id]],
                                        constant SpectrumBar* bars [[buffer(0)]],
                                        constant VisualizationUniforms& uniforms [[buffer(1)]]) {
    
    SpectrumVertexOut out;
    
    // Get the spectrum bar for this instance
    SpectrumBar bar = bars[instanceID];
    
    // Define quad vertices for each bar
    float2 vertices[4] = {
        float2(-0.8, 0.0),  // Bottom left
        float2(0.8, 0.0),   // Bottom right
        float2(-0.8, 1.0),  // Top left
        float2(0.8, 1.0)    // Top right
    };
    
    float2 localVertex = vertices[vertexID];
    
    // Scale and position the bar
    float barWidth = 2.0 / float(uniforms.barCount) * 0.8; // 80% width with gaps
    float2 scaledVertex = localVertex * float2(barWidth * 0.5, bar.height);
    float2 worldPosition = bar.position + scaledVertex;
    
    // Transform to clip space
    out.position = uniforms.projectionMatrix * float4(worldPosition, 0.0, 1.0);
    
    // Calculate color based on height and frequency
    float normalizedFreq = float(instanceID) / float(uniforms.barCount);
    out.color = calculateSpectrumColor(normalizedFreq, bar.height, uniforms.colorLow, uniforms.colorMid, uniforms.colorHigh);
    
    // Add glow effect
    out.glow = bar.height * uniforms.glowIntensity;
    out.barPosition = localVertex;
    out.height = bar.height;
    
    return out;
}

fragment float4 spectrum_fragment(SpectrumVertexOut in [[stage_in]],
                                 constant VisualizationUniforms& uniforms [[buffer(0)]]) {
    
    float4 color = in.color;
    
    // Create gradient effect within each bar
    float gradient = smoothstep(0.0, 1.0, in.barPosition.y);
    color.rgb *= (0.5 + 0.5 * gradient);
    
    // Add glow effect at the edges
    float distFromCenter = abs(in.barPosition.x);
    float edgeGlow = 1.0 - smoothstep(0.7, 1.0, distFromCenter);
    color.rgb += edgeGlow * in.glow * uniforms.glowIntensity;
    
    // Add subtle animation
    float pulse = sin(uniforms.time * 3.14159 + in.barPosition.y * 10.0) * 0.1 + 0.9;
    color.rgb *= pulse;
    
    // Peak indicators
    if (in.barPosition.y > 0.95) {
        color.rgb += float3(1.0, 1.0, 1.0) * 0.3; // White peak highlight
    }
    
    return color;
}

// Helper function for spectrum color calculation
float4 calculateSpectrumColor(float frequency, float amplitude, float3 colorLow, float3 colorMid, float3 colorHigh) {
    float3 baseColor;
    
    if (frequency < 0.5) {
        // Interpolate between low and mid colors
        float t = frequency * 2.0;
        baseColor = mix(colorLow, colorMid, t);
    } else {
        // Interpolate between mid and high colors
        float t = (frequency - 0.5) * 2.0;
        baseColor = mix(colorMid, colorHigh, t);
    }
    
    // Modulate intensity based on amplitude
    baseColor *= amplitude;
    
    return float4(baseColor, 1.0);
}

// MARK: - Oscilloscope Shaders

struct OscilloscopeVertexOut {
    float4 position [[position]];
    float4 color;
    float amplitude;
    float age;
    float2 screenPos;
};

vertex OscilloscopeVertexOut oscilloscope_vertex(uint vertexID [[vertex_id]],
                                               constant OscilloscopePoint* points [[buffer(0)]],
                                               constant VisualizationUniforms& uniforms [[buffer(1)]]) {
    
    OscilloscopeVertexOut out;
    
    OscilloscopePoint point = points[vertexID];
    
    // Transform position to clip space
    out.position = uniforms.projectionMatrix * float4(point.position, 0.0, 1.0);
    
    // Calculate age-based fading
    float age = uniforms.time - point.timestamp;
    float fadeAlpha = max(0.0, 1.0 - age * 2.0);
    
    out.color = point.color;
    out.color.a *= fadeAlpha;
    out.amplitude = point.amplitude;
    out.age = age;
    out.screenPos = point.position;
    
    return out;
}

fragment float4 oscilloscope_fragment(OscilloscopeVertexOut in [[stage_in]],
                                     constant VisualizationUniforms& uniforms [[buffer(0)]]) {
    
    float4 color = in.color;
    
    // Create glow effect based on amplitude
    float glowIntensity = abs(in.amplitude) * uniforms.glowIntensity;
    color.rgb += glowIntensity * float3(0.5, 1.0, 0.5);
    
    // Add subtle wave distortion
    float wave = sin(uniforms.time * 6.28318 + in.screenPos.x * 20.0) * 0.05;
    color.rgb *= (1.0 + wave);
    
    // Anti-aliasing for smooth lines
    float lineWidth = 2.0;
    float alpha = smoothstep(lineWidth + 1.0, lineWidth, length(in.screenPos.xy));
    color.a *= alpha;
    
    return color;
}

// MARK: - Particle Effect Shaders (for enhanced visualizations)

struct ParticleData {
    float2 position;
    float2 velocity;
    float4 color;
    float life;
    float size;
};

struct ParticleVertexOut {
    float4 position [[position]];
    float4 color;
    float2 texCoord;
    float size;
    float life;
};

vertex ParticleVertexOut particle_vertex(uint vertexID [[vertex_id]],
                                        uint instanceID [[instance_id]],
                                        constant ParticleData* particles [[buffer(0)]],
                                        constant VisualizationUniforms& uniforms [[buffer(1)]]) {
    
    ParticleVertexOut out;
    
    ParticleData particle = particles[instanceID];
    
    // Create billboard quad for each particle
    float2 offsets[4] = {
        float2(-1.0, -1.0),
        float2(1.0, -1.0),
        float2(-1.0, 1.0),
        float2(1.0, 1.0)
    };
    
    float2 texCoords[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };
    
    float2 offset = offsets[vertexID] * particle.size;
    float2 worldPos = particle.position + offset;
    
    out.position = uniforms.projectionMatrix * float4(worldPos, 0.0, 1.0);
    out.color = particle.color;
    out.texCoord = texCoords[vertexID];
    out.size = particle.size;
    out.life = particle.life;
    
    return out;
}

fragment float4 particle_fragment(ParticleVertexOut in [[stage_in]],
                                 constant VisualizationUniforms& uniforms [[buffer(0)]]) {
    
    // Create circular particle shape
    float2 center = float2(0.5, 0.5);
    float distance = length(in.texCoord - center);
    
    // Soft circular falloff
    float alpha = 1.0 - smoothstep(0.3, 0.5, distance);
    
    float4 color = in.color;
    color.a *= alpha * in.life;
    
    // Add glow effect
    float glow = 1.0 - smoothstep(0.0, 0.8, distance);
    color.rgb += glow * uniforms.glowIntensity * 0.5;
    
    return color;
}

// MARK: - Advanced Spectrum Effects

// 3D Spectrum bars with depth and perspective
vertex SpectrumVertexOut spectrum_3d_vertex(uint vertexID [[vertex_id]],
                                           uint instanceID [[instance_id]],
                                           constant SpectrumBar* bars [[buffer(0)]],
                                           constant VisualizationUniforms& uniforms [[buffer(1)]]) {
    
    SpectrumVertexOut out;
    
    SpectrumBar bar = bars[instanceID];
    
    // Create 3D cube vertices for each bar
    float3 vertices[8] = {
        float3(-0.4, 0.0, -0.2),   // Bottom face
        float3(0.4, 0.0, -0.2),
        float3(0.4, 0.0, 0.2),
        float3(-0.4, 0.0, 0.2),
        float3(-0.4, 1.0, -0.2),   // Top face
        float3(0.4, 1.0, -0.2),
        float3(0.4, 1.0, 0.2),
        float3(-0.4, 1.0, 0.2)
    };
    
    // Define cube face indices (this is simplified - would need proper indexing)
    uint cubeIndices[36] = {
        0,1,2, 0,2,3,  // Bottom
        4,7,6, 4,6,5,  // Top
        0,4,5, 0,5,1,  // Front
        2,6,7, 2,7,3,  // Back
        0,3,7, 0,7,4,  // Left
        1,5,6, 1,6,2   // Right
    };
    
    uint index = cubeIndices[vertexID];
    float3 vertex = vertices[index];
    
    // Scale by bar height
    vertex.y *= bar.height;
    
    // Position in world space
    float barSpacing = 2.0 / float(uniforms.barCount);
    float3 worldPos = float3(bar.position.x, vertex.y, vertex.z);
    
    // Apply perspective transformation
    float4x4 viewMatrix = float4x4(
        float4(1, 0, 0, 0),
        float4(0, 1, 0, 0),
        float4(0, 0, 1, -3),
        float4(0, 0, 0, 1)
    );
    
    float4 viewPos = viewMatrix * float4(worldPos, 1.0);
    out.position = uniforms.projectionMatrix * viewPos;
    
    // Calculate lighting-like effect for 3D appearance
    float3 normal = normalize(cross(
        vertices[(index + 1) % 8] - vertex,
        vertices[(index + 2) % 8] - vertex
    ));
    
    float3 lightDir = normalize(float3(0.5, 1.0, 0.5));
    float lighting = max(0.3, dot(normal, lightDir));
    
    float normalizedFreq = float(instanceID) / float(uniforms.barCount);
    out.color = calculateSpectrumColor(normalizedFreq, bar.height * lighting, uniforms.colorLow, uniforms.colorMid, uniforms.colorHigh);
    
    out.barPosition = vertex.xy;
    out.height = bar.height;
    out.glow = bar.height * uniforms.glowIntensity;
    
    return out;
}

// MARK: - Waveform Analysis Compute Shader

kernel void fft_compute(device float* inputReal [[buffer(0)]],
                       device float* inputImag [[buffer(1)]],
                       device float* outputMagnitudes [[buffer(2)]],
                       constant int& fftSize [[buffer(3)]],
                       uint gid [[thread_position_in_grid]]) {
    
    if (gid >= uint(fftSize / 2)) return;
    
    // This is a simplified GPU-based FFT component
    // In practice, you'd use more sophisticated FFT algorithms
    
    float real = inputReal[gid];
    float imag = inputImag[gid];
    
    // Calculate magnitude
    float magnitude = sqrt(real * real + imag * imag);
    
    // Apply logarithmic scaling
    magnitude = log10(1.0 + magnitude * 9.0); // Log scale from 1 to 10
    
    outputMagnitudes[gid] = magnitude;
}

// MARK: - Audio Reactive Color Palette

float3 audioReactiveColor(float frequency, float amplitude, float time) {
    // Create dynamic color based on audio characteristics
    float hue = frequency * 360.0 + time * 30.0; // Rotating hue based on frequency
    float saturation = 0.8 + amplitude * 0.2;
    float brightness = 0.5 + amplitude * 0.5;
    
    // Convert HSB to RGB
    float c = brightness * saturation;
    float x = c * (1.0 - abs(fmod(hue / 60.0, 2.0) - 1.0));
    float m = brightness - c;
    
    float3 rgb;
    if (hue < 60.0) {
        rgb = float3(c, x, 0);
    } else if (hue < 120.0) {
        rgb = float3(x, c, 0);
    } else if (hue < 180.0) {
        rgb = float3(0, c, x);
    } else if (hue < 240.0) {
        rgb = float3(0, x, c);
    } else if (hue < 300.0) {
        rgb = float3(x, 0, c);
    } else {
        rgb = float3(c, 0, x);
    }
    
    return rgb + m;
}

// MARK: - Beat Detection Visualization

kernel void beat_detection(device float* magnitudes [[buffer(0)]],
                          device float* beatStrength [[buffer(1)]],
                          constant int& numBands [[buffer(2)]],
                          constant float& threshold [[buffer(3)]],
                          uint gid [[thread_position_in_grid]]) {
    
    if (gid >= uint(numBands)) return;
    
    // Simple beat detection based on magnitude changes
    float current = magnitudes[gid];
    float previous = gid > 0 ? magnitudes[gid - 1] : 0.0;
    
    float change = current - previous;
    float beat = change > threshold ? change : 0.0;
    
    // Smooth beat strength over time
    beatStrength[gid] = beatStrength[gid] * 0.9 + beat * 0.1;
}