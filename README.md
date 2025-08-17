# WinampMac - Classic Winamp Skins for macOS

A native macOS application that brings the nostalgic Winamp experience to Mac, complete with classic skin support.

## Features

- **Authentic Skin Support**: Load and render classic Winamp .wsz skin files
- **Pixel-Perfect Rendering**: Maintains the original aesthetic with Retina display support
- **Window Docking**: Classic Winamp window snapping and docking behavior
- **Audio Formats**: MP3, FLAC, AAC, WAV, and more
- **Visualizations**: Classic spectrum analyzer with skin-specific colors
- **macOS Integration**: Native performance with modern macOS features

## Project Structure

```
WinampMac/
├── Core/           # Core functionality
├── UI/             # User interface components
├── Resources/      # Assets and default skins
└── Tests/          # Unit and UI tests
```

## Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository
2. Open `WinampMac.xcodeproj` in Xcode
3. Build and run

## Skin Compatibility

Supports classic Winamp 2.x skins (.wsz files). Place skin files in the application's Skins directory or drag-and-drop onto the main window.

## Development

See [MIGRATION_PLAN.md](MIGRATION_PLAN.md) for the complete development strategy and technical implementation details.

## References

- [WebAmp Project](https://github.com/captbaritone/webamp)
- [Winamp Skin Museum](https://skins.webamp.org)

## License

TBD

## Acknowledgments

- Original Winamp by Nullsoft
- WebAmp project for implementation reference
- Winamp Skin Museum for preservation efforts