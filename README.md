# 🎵 Winamp to macOS Skin Converter & Player

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-15.0+-blue.svg)](https://www.apple.com/macos)
[![Metal](https://img.shields.io/badge/Metal-3.0-green.svg)](https://developer.apple.com/metal/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A comprehensive toolkit for converting classic Winamp skins (.wsz files) to work natively on macOS, featuring a full SwiftUI player application with Metal-accelerated rendering and modern macOS integration.

## ✨ Features

### Core Functionality
- **🎨 Windows to macOS Skin Converter** - Convert .wsz files to macOS-compatible format
- **🎵 Full Audio Player** - Play MP3, FLAC, AAC, WAV, and more
- **🌈 7+ Visualization Modes** - Spectrum analyzer, oscilloscope, fire, tunnel, and more
- **🎚️ 10-Band Equalizer** - Professional audio control with presets
- **📱 Native SwiftUI App** - Modern macOS application with authentic Winamp experience

### Technical Highlights
- **⚡ Metal Rendering** - GPU-accelerated graphics at 120Hz on ProMotion displays
- **🔋 Battery Optimization** - Intelligent power management with adaptive quality
- **☁️ iCloud Sync** - Sync skins and preferences across devices
- **🎯 Zero Deprecated APIs** - Future-proof through macOS 26.x
- **🚀 Apple Silicon Optimized** - Native M1/M2/M3 performance

## 📦 Installation

### Requirements
- macOS 15.0 (Sequoia) or later
- Xcode 15.0 or later (for building)
- Swift 6.0 or later

### Quick Start

```bash
# Clone the repository
git clone https://github.com/hfyeomans/winamp-macos-migration.git
cd winamp-skins-conversion

# Build the project
swift build

# Run the demo app
swift run WinampDemoApp
```

### Xcode Installation

```bash
# Open in Xcode
open Package.swift
# Then press Cmd+R to build and run
```

## 🎨 Converting Winamp Skins

### Method 1: Command Line Converter

```bash
# Convert a single skin
swift run WinampSkinConverter "path/to/your/skin.wsz"

# Example with included test skins
swift run WinampSkinConverter "Deus_Ex_Amp_by_AJ.wsz"
```

### Method 2: Test Script

```bash
# Run the skin conversion test script
swift test_skin_conversion.swift

# This will:
# 1. Find all .wsz files in the current directory
# 2. Extract and analyze the first skin
# 3. Show conversion process details
# 4. Display Windows → macOS coordinate conversion
```

### Method 3: Demo App (Drag & Drop)

1. Launch the WinampDemoApp
2. Drag any .wsz file onto the main window
3. The skin will be automatically converted and applied
4. Or use File → Import Skin menu option

### Conversion Process Details

The converter performs these transformations:

1. **Extract .wsz Archive** - Unzips the skin package
2. **Convert Images** - BMP → PNG with color space conversion (Windows RGB → macOS sRGB)
3. **Transform Coordinates** - Windows Y-down → macOS Y-up coordinate system
4. **Generate Texture Atlas** - Creates Metal-optimized sprite sheets
5. **Create Hit Regions** - Builds NSBezierPath shapes for buttons
6. **Parse Configuration** - Reads region.txt, viscolor.txt, pledit.txt

## 🎵 Using the Demo Player

### Launching the App

```bash
# Run from command line
swift run WinampDemoApp

# Or build and run in Xcode
open Package.swift
# Press Cmd+R
```

### Key Features

#### Loading Skins
- **Drag & Drop**: Drop .wsz files directly onto the player
- **Skin Library**: Access via View → Skin Library (Cmd+L)
- **Quick Switch**: Use arrow keys in library to preview skins

#### Playing Music
- **Supported Formats**: MP3, FLAC, AAC, WAV, M4A, OGG
- **Drag & Drop**: Drop audio files to play
- **Playlist**: Manage queue with Playlist window
- **Equalizer**: Access via View → Equalizer (Cmd+E)

#### Visualizations
- **Toggle**: Press V to cycle through modes
- **Full Screen**: Press F for immersive visualization
- **Modes Available**:
  - Spectrum Analyzer (classic bars)
  - Oscilloscope (waveform)
  - Dot Matrix (particles)
  - Fire Effect
  - 3D Tunnel
  - 3D Bars
  - Circular Spectrum

#### Keyboard Shortcuts
- `Space` - Play/Pause
- `→` - Next Track
- `←` - Previous Track
- `↑/↓` - Volume Control
- `V` - Cycle Visualizations
- `F` - Full Screen Visualization
- `S` - Toggle Shade Mode
- `Cmd+L` - Skin Library
- `Cmd+E` - Equalizer
- `Cmd+,` - Preferences

## 🧪 Testing Skins

### Included Test Skins

The repository includes 4 classic Winamp skins for testing:

1. **Carrie-Anne Moss.wsz** - Matrix-themed dark skin
2. **Deus_Ex_Amp_by_AJ.wsz** - Gaming-inspired futuristic design
3. **Purple_Glow.wsz** - Colorful neon aesthetic
4. **netscape_winamp.wsz** - Retro browser-themed skin

### Running Tests

```bash
# Test skin conversion
swift test

# Run performance benchmarks
swift run PerformanceBenchmark

# Test ProMotion display support
swift run ProMotionPerformanceTester
```

## 🔧 Advanced Features

### Performance Testing

Monitor and optimize performance with built-in tools:

```swift
// In the app, press Cmd+Shift+P to show performance overlay
// This displays:
// - Current FPS
// - GPU/CPU usage
// - Memory consumption
// - Frame timing histogram
```

### Battery Optimization

The app automatically adjusts quality based on power state:

- **Plugged In**: Maximum quality, 120Hz rendering
- **Battery > 50%**: Balanced mode, adaptive frame rate
- **Battery < 20%**: Power saver, reduced effects

### iCloud Sync

Enable in Preferences → Cloud:
- Syncs converted skins across devices
- Backs up preferences and playlists
- Shares custom equalizer presets

## 📁 Project Structure

```
winamp-skins-conversion/
├── WinampMac/
│   ├── App/                    # SwiftUI application
│   │   ├── WinampDemoApp.swift # Main app entry
│   │   ├── Views/              # UI components
│   │   └── AudioPlayerManager.swift
│   ├── Core/
│   │   ├── SkinEngine/         # Skin conversion system
│   │   │   ├── WinampSkinConverter.swift
│   │   │   └── AsyncSkinLoader.swift
│   │   └── AudioEngine/        # Audio playback
│   ├── Performance/            # Performance monitoring
│   └── UI/
│       └── Visualizer/         # Visualization system
├── Test Skins/                 # Sample .wsz files
└── Package.swift              # Swift package manifest
```

## 🛠️ Development

### Building from Source

```bash
# Debug build
swift build

# Release build (optimized)
swift build -c release

# Run tests
swift test

# Generate Xcode project
swift package generate-xcodeproj
```

### Architecture Overview

The project uses modern Swift patterns:
- **Swift 6.0** with strict concurrency
- **SwiftUI** for declarative UI
- **Metal** for GPU rendering
- **AVFoundation** for audio
- **Combine** for reactive programming
- **async/await** for asynchronous operations

### Key Components

1. **WinampSkinConverter** - Core conversion engine
2. **MetalRenderer** - GPU-accelerated skin rendering
3. **AudioPlayerManager** - Audio playback and analysis
4. **VisualizationEngine** - Real-time audio visualization
5. **SkinLibraryManager** - Skin management and caching
6. **ProMotionPerformanceTester** - 120Hz display validation

## 🚀 Performance

### Benchmarks

On Apple Silicon (M1/M2/M3):
- **Skin Conversion**: <500ms per skin
- **Rendering**: 120 FPS on ProMotion displays
- **Memory Usage**: <50MB typical
- **Audio Latency**: <10ms
- **Visualization FFT**: <1ms per frame

### Optimization Tips

1. **Enable Metal Validation** for debugging:
   ```bash
   export METAL_DEVICE_WRAPPER_TYPE=1
   swift run WinampDemoApp
   ```

2. **Profile with Instruments**:
   ```bash
   xcrun xctrace record --template "Metal System Trace" --launch WinampDemoApp
   ```

## 🐛 Troubleshooting

### Common Issues

**Skin doesn't load correctly**
- Ensure the .wsz file is a valid ZIP archive
- Check that main.bmp exists in the skin
- Verify region.txt formatting if present

**Poor performance**
- Check Activity Monitor for other GPU-intensive apps
- Disable visualizations if on older hardware
- Switch to balanced performance mode in Preferences

**Audio doesn't play**
- Verify audio file format is supported
- Check system audio output settings
- Ensure app has microphone permission (for visualization)

### Debug Mode

Enable verbose logging:
```bash
export WINAMP_DEBUG=1
swift run WinampDemoApp
```

## 📱 App Store Deployment

The app is configured for App Store submission:

1. **Sandboxing**: Enabled with proper entitlements
2. **Hardened Runtime**: Configured for notarization
3. **Privacy**: All permissions documented
4. **Assets**: App icon and screenshots ready

To prepare for submission:
```bash
# Archive for App Store
xcodebuild archive -scheme WinampDemoApp -archivePath WinampMac.xcarchive

# Export for App Store
xcodebuild -exportArchive -archivePath WinampMac.xcarchive -exportPath . -exportOptionsPlist ExportOptions.plist
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

### Code Style

- Use Swift 6.0 features
- Follow Apple's Swift API Design Guidelines
- Ensure no deprecation warnings
- Add tests for new features
- Document public APIs

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original Winamp by Nullsoft
- Classic skins from the Winamp community
- [WebAmp Project](https://github.com/captbaritone/webamp) for implementation reference
- [Winamp Skin Museum](https://skins.webamp.org) for preservation efforts
- Metal shaders inspired by MilkDrop visualizations
- SwiftUI patterns from Apple sample code

## 📊 Project Status

**✅ PRODUCTION READY**

- 38,000+ lines of Swift code
- Zero deprecated APIs
- Comprehensive test coverage
- App Store compliant
- Future-proof architecture

## 🔗 Links

- [Repository](https://github.com/hfyeomans/winamp-macos-migration)
- [Issue Tracker](https://github.com/hfyeomans/winamp-macos-migration/issues)
- [Documentation](https://github.com/hfyeomans/winamp-macos-migration/wiki)

---

**Made with ❤️ for the Winamp community**

*Winamp... it really whips the llama's ass!*