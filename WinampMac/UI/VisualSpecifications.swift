//
//  VisualSpecifications.swift
//  WinampMac
//
//  Comprehensive visual design specifications for Winamp to macOS migration
//  Optimized for Metal rendering, Retina displays, and modern macOS features
//

import Foundation
import AppKit
import Metal

/// Complete visual specification system for Winamp macOS player
public struct WinampVisualSpecifications {
    
    // MARK: - Design System Foundation
    
    /// Core spacing system based on 4px grid for pixel-perfect layouts
    public enum Spacing {
        static let xxxs: CGFloat = 2   // 0.125rem - Micro spacing
        static let xxs: CGFloat = 4    // 0.25rem - Tight spacing
        static let xs: CGFloat = 8     // 0.5rem - Small spacing
        static let sm: CGFloat = 12    // 0.75rem - Default small
        static let md: CGFloat = 16    // 1rem - Default medium
        static let lg: CGFloat = 24    // 1.5rem - Section spacing
        static let xl: CGFloat = 32    // 2rem - Large spacing
        static let xxl: CGFloat = 48   // 3rem - Hero spacing
        static let xxxl: CGFloat = 64  // 4rem - Maximum spacing
        
        /// Component-specific spacing presets
        static let buttonPadding: CGFloat = xs
        static let sliderTrack: CGFloat = xxs
        static let windowBorder: CGFloat = sm
        static let controlSpacing: CGFloat = md
    }
    
    /// Typography scale optimized for pixel art aesthetics and modern readability
    public enum Typography {
        static let display = NSFont.systemFont(ofSize: 36, weight: .bold)     // Hero headlines
        static let h1 = NSFont.systemFont(ofSize: 30, weight: .semibold)      // Page titles
        static let h2 = NSFont.systemFont(ofSize: 24, weight: .medium)        // Section headers
        static let h3 = NSFont.systemFont(ofSize: 20, weight: .medium)        // Card titles
        static let body = NSFont.systemFont(ofSize: 16, weight: .regular)     // Default text
        static let small = NSFont.systemFont(ofSize: 14, weight: .regular)    // Secondary text
        static let tiny = NSFont.systemFont(ofSize: 12, weight: .regular)     // Captions
        static let code = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular) // Monospace
        
        /// Winamp-specific pixel fonts for authentic display
        static let digitalDisplay = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        static let playlistTime = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    }
    
    /// Color system with classic Winamp palette and modern macOS integration
    public struct ColorPalette {
        
        // MARK: - Core Brand Colors
        static let winampGreen = NSColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)      // #00FF00
        static let winampBlue = NSColor(srgbRed: 0.0, green: 0.4, blue: 1.0, alpha: 1.0)       // #0066FF
        static let winampOrange = NSColor(srgbRed: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)     // #FF9900
        static let winampRed = NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)        // #FF0000
        static let winampYellow = NSColor(srgbRed: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)     // #FFFF00
        
        // MARK: - Classic Skin Colors
        static let classicBackground = NSColor(srgbRed: 0.667, green: 0.667, blue: 0.667, alpha: 1.0) // #AAAAAA
        static let classicFrame = NSColor(srgbRed: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)           // #666666
        static let classicHighlight = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)       // #FFFFFF
        static let classicShadow = NSColor(srgbRed: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)          // #333333
        
        // MARK: - Modern Adaptive Colors
        static let primary = NSColor.controlAccentColor
        static let secondary = NSColor.secondaryLabelColor
        static let background = NSColor.windowBackgroundColor
        static let surface = NSColor.controlBackgroundColor
        static let onSurface = NSColor.controlTextColor
        static let onBackground = NSColor.labelColor
        
        // MARK: - Visualization Colors
        static let spectrumGradient = [
            NSColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),    // Bright green
            NSColor(srgbRed: 0.5, green: 1.0, blue: 0.0, alpha: 1.0),    // Yellow-green
            NSColor(srgbRed: 1.0, green: 1.0, blue: 0.0, alpha: 1.0),    // Yellow
            NSColor(srgbRed: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),    // Orange
            NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)     // Red
        ]
        
        // MARK: - Status Colors
        static let success = NSColor.systemGreen
        static let warning = NSColor.systemOrange
        static let error = NSColor.systemRed
        static let info = NSColor.systemBlue
        
        // MARK: - Glassmorphism Effects
        static let glassBackground = NSColor(white: 1.0, alpha: 0.1)
        static let glassBorder = NSColor(white: 1.0, alpha: 0.2)
        static let glassHighlight = NSColor(white: 1.0, alpha: 0.4)
    }
    
    // MARK: - Component Specifications
    
    /// Main player window visual specification
    public struct MainPlayerWindow {
        static let baseSize = NSSize(width: 275, height: 116)  // Classic Winamp dimensions
        static let retinaSize = NSSize(width: 550, height: 232) // 2x for Retina
        static let cornerRadius: CGFloat = 0 // Classic sharp corners
        static let borderWidth: CGFloat = 1
        static let shadowRadius: CGFloat = 8
        static let shadowOpacity: Float = 0.3
        static let shadowOffset = NSSize(width: 0, height: -2)
        
        /// Titlebar specifications
        struct Titlebar {
            static let height: CGFloat = 14
            static let buttonSize = NSSize(width: 9, height: 9)
            static let buttonSpacing: CGFloat = 2
            static let textInset: CGFloat = 4
            static let textColor = ColorPalette.onSurface
            static let backgroundColor = ColorPalette.classicFrame
        }
        
        /// Display area for track info and time
        struct DisplayArea {
            static let frame = NSRect(x: 111, y: 27, width: 153, height: 13)
            static let backgroundColor = NSColor.black
            static let textColor = ColorPalette.winampGreen
            static let font = Typography.digitalDisplay
            static let cornerRadius: CGFloat = 1
            static let internalPadding: CGFloat = 2
        }
        
        /// Track information display
        struct TrackInfo {
            static let frame = NSRect(x: 111, y: 43, width: 153, height: 9)
            static let scrollSpeed: CGFloat = 1.0 // pixels per frame
            static let scrollPause: TimeInterval = 2.0 // seconds
            static let font = Typography.small
            static let textColor = ColorPalette.onSurface
        }
        
        /// Visualization window
        struct VisualizationWindow {
            static let frame = NSRect(x: 24, y: 43, width: 76, height: 16)
            static let backgroundColor = NSColor.black
            static let borderColor = ColorPalette.classicFrame
            static let borderWidth: CGFloat = 1
            static let spectrumBarWidth: CGFloat = 1
            static let spectrumBarGap: CGFloat = 0
            static let spectrumBarCount: Int = 75
        }
    }
    
    /// Control button specifications
    public struct ControlButtons {
        static let baseSize = NSSize(width: 23, height: 18)
        static let spacing: CGFloat = 1
        
        /// Button positions in main window
        static let previousPosition = NSPoint(x: 16, y: 88)
        static let playPosition = NSPoint(x: 39, y: 88)
        static let pausePosition = NSPoint(x: 62, y: 88)
        static let stopPosition = NSPoint(x: 85, y: 88)
        static let nextPosition = NSPoint(x: 108, y: 88)
        static let ejectPosition = NSPoint(x: 136, y: 89)
        
        /// Visual states with animation specifications
        struct States {
            static let normalAlpha: CGFloat = 1.0
            static let pressedScale: CGFloat = 0.95
            static let pressedDuration: TimeInterval = 0.05
            static let hoverGlow: CGFloat = 0.2
            static let disabledAlpha: CGFloat = 0.5
            
            /// Spring animation parameters
            static let springDamping: CGFloat = 0.8
            static let springVelocity: CGFloat = 0.6
            static let springMass: CGFloat = 1.0
            static let springStiffness: CGFloat = 100.0
        }
    }
    
    /// Volume and balance slider specifications
    public struct Sliders {
        
        /// Volume slider
        struct Volume {
            static let trackFrame = NSRect(x: 107, y: 57, width: 68, height: 13)
            static let thumbSize = NSSize(width: 14, height: 11)
            static let trackHeight: CGFloat = 2
            static let range: ClosedRange<Float> = 0...1
            static let snapDistance: CGFloat = 4 // Snap to center
        }
        
        /// Balance slider
        struct Balance {
            static let trackFrame = NSRect(x: 177, y: 57, width: 38, height: 13)
            static let thumbSize = NSSize(width: 14, height: 11)
            static let trackHeight: CGFloat = 2
            static let range: ClosedRange<Float> = -1...1
            static let centerSnapZone: CGFloat = 0.1 // Snap to center balance
        }
        
        /// Position slider (seek bar)
        struct Position {
            static let trackFrame = NSRect(x: 16, y: 72, width: 248, height: 10)
            static let thumbSize = NSSize(width: 29, height: 10)
            static let trackHeight: CGFloat = 3
            static let range: ClosedRange<Float> = 0...1
            static let smoothingFactor: CGFloat = 0.9 // For smooth seeking
        }
        
        /// Animation and interaction specifications
        struct Interaction {
            static let thumbPressScale: CGFloat = 1.1
            static let thumbHoverGlow: CGFloat = 0.3
            static let trackFillColor = ColorPalette.winampGreen
            static let trackEmptyColor = ColorPalette.classicShadow
            static let animationDuration: TimeInterval = 0.15
        }
    }
    
    /// Status indicator specifications
    public struct StatusIndicators {
        
        /// Stereo/Mono indicator
        struct StereoMono {
            static let position = NSPoint(x: 212, y: 41)
            static let size = NSSize(width: 28, height: 12)
            static let stereoColor = ColorPalette.winampGreen
            static let monoColor = ColorPalette.winampOrange
            static let offColor = ColorPalette.classicShadow
        }
        
        /// Shuffle indicator
        struct Shuffle {
            static let position = NSPoint(x: 164, y: 89)
            static let size = NSSize(width: 28, height: 15)
            static let activeColor = ColorPalette.winampYellow
            static let inactiveColor = ColorPalette.classicFrame
        }
        
        /// Repeat indicator
        struct Repeat {
            static let position = NSPoint(x: 210, y: 89)
            static let size = NSSize(width: 28, height: 15)
            static let activeColor = ColorPalette.winampYellow
            static let inactiveColor = ColorPalette.classicFrame
        }
        
        /// EQ/PL buttons
        struct EQPLButtons {
            static let eqPosition = NSPoint(x: 219, y: 58)
            static let plPosition = NSPoint(x: 242, y: 58)
            static let size = NSSize(width: 23, height: 12)
            static let activeColor = ColorPalette.winampGreen
            static let inactiveColor = ColorPalette.classicFrame
        }
    }
    
    // MARK: - Equalizer Window Specifications
    
    public struct EqualizerWindow {
        static let baseSize = NSSize(width: 275, height: 116)
        static let expandedSize = NSSize(width: 275, height: 232) // When showing all bands
        
        /// Preamp control
        struct Preamp {
            static let position = NSPoint(x: 21, y: 38)
            static let size = NSSize(width: 13, height: 63)
            static let range: ClosedRange<Float> = -20...20 // dB
            static let tickMarks: [Float] = [-20, -10, 0, 10, 20]
        }
        
        /// 10-band equalizer sliders
        struct Bands {
            static let startX: CGFloat = 78
            static let spacing: CGFloat = 18
            static let sliderSize = NSSize(width: 13, height: 63)
            static let range: ClosedRange<Float> = -20...20 // dB
            static let frequencies = ["60", "170", "310", "600", "1K", "3K", "6K", "12K", "14K", "16K"]
            
            /// Visual styling
            static let activeColor = ColorPalette.winampGreen
            static let inactiveColor = ColorPalette.classicFrame
            static let centerLineColor = ColorPalette.classicHighlight
            static let tickColor = ColorPalette.classicShadow
        }
        
        /// Preset controls
        struct Presets {
            static let autoPosition = NSPoint(x: 61, y: 103)
            static let presetPosition = NSPoint(x: 142, y: 103)
            static let buttonSize = NSSize(width: 33, height: 12)
            static let dropdownSize = NSSize(width: 100, height: 200)
        }
        
        /// Window docking specifications
        struct Docking {
            static let snapDistance: CGFloat = 20
            static let snapAnimation: TimeInterval = 0.2
            static let alignmentGuideColor = ColorPalette.primary
            static let alignmentGuideWidth: CGFloat = 2
            static let alignmentGuideAlpha: CGFloat = 0.8
        }
    }
    
    // MARK: - Playlist Window Specifications
    
    public struct PlaylistWindow {
        static let baseSize = NSSize(width: 275, height: 232)
        static let minimumSize = NSSize(width: 275, height: 116)
        static let maximumSize = NSSize(width: 1024, height: 768)
        
        /// Track list specifications
        struct TrackList {
            static let rowHeight: CGFloat = 13
            static let alternateRowAlpha: CGFloat = 0.05
            static let scrollBarWidth: CGFloat = 16
            static let textInset: CGFloat = 4
            
            /// Selection states
            struct Selection {
                static let normalBackground = NSColor.clear
                static let selectedBackground = ColorPalette.primary
                static let playingBackground = ColorPalette.winampGreen
                static let selectedTextColor = NSColor.white
                static let playingTextColor = NSColor.black
                static let normalTextColor = ColorPalette.onSurface
            }
            
            /// Drag and drop styling
            struct DragDrop {
                static let insertLineColor = ColorPalette.primary
                static let insertLineWidth: CGFloat = 2
                static let dragImageAlpha: CGFloat = 0.7
                static let dropHighlightColor = ColorPalette.primary
                static let dropHighlightAlpha: CGFloat = 0.2
            }
        }
        
        /// Control buttons
        struct Controls {
            static let buttonSize = NSSize(width: 22, height: 18)
            static let spacing: CGFloat = 2
            
            static let addPosition = NSPoint(x: 12, y: 204)
            static let removePosition = NSPoint(x: 40, y: 204)
            static let selectPosition = NSPoint(x: 68, y: 204)
            static let miscPosition = NSPoint(x: 96, y: 204)
            static let listPosition = NSPoint(x: 124, y: 204)
        }
        
        /// Search field
        struct Search {
            static let frame = NSRect(x: 152, y: 204, width: 100, height: 18)
            static let cornerRadius: CGFloat = 9
            static let backgroundColor = NSColor.textBackgroundColor
            static let textColor = NSColor.textColor
            static let placeholderColor = NSColor.placeholderTextColor
        }
    }
    
    // MARK: - Visualization Modes
    
    public struct VisualizationModes {
        
        /// Spectrum analyzer
        struct Spectrum {
            static let barCount: Int = 75
            static let barWidth: CGFloat = 1
            static let barGap: CGFloat = 0
            static let maxHeight: CGFloat = 16
            static let falloffRate: Float = 0.9
            static let responseTime: Float = 0.1
            static let colors = ColorPalette.spectrumGradient
        }
        
        /// Oscilloscope
        struct Oscilloscope {
            static let lineWidth: CGFloat = 1
            static let sampleCount: Int = 76
            static let amplitudeScale: Float = 8.0
            static let lineColor = ColorPalette.winampGreen
            static let backgroundColor = NSColor.black
            static let smoothing: Float = 0.8
        }
        
        /// Advanced visualization modes
        struct Advanced {
            /// Fire effect
            struct Fire {
                static let particleCount: Int = 200
                static let particleSize: CGFloat = 2
                static let flameHeight: CGFloat = 12
                static let colorTemperature: [NSColor] = [
                    NSColor.black,
                    NSColor.systemRed,
                    NSColor.systemOrange,
                    NSColor.systemYellow,
                    NSColor.white
                ]
            }
            
            /// Tunnel effect
            struct Tunnel {
                static let ringCount: Int = 8
                static let rotationSpeed: Float = 0.02
                static let pulseIntensity: Float = 0.5
                static let tunnelColor = ColorPalette.winampBlue
            }
            
            /// Dots visualization
            struct Dots {
                static let gridSize: Int = 8
                static let dotSize: CGFloat = 1.5
                static let spacing: CGFloat = 2
                static let maxIntensity: Float = 1.0
                static let baseColor = ColorPalette.winampGreen
            }
        }
    }
    
    // MARK: - Animation System
    
    public struct AnimationSystem {
        
        /// Core timing curves
        static let easeInOut = CAMediaTimingFunction(controlPoints: 0.42, 0, 0.58, 1)
        static let easeOut = CAMediaTimingFunction(controlPoints: 0, 0, 0.58, 1)
        static let easeIn = CAMediaTimingFunction(controlPoints: 0.42, 0, 1, 1)
        static let bounceOut = CAMediaTimingFunction(controlPoints: 0.68, -0.55, 0.265, 1.55)
        
        /// Transition durations
        static let microAnimation: TimeInterval = 0.05   // Button press
        static let fastAnimation: TimeInterval = 0.15    // Hover effects
        static let standardAnimation: TimeInterval = 0.25 // UI transitions
        static let slowAnimation: TimeInterval = 0.35    // Window operations
        
        /// Window shade animation
        struct WindowShade {
            static let duration: TimeInterval = 0.15
            static let timingCurve = easeInOut
            static let shadedHeight: CGFloat = 14 // Titlebar only
            static let bounceDistance: CGFloat = 2
        }
        
        /// Visualization transitions
        struct VisualizationTransition {
            static let crossfadeDuration: TimeInterval = 0.5
            static let morphDuration: TimeInterval = 0.3
            static let colorTransition: TimeInterval = 0.2
        }
        
        /// Physics-based animations
        struct Physics {
            static let springMass: CGFloat = 1.0
            static let springStiffness: CGFloat = 300.0
            static let springDamping: CGFloat = 30.0
            static let springVelocity: CGFloat = 0.0
        }
    }
    
    // MARK: - Metal Shader Parameters
    
    public struct MetalShaderParameters {
        
        /// Spectrum visualization shader
        struct SpectrumShader {
            static let vertexShaderName = "spectrumVertex"
            static let fragmentShaderName = "spectrumFragment"
            
            /// Uniform parameters
            static let barWidthUniform = "barWidth"
            static let barHeightUniform = "barHeight"
            static let colorUniform = "barColor"
            static let timeUniform = "time"
            static let intensityUniform = "intensity"
        }
        
        /// Blur effect for glassmorphism
        struct BlurShader {
            static let vertexShaderName = "blurVertex"
            static let fragmentShaderName = "blurFragment"
            static let blurRadiusUniform = "blurRadius"
            static let intensityUniform = "intensity"
            static let directionUniform = "direction"
        }
        
        /// Color grading for theme adaptation
        struct ColorGradingShader {
            static let fragmentShaderName = "colorGrading"
            static let exposureUniform = "exposure"
            static let contrastUniform = "contrast"
            static let saturationUniform = "saturation"
            static let temperatureUniform = "temperature"
        }
    }
    
    // MARK: - Asset Requirements
    
    public struct AssetRequirements {
        
        /// Image formats and sizes
        static let supportedFormats = ["png", "bmp", "gif", "jpg"]
        static let baseResolution: CGFloat = 1.0
        static let retinaResolution: CGFloat = 2.0
        static let superRetinaResolution: CGFloat = 3.0
        
        /// Asset naming convention
        static let assetNames = [
            "main",      // Main window background
            "cbuttons",  // Control buttons
            "titlebar",  // Title bar
            "numbers",   // Digital display font
            "text",      // Track info text
            "volume",    // Volume slider
            "balance",   // Balance slider
            "posbar",    // Position bar
            "playpaus",  // Play/pause button
            "monoster",  // Mono/stereo indicator
            "shufrep",   // Shuffle/repeat buttons
            "eqmain",    // Equalizer window
            "pledit",    // Playlist window
            "eq_ex",     // EQ sliders
            "genex"      // General extended UI
        ]
        
        /// Sprite sheet specifications
        struct SpriteSheets {
            static let buttonStates: Int = 3  // Normal, pressed, disabled
            static let sliderFrames: Int = 28 // Volume/balance positions
            static let digitFrames: Int = 12  // 0-9, colon, minus
            static let equalizerSliders: Int = 28 // EQ band positions
        }
    }
    
    // MARK: - Accessibility Specifications
    
    public struct AccessibilitySpecs {
        
        /// High contrast mode adaptations
        struct HighContrast {
            static let minimumContrastRatio: Float = 4.5
            static let borderWidthIncrease: CGFloat = 1
            static let focusRingWidth: CGFloat = 3
            static let focusRingColor = NSColor.keyboardFocusIndicatorColor
        }
        
        /// Voice Over support
        struct VoiceOver {
            static let buttonDescriptions: [String: String] = [
                "play": "Play button",
                "pause": "Pause button",
                "stop": "Stop button",
                "previous": "Previous track",
                "next": "Next track",
                "eject": "Open file"
            ]
            
            static let sliderDescriptions: [String: String] = [
                "volume": "Volume slider",
                "balance": "Balance slider",
                "position": "Track position slider"
            ]
        }
        
        /// Reduced motion alternatives
        struct ReducedMotion {
            static let disableAnimations: [String] = [
                "visualization",
                "spectrum",
                "windowShade",
                "buttonPress"
            ]
            static let staticIndicatorDuration: TimeInterval = 0.1
        }
    }
    
    // MARK: - ProMotion Display Support
    
    public struct ProMotionSupport {
        static let preferredFrameRate: Int = 120
        static let fallbackFrameRate: Int = 60
        static let minimumFrameRate: Int = 30
        
        /// Adaptive refresh rates for different content
        static let visualizationFrameRate: Int = 120  // Smooth spectrum
        static let uiAnimationFrameRate: Int = 60     // Standard UI
        static let idleFrameRate: Int = 30            // Power saving
        
        /// Frame rate detection
        static func detectOptimalFrameRate() -> Int {
            if let screen = NSScreen.main {
                // Detect ProMotion capability
                if screen.maximumRefreshInterval <= 1.0/120.0 {
                    return preferredFrameRate
                } else if screen.maximumRefreshInterval <= 1.0/60.0 {
                    return fallbackFrameRate
                }
            }
            return minimumFrameRate
        }
    }
}

// MARK: - Usage Example and Integration Points

extension WinampVisualSpecifications {
    
    /// Generate CSS-like specifications for web documentation
    static func generateStyleSheet() -> String {
        return """
        /* Winamp macOS Visual Specifications */
        
        :root {
            /* Spacing System */
            --spacing-xxxs: 2px;
            --spacing-xxs: 4px;
            --spacing-xs: 8px;
            --spacing-sm: 12px;
            --spacing-md: 16px;
            --spacing-lg: 24px;
            --spacing-xl: 32px;
            --spacing-xxl: 48px;
            --spacing-xxxl: 64px;
            
            /* Colors */
            --winamp-green: #00FF00;
            --winamp-blue: #0066FF;
            --winamp-orange: #FF9900;
            --winamp-red: #FF0000;
            --winamp-yellow: #FFFF00;
            
            /* Typography */
            --font-display: 36px/40px system-ui bold;
            --font-h1: 30px/36px system-ui semibold;
            --font-body: 16px/24px system-ui regular;
            --font-digital: 13px/16px monospace medium;
            
            /* Animations */
            --duration-micro: 0.05s;
            --duration-fast: 0.15s;
            --duration-standard: 0.25s;
            --duration-slow: 0.35s;
            
            /* Component Sizes */
            --main-window-width: 275px;
            --main-window-height: 116px;
            --button-size: 23px 18px;
            --slider-thumb: 14px 11px;
        }
        
        .winamp-main-window {
            width: var(--main-window-width);
            height: var(--main-window-height);
            border-radius: 0;
            box-shadow: 0 -2px 8px rgba(0,0,0,0.3);
        }
        
        .winamp-button {
            width: 23px;
            height: 18px;
            transition: transform var(--duration-micro) ease-out;
        }
        
        .winamp-button:active {
            transform: scale(0.95);
        }
        
        .visualization-spectrum {
            width: 76px;
            height: 16px;
            background: black;
            border: 1px solid #666;
        }
        """
    }
    
    /// Integration with existing renderer
    static func configureRenderer(_ renderer: WinampRenderer) {
        // Apply visual specifications to existing renderer components
        // This would integrate with the Metal shaders and UI components
    }
}