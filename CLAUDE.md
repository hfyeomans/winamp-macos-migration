# Claude Session Instructions - Winamp macOS Project

## 🎯 Project Context
This is the Winamp to macOS migration project that converts Windows .wsz skins to work natively on macOS using Metal rendering and modern Swift.

## 🔧 Development Best Practices

### Use Git Worktrees for Parallel Development
When working on multiple features or fixing different issues simultaneously:

```bash
# Create worktrees for parallel development
git worktree add ../winamp-feature-audio feature/audio-engine
git worktree add ../winamp-fix-rendering fix/metal-rendering
git worktree add ../winamp-experimental experimental/new-visualizations

# This allows multiple Claude sessions to work in parallel without conflicts
# Each worktree is an independent working directory with its own branch
```

Benefits of worktrees:
- Multiple Claude sessions can work simultaneously
- No branch switching needed
- Isolated experiments don't affect main codebase
- Easy to merge successful changes back to main

### Systems Thinking Approach
Apply these principles when working on this project:

1. **Consider the Whole System**
   - How does a change in one module affect others?
   - What are the upstream and downstream dependencies?
   - How does this impact performance across the entire app?

2. **Identify Feedback Loops**
   - User actions → Visual feedback → Audio response
   - Performance monitoring → Adaptive quality → User experience
   - Error states → Recovery mechanisms → System stability

3. **Understand Emergent Properties**
   - Skin rendering + Audio playback = Synchronized visualization
   - Multiple windows + Docking = Unified interface
   - Metal rendering + ProMotion = Smooth 120Hz experience

### Software Design Principles
Always apply these principles:

1. **SOLID Principles**
   - Single Responsibility: Each class does one thing well
   - Open/Closed: Open for extension, closed for modification
   - Liskov Substitution: Subtypes must be substitutable
   - Interface Segregation: Many specific interfaces over general ones
   - Dependency Inversion: Depend on abstractions, not concretions

2. **Clean Architecture**
   - Separate concerns into layers (UI, Business Logic, Data)
   - Dependencies point inward (UI → Logic → Data)
   - Core business logic has no external dependencies

3. **Swift-Specific Best Practices**
   - Use value types (structs) where possible
   - Leverage protocol-oriented programming
   - Apply proper actor isolation for concurrency
   - Handle optionals safely (no force unwrapping)
   - Use Result types for error handling

## 📚 Current Project State

### Working Components
- ✅ **WinampLite**: Minimal working app (single file, compilable)
- ✅ **Skin Conversion**: Windows .wsz → macOS conversion working
- ✅ **Metal Rendering**: GPU-accelerated skin display
- ✅ **Audio Playback**: Basic audio player with controls

### Known Issues
- ⚠️ Full demo app has Swift 6 concurrency compilation issues
- ⚠️ Some AppKit types don't conform to Sendable
- ⚠️ Complex module interdependencies need refactoring

### Build Commands
```bash
# Quick working build (recommended)
swiftc -o winamp-lite WinampLite/main.swift -framework AppKit -framework AVFoundation
./winamp-lite

# Test skin conversion
swift WinampSimpleTest/main.swift

# Full build (may have issues)
swift build --product WinampDemoApp

# Build with Swift 5 mode (bypasses strict concurrency)
swift build -Xswiftc -swift-version -Xswiftc 5 --product WinampDemoApp
```

## 🎨 Architecture Overview

```
Project Structure:
├── WinampLite/           # Minimal working app (recommended starting point)
├── WinampSimpleTest/     # Test scripts for skin conversion
├── WinampMac/           # Full app with all features
│   ├── Core/            # Business logic and skin conversion
│   ├── UI/              # User interface components
│   ├── Performance/     # ProMotion and optimization
│   └── App/             # Main application
└── Test Skins/          # .wsz files for testing
```

## 💡 Problem-Solving Approach

When encountering compilation errors:

1. **Start Simple**: Use WinampLite as the working baseline
2. **Isolate Issues**: Build modules independently
3. **Apply Patterns**: Use established Swift patterns for common issues
4. **Test Incrementally**: Verify each fix before moving on
5. **Document Solutions**: Update this file with successful approaches

## 🔄 Workflow Recommendations

### For New Features:
1. Create a git worktree for the feature
2. Start with WinampLite as the base
3. Add feature incrementally
4. Test with real .wsz skins
5. Merge back when stable

### For Bug Fixes:
1. Reproduce in WinampLite if possible
2. Fix in isolation
3. Test with multiple skins
4. Apply fix to main app if applicable

### For Performance Work:
1. Use Instruments for profiling
2. Test on both Intel and Apple Silicon
3. Verify ProMotion display support
4. Monitor memory usage

## 🎯 Key Goals
- Preserve authentic Winamp experience
- Leverage modern macOS capabilities
- Maintain clean, understandable code
- Ensure smooth performance on all Macs
- Support classic .wsz skins perfectly

## 📝 Remember
- The simple approach often works best
- WinampLite is the proof of concept that works
- Systems thinking helps understand complex interactions
- Git worktrees enable parallel development
- Document solutions for future sessions

---
*This file helps maintain consistency across Claude sessions on this project*