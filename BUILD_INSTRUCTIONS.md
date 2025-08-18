# Build Instructions for Winamp macOS Apps

## Quick Start - Working Apps

### 1. WinampLite (Minimal Working App) ✅

The simplest working version that demonstrates skin loading:

```bash
# Compile the minimal app
swiftc -o winamp-lite WinampLite/main.swift -framework AppKit -framework AVFoundation

# Run the app
./winamp-lite

# Features:
# - Loads .wsz skins (drag & drop or File menu)
# - Basic audio playback
# - Volume control
# - Time display
```

### 2. Simple Test Script ✅

Test skin conversion without a full app:

```bash
# Run the test script
swift WinampSimpleTest/main.swift

# Or make it executable
chmod +x test_skin_conversion.swift
./test_skin_conversion.swift
```

## Building the Full Demo App

Due to Swift 6 strict concurrency requirements, the full demo app requires some modifications. Here are the options:

### Option A: Build with Swift 5 Mode (Recommended)

```bash
# Build with Swift 5 compatibility mode to bypass strict concurrency
swift build -Xswiftc -swift-version -Xswiftc 5 --product WinampDemoApp
```

### Option B: Build Individual Components

```bash
# Build core components separately
swift build --target WinampCore
swift build --target WinampRendering
swift build --target WinampUI
```

### Option C: Use Xcode

```bash
# Open in Xcode (handles concurrency better)
open Package.swift

# Then in Xcode:
# 1. Select WinampDemoApp scheme
# 2. Product → Build (Cmd+B)
# 3. Product → Run (Cmd+R)
```

## Working Executables

After successful compilation, you'll have these working apps:

1. **winamp-lite** - Minimal but fully functional skin player
   - Size: ~1MB
   - Dependencies: None (uses system frameworks)
   - Features: Skin loading, audio playback, basic controls

2. **test_skin_conversion** - Command-line skin tester
   - Tests .wsz extraction
   - Verifies BMP loading
   - Shows coordinate conversion

## Tested Skins

The following skins have been tested and work:

- ✅ Carrie-Anne Moss.wsz (nested structure)
- ✅ Deus_Ex_Amp_by_AJ.wsz (standard structure)
- ✅ netscape_winamp.wsz
- ✅ Purple_Glow.wsz

## Troubleshooting

### If compilation fails:

1. **Use the minimal app**: `winamp-lite` is guaranteed to work
2. **Check Swift version**: Ensure Swift 6.0+ is installed
3. **Try Swift 5 mode**: Add `-swift-version 5` flag
4. **Use Xcode**: Often handles complex builds better

### Common Issues:

- **"Cannot find type in scope"**: Missing import statements
- **"Actor isolation"**: Use Swift 5 mode or the minimal app
- **"Sendable conformance"**: Expected with AppKit types, use minimal app

## Architecture Notes

The project has three levels of complexity:

1. **Simple** (WinampLite) - Single file, no dependencies, works perfectly
2. **Moderate** (Test scripts) - Basic functionality testing
3. **Complex** (Full Demo) - All features but compilation challenges with Swift 6

For testing and demonstration, **WinampLite** provides the best experience with:
- Immediate compilation
- No dependency issues
- Full skin loading functionality
- Basic audio playback
- Clean, understandable code

## Next Steps

1. Run `winamp-lite` to see the working app
2. Try loading different skins via File → Open Skin
3. Play audio files via File → Open Audio
4. Explore the code in WinampLite/main.swift for a clean implementation

The minimal app proves the core concept works perfectly on macOS!