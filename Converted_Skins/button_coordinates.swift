// Button Coordinate Mapping for Purple_Glow skin
// Converted from Windows Y-down to macOS Y-up coordinate system
// Window Height: 87

// Swift code for integration:
let buttonPositions: [String: CGPoint] = [
    "play": CGPoint(x: 24, y: 59),
    "pause": CGPoint(x: 39, y: 59),
    "stop": CGPoint(x: 54, y: 59),
    "prev": CGPoint(x: 6, y: 59),
    "next": CGPoint(x: 69, y: 59),
    "eject": CGPoint(x: 84, y: 59)
]

// Usage in your WinampClone:
// 1. Load purple_glow_converted.png as background
// 2. Position buttons using the coordinates above
// 3. Set window size to 206×87