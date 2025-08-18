# Build Instructions for Winamp Skin Converter

## ✅ CURRENT STATUS: ALL TOOLS WORKING

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
```

### 3. Skin Converter CLI ✅

Swift package-based converter:

```bash
# Build the package
swift build

# Test conversion
swift run WinampSkinCLI test

# Convert specific skin
swift run WinampSkinCLI convert "Purple_Glow.wsz"

# Batch convert all skins
swift run WinampSkinCLI batch
```

### 4. Standalone Converter Script ✅

Direct script for quick conversion:

```bash
# Make executable and run
chmod +x simple_skin_converter.swift
./simple_skin_converter.swift
```

## Advanced Components (Archived)

The full demo app with Metal rendering and complex UI has been temporarily archived due to Swift 6 strict concurrency complexity.

### Current State: ARCHIVED
- Complex SwiftUI app: Moved to `/Archive/`
- Metal rendering pipeline: Preserved for future
- Advanced visualization: Documented but not built

### To Access Archived Code
```bash
# View archived implementation
git checkout archive/2025-08-17
# Contains full complex implementation for future reference
```

### Integration Path
The working converters provide the foundation needed for integration:
1. Use `WinampSkinConverter` to convert skins
2. Extract `ConvertedSkin.originalImage` for your player
3. Use `ConvertedSkin.convertedRegions` for button mapping
4. Apply coordinate transformation for hit-testing

## Working Executables

After successful compilation, you'll have these working tools:

1. **winamp-lite** - Minimal player demo (150 lines, single file)
   - Size: ~200KB compiled
   - Dependencies: AppKit, AVFoundation only  
   - Features: Skin loading, audio playback, drag & drop

2. **WinampSkinCLI** - Package-based converter
   - Command: `swift run WinampSkinCLI`
   - Features: Batch conversion, testing, individual files

3. **simple_skin_converter.swift** - Standalone script  
   - Direct execution: `./simple_skin_converter.swift`
   - Features: Basic conversion with detailed output

4. **WinampSimpleTest** - Analysis tool
   - Command: `swift WinampSimpleTest/main.swift`
   - Features: Extraction testing, coordinate validation

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