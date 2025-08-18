#!/bin/bash
set -e

echo "🔨 Building Winamp Skin Converter Tools"
echo "========================================"

# Build the modern Swift package
echo "📦 Building modern CLI..."
swift build --product ModernWinampCLI
echo "✅ ModernWinampCLI built successfully"

# Build WinampLite
echo "🎵 Building WinampLite player..."
swiftc -o Tools/winamp-lite Tools/WinampLite/main.swift -framework AppKit -framework AVFoundation
echo "✅ WinampLite built successfully"

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x Scripts/simple_skin_converter.swift
chmod +x Scripts/WinampSimpleTest/main.swift
echo "✅ Scripts are executable"

echo ""
echo "🎯 All tools built successfully!"
echo ""
echo "Available tools:"
echo "1. swift run ModernWinampCLI test           # Modern Metal-enabled converter"
echo "2. ./Tools/winamp-lite                     # Minimal player demo"
echo "3. ./Scripts/simple_skin_converter.swift   # Standalone converter script"
echo "4. swift Scripts/WinampSimpleTest/main.swift  # Basic analysis tool"
echo ""
echo "💡 Test conversion: swift run ModernWinampCLI test"
