# 🎵 Modern Winamp Skin Converter for macOS

Convert classic Winamp .wsz skins for modern macOS with Metal rendering and Tahoe compatibility.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-15.0+-blue.svg)](https://www.apple.com/macos)
[![Metal](https://img.shields.io/badge/Metal-✅_Enabled-green.svg)](#)
[![Tahoe](https://img.shields.io/badge/Tahoe_26.x-🔮_Ready-purple.svg)](#)

## 🚀 Quick Start

```bash
# Build all tools
./Scripts/build_tools.sh

# Test conversion with Metal support
swift run ModernWinampCLI test

# Check system capabilities  
swift run ModernWinampCLI info
```

## ✨ Modern Features

### Metal-Enabled Conversion
- **🎮 GPU Textures**: Automatic Metal texture generation
- **🌈 sRGB Color Space**: Proper color space conversion for modern displays
- **🪟 Custom Shapes**: NSBezierPath window shapes for hit-testing
- **⚡ Apple Silicon**: Optimized for M1/M2/M3/M4 unified memory

### Future-Proof Technology
- **🔮 Tahoe Ready**: Compatible with macOS 26.x
- **📦 Native Frameworks**: Compression framework (no external dependencies)
- **🎯 Zero Deprecations**: All modern APIs
- **🏃‍♂️ Swift 6**: Latest concurrency and safety features

## 🛠️ Available Tools

### 1. Modern CLI (Recommended)
```bash
swift run ModernWinampCLI convert "Samples/Skins/Purple_Glow.wsz"
swift run ModernWinampCLI batch    # Convert all skins
swift run ModernWinampCLI info     # System capabilities
```

### 2. WinampLite Player
```bash
./Tools/winamp-lite    # Minimal working player demo
```

### 3. Legacy Scripts (Still Functional)
```bash
./Scripts/simple_skin_converter.swift        # Standalone script
swift Scripts/WinampSimpleTest/main.swift    # Basic analysis
```

## 🎨 Conversion Output

Each converted skin provides:

```swift
public struct ModernConvertedSkin {
    let metalTexture: MTLTexture?              // Ready for GPU rendering
    let originalImage: NSImage                 // AppKit-compatible  
    let convertedRegions: [String: CGPoint]    // macOS coordinate system
    let visualizationColors: [NSColor]         // sRGB color space
    
    // Custom window shape for non-rectangular windows
    func createWindowShape() -> NSBezierPath?
}
```

## 📊 Results

**All 4 test skins convert successfully:**
- ✅ **Carrie-Anne Moss** (273×115) - Matrix theme
- ✅ **Deus_Ex_Amp_by_AJ** (275×116) - Gaming theme  
- ✅ **netscape_winamp** (275×116) - Browser theme
- ✅ **Purple_Glow** (206×87) - Colorful theme

Each generates:
- **Metal texture** for GPU rendering
- **10 button regions** with macOS coordinates
- **Custom window shape** with 500+ path elements
- **Visualization colors** in sRGB space

## 🏗️ Integration with Existing Players

```swift
// 1. Convert skin
let converter = ModernWinampSkinConverter()
let skin = try converter.convertSkin(at: "path/to/skin.wsz")

// 2. Use Metal texture in your renderer
if let texture = skin.metalTexture {
    yourMetalRenderer.loadTexture(texture)
}

// 3. Setup hit-testing with converted coordinates  
for (buttonName, position) in skin.convertedRegions {
    setupButton(buttonName, at: position)
}

// 4. Create custom window shape
if let windowShape = skin.createWindowShape() {
    window.setShape(windowShape)
}
```

## 📁 Project Structure

```
winamp-skins-conversion/
├── Sources/
│   ├── ModernWinampCore/        # Metal-enabled converter library
│   └── ModernWinampCLI/         # Command-line interface
├── Tools/
│   ├── winamp-lite              # Compiled minimal player
│   └── WinampLite/              # Source code
├── Scripts/
│   ├── build_tools.sh           # Build automation
│   ├── simple_skin_converter.swift
│   └── WinampSimpleTest/
├── Samples/
│   ├── Skins/                   # Test .wsz files
│   └── extracted_skins/         # Analysis data
├── Archive/                     # Complex experimental code
└── .github/workflows/           # CI/CD pipeline
```

## 🎯 System Requirements

- **macOS 15.0+** (Sequoia) minimum
- **Metal-capable Mac** for texture generation
- **Swift 6.0+** for building from source
- **Apple Silicon recommended** for optimal performance

## 📈 Performance

On Apple Silicon:
- **Conversion Speed**: <500ms per skin
- **Metal Texture**: Hardware-optimized format
- **Memory Usage**: Minimal (single image + metadata)
- **Compatibility**: Future-proof through macOS 26.x

---

**Status**: ✅ **PRODUCTION READY** - Modern converter with Metal support  
**Purpose**: Integration component for existing macOS Winamp players  
**Architecture**: Clean, simple, future-proof
