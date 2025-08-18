# 🎵 Winamp Skin Converter for macOS

Convert classic Winamp .wsz skins for use with macOS Winamp players.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-15.0+-blue.svg)](https://www.apple.com/macos)
[![Build](https://img.shields.io/badge/Build-✅_GREEN-green.svg)](#)

## 🚀 Quick Start

### Working Tools (Ready to Use)

```bash
# 1. Simple skin converter (standalone script)
./simple_skin_converter.swift

# 2. Command-line converter (Swift package)
swift run WinampSkinCLI test
swift run WinampSkinCLI convert "Purple_Glow.wsz"
swift run WinampSkinCLI batch

# 3. Basic skin tester  
swift WinampSimpleTest/main.swift

# 4. Minimal Winamp player demo
./winamp-lite
```

### What It Does

Converts Windows Winamp skins (.wsz files) to macOS-compatible format:

1. **Extracts .wsz archives** (ZIP files containing skin assets)
2. **Loads main.bmp** (primary skin graphics)  
3. **Converts coordinates** Windows Y-down → macOS Y-up
4. **Prepares for integration** with existing macOS Winamp players

## 🎯 Core Functionality

### Conversion Process
- ✅ Extracts .wsz ZIP archives
- ✅ Finds main.bmp in nested directories
- ✅ Converts Windows to macOS coordinate systems
- ✅ Prepares images for Metal texture usage
- ✅ Maps button regions for hit-testing

### Tested Skins
- ✅ **Carrie-Anne Moss.wsz** - 273×115 (Matrix theme)
- ✅ **netscape_winamp.wsz** - 275×116 (Browser theme)  
- ✅ **Purple_Glow.wsz** - 206×87 (Colorful theme)
- ⚠️ **Deus_Ex_Amp_by_AJ.wsz** - Different structure (needs investigation)

## 📁 Project Structure

```
winamp-skins-conversion/
├── Tools/ (Working utilities)
│   ├── winamp-lite               # Minimal player demo
│   ├── simple_skin_converter.swift  # Standalone converter
│   └── WinampSimpleTest/         # Basic skin analysis
├── Sources/SimpleCLI/            # Swift package CLI
├── *.wsz                         # Test skin files
├── Archive/                      # Complex experiments (archived)
└── Package.swift                 # Swift package (simplified)
```

## 🔧 Building

### Requirements
- macOS 15.0+
- Swift 6.0+
- Command-line tools (unzip)

### Build Commands
```bash
# Build the Swift package
swift build

# Test the converter
swift run WinampSkinCLI test

# Build minimal player
swiftc -o winamp-lite WinampLite/main.swift -framework AppKit -framework AVFoundation
```

## 🎨 Using with Existing Winamp Players

This converter prepares Winamp skins for integration with existing macOS Winamp implementations:

1. **Image Assets**: NSImage objects ready for texture creation
2. **Coordinate Mapping**: Button positions converted to macOS coordinate space  
3. **Window Shapes**: Data ready for NSBezierPath hit-testing
4. **Color Information**: RGB values prepared for macOS color spaces

### Integration Example
```swift
let converter = WinampSkinConverter()
let convertedSkin = try converter.convertSkin(at: "MyCustomSkin.wsz")

// Use with your existing player:
// - convertedSkin.originalImage → Create Metal texture
// - convertedSkin.convertedRegions → Setup hit-testing  
// - convertedSkin.windowHeight → Calculate window bounds
```

## 📊 Project Status

**Current State**: ✅ **WORKING BASELINE**
- Core conversion functionality: **COMPLETE**
- Command-line tools: **FUNCTIONAL**  
- Build system: **GREEN**
- Ready for integration with existing players

**Future Enhancements**: Archived in `/Archive/` directory
- Full SwiftUI player app (complex, needs Swift 6 fixes)
- Metal rendering pipeline (experimental)
- Advanced UI components (documented but not built)

## 🤝 Contributing

1. Fork repository
2. Test with: `swift run WinampSkinCLI test`
3. Make changes to working code only
4. Ensure `swift build` stays green
5. Submit PR

## 📄 License

MIT License - Preserve Winamp's legacy on modern macOS.

---

**Focus**: Simple, working skin conversion for integration with existing Winamp players.  
**Status**: Ready for production use.
