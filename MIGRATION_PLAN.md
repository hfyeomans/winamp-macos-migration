# Winamp Classic Skins to macOS Migration Plan

## Executive Summary

This document outlines the comprehensive strategy for migrating classic Winamp skins to a native macOS application, preserving the nostalgic experience while leveraging modern macOS capabilities.

### Reference Implementation
- **WebAmp Project**: https://github.com/captbaritone/webamp
- **Winamp Skin Museum**: https://skins.webamp.org
- **Target Platform**: macOS (native, not iOS)

## Phase 1: Foundation (Days 1-2)

### 1.1 Core Architecture Setup

**Technology Stack:**
- **UI Framework**: Hybrid AppKit (primary) + SwiftUI (modern components)
- **Rendering**: Metal for sprite-based UI and visualizations
- **Audio**: AVFoundation with Core Audio for advanced features
- **Language**: Swift 5.9+

**Project Structure:**
```
WinampMac/
├── Core/
│   ├── SkinEngine/     # .wsz parsing, sprite management
│   ├── AudioEngine/    # Playback, EQ, format support
│   └── WindowManager/  # Docking, snapping, multi-window
├── UI/
│   ├── MainPlayer/     # Primary player window
│   ├── Playlist/       # Playlist window
│   ├── Equalizer/      # EQ window
│   └── Visualizer/     # Spectrum analyzer
└── Resources/
    └── DefaultSkin/    # Fallback classic skin
```

### 1.2 Skin Loading System

**Implementation Priority:**
1. ZIP extraction for .wsz files
2. Sprite sheet parsing (BMP/PNG)
3. Configuration file parsing (viscolor.txt, pledit.txt)
4. Cursor file conversion (.cur → NSCursor)

**Key Components:**
```swift
class SkinLoader {
    - Parse .wsz (ZIP) archives
    - Extract and cache sprite assets
    - Load configuration files
    - Convert Windows cursors to macOS
}
```

## Phase 2: Visual Fidelity (Days 3-4)

### 2.1 Sprite Rendering System

**Metal-based Implementation:**
- Sprite batching for performance
- Nearest-neighbor scaling for pixel art
- Integer scaling (1x, 2x, 3x) for Retina displays
- Custom window shapes with alpha transparency

**Sprite Components:**
- main.bmp - Main player window
- eqmain.bmp - Equalizer
- pledit.bmp - Playlist editor
- cbuttons.bmp - Control buttons
- numbers.bmp - Time display
- titlebar.bmp - Window chrome

### 2.2 Window Management

**Unique Winamp Behaviors:**
- **Docking System**: 8-pixel magnetic snap zones
- **Shaded Mode**: Collapse to title bar (150ms animation)
- **Window Clustering**: Move docked windows as group
- **Non-rectangular Windows**: Custom shapes per skin

**macOS Integration:**
- Mission Control compatibility
- Spaces support
- Dock integration
- Native menu bar

## Phase 3: Audio & Interaction (Days 5-6)

### 3.1 Audio Engine

**Format Support:**
- MP3, AAC, FLAC, WAV, ALAC (native)
- OGG Vorbis (custom decoder)
- Gapless playback
- 10-band equalizer

**Visualization System:**
- FFT-based spectrum analyzer
- 75-bar classic layout
- Skin-specific color schemes (viscolor.txt)
- 60fps rendering via Metal

### 3.2 User Interaction

**Authentic Behaviors:**
- Pixel-perfect button states
- Custom cursor per UI region
- Drag anywhere (not just title bar)
- Window snapping/docking

**Modern Enhancements:**
- Keyboard shortcuts (Cmd-based)
- Media key support
- Touch Bar integration
- Accessibility layer

## User Experience Strategy

### Core Principles

1. **Nostalgia First**: Preserve authentic Winamp feel
2. **macOS Native**: Respect platform conventions
3. **Performance**: 60fps animations, <2s skin loading
4. **Accessibility**: Full VoiceOver support

### Target User Personas

1. **Nostalgic Professional (35-45)**: Wants authentic experience with modern performance
2. **Retro Enthusiast (25-35)**: Values customization and Y2K aesthetics
3. **Audio Purist (30-50)**: Needs powerful EQ and gapless playback
4. **Developer/Power User (25-40)**: Wants to create/modify skins

### Key Interactions

**Window Docking:**
- Magnetic edges with visual feedback
- Remembered configurations
- Multi-window group movement

**Shaded Mode:**
- Double-click or gesture toggle
- Essential controls remain visible
- Smooth 200ms transition

**Skin Switching:**
- Drag-and-drop .wsz files
- Live preview before apply
- <2 second load time

## Technical Implementation Details

### Memory Management
```swift
- NSCache for textures (100MB limit)
- Lazy loading of skin assets
- Automatic cache clearing on memory pressure
- Maximum 5 skins cached simultaneously
```

### Performance Optimization
```swift
- Metal sprite batching (1000+ sprites/frame)
- Hardware-accelerated rendering
- Efficient FFT via Accelerate framework
- Background audio processing
```

### Skin Compatibility
```swift
- Support original .wsz format
- Parse INI-style configuration
- Handle missing assets gracefully
- Fallback to default skin elements
```

## Testing Strategy

### Unit Tests
- Skin loading and parsing
- Audio format support
- Window docking logic
- Visualization calculations

### UI Tests
- Window snapping behavior
- Skin switching workflow
- Playlist management
- EQ adjustments

### Performance Tests
- Sprite rendering at 60fps
- Audio playback smoothness
- Skin loading times
- Memory usage under load

### Compatibility Tests
- Various skin formats
- Different audio codecs
- Multiple display configurations
- macOS version compatibility

## Development Workflow

### Sprint 1 (Days 1-2): Foundation
- [ ] Initialize project structure
- [ ] Implement .wsz parser
- [ ] Create basic window system
- [ ] Setup Metal rendering pipeline

### Sprint 2 (Days 3-4): Visual System
- [ ] Sprite sheet rendering
- [ ] Window docking/snapping
- [ ] Shaded mode implementation
- [ ] Cursor system

### Sprint 3 (Days 5-6): Audio & Polish
- [ ] Audio engine integration
- [ ] Visualization system
- [ ] Skin switching UI
- [ ] Performance optimization

## Success Metrics

- **Nostalgia Score**: 90%+ recognition of authentic Winamp
- **Performance**: Consistent 60fps rendering
- **Load Time**: <2 seconds for skin switching
- **Compatibility**: Support 95%+ of classic skins
- **Accessibility**: Full VoiceOver navigation

## Risk Mitigation

### Technical Risks
- **Cursor limitations**: Fallback to system cursors
- **Performance issues**: Progressive enhancement approach
- **Skin compatibility**: Robust error handling and fallbacks

### User Experience Risks
- **Platform confusion**: Clear macOS integration points
- **Learning curve**: Progressive disclosure of features
- **Accessibility gaps**: Parallel semantic interface

## Next Steps

1. Initialize git repository
2. Create Xcode project with structure
3. Implement basic .wsz parser
4. Create proof-of-concept sprite renderer
5. Test with sample skins

## References

- WebAmp Implementation: https://github.com/captbaritone/webamp
- Winamp Skin Museum: https://skins.webamp.org
- Classic Skin Specifications: [Internal documentation]
- macOS HIG: https://developer.apple.com/design/human-interface-guidelines/