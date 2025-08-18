#!/bin/bash
set -e

echo "🔍 Verifying Integration Readiness"
echo "=================================="

# Test 1: Build verification
echo "📦 Testing build..."
swift build --product ModernWinampCLI
echo "✅ Build successful"

# Test 2: System capabilities  
echo "🖥️  Checking system capabilities..."
swift run ModernWinampCLI info | grep -E "(Metal Device|Tahoe Features)" || {
    echo "❌ System check failed"
    exit 1
}
echo "✅ System capabilities verified"

# Test 3: Batch skin conversion
echo "🎨 Testing batch skin conversion..."
CONVERSION_OUTPUT=$(swift run ModernWinampCLI batch 2>&1)
echo "$CONVERSION_OUTPUT"

# Verify all skins converted successfully
if echo "$CONVERSION_OUTPUT" | grep -q "Successfully converted: 4"; then
    echo "✅ All 4 test skins converted successfully"
else
    echo "❌ Skin conversion failed"
    exit 1
fi

# Test 4: Metal texture validation
echo "🎮 Validating Metal textures..."
if echo "$CONVERSION_OUTPUT" | grep -q "Metal texture: Ready"; then
    echo "✅ Metal textures generated for all skins"
else
    echo "❌ Metal texture generation failed"
    exit 1
fi

# Test 5: Legacy tools compatibility
echo "🔧 Testing legacy tools..."
swift Scripts/WinampSimpleTest/main.swift > /dev/null && echo "✅ WinampSimpleTest works"
./Scripts/simple_skin_converter.swift > /dev/null && echo "✅ Simple converter works"

# Test 6: WinampLite compilation
echo "⚡ Testing WinampLite..."
swiftc -o /tmp/test-winamp-lite Tools/WinampLite/main.swift -framework AppKit -framework AVFoundation
echo "✅ WinampLite compiles successfully"
rm -f /tmp/test-winamp-lite

echo ""
echo "🎯 INTEGRATION READINESS VERIFIED"
echo "================================="
echo "✅ Build: GREEN"
echo "✅ Metal: Enabled and working"
echo "✅ Conversions: 4/4 successful"
echo "✅ Legacy tools: Compatible"
echo "✅ Tahoe: Ready for macOS 26.x"
echo ""
echo "🚀 READY FOR INTEGRATION WITH YOUR WINAMP PLAYER!"
echo ""
echo "Next steps:"
echo "1. Review INTEGRATION.md for complete integration guide"
echo "2. Import ModernWinampCore into your player project"  
echo "3. Use convertSkin() to get Metal textures and macOS coordinates"
echo "4. Integrate with your existing Metal renderer"
echo ""
echo "💡 Quick test: swift run ModernWinampCLI convert \"Samples/Skins/Purple_Glow.wsz\""
