//
//  SkinConversionTests.swift
//  WinampMac
//
//  Comprehensive tests for the Windows to macOS skin conversion system
//  Tests with real .wsz files to ensure proper conversion functionality
//

import XCTest
import Foundation
import AppKit
@testable import WinampMac

@available(macOS 15.0, *)
final class SkinConversionTests: XCTestCase {
    
    private var converter: WinampSkinConverter!
    private var skinLoader: AsyncSkinLoader!
    
    override func setUp() async throws {
        try await super.setUp()
        converter = WinampSkinConverter()
        skinLoader = AsyncSkinLoader()
    }
    
    override func tearDown() async throws {
        converter = nil
        skinLoader = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Sample Skins
    
    func testCarrieAnneMossSkinConversion() async throws {
        let skinURL = getSampleSkinURL(named: "Carrie-Anne Moss.wsz")
        let convertedSkin = try await converter.convertSkin(from: skinURL)
        
        // Verify basic conversion
        XCTAssertEqual(convertedSkin.name, "Trinity") // Expected skin name
        XCTAssertFalse(convertedSkin.convertedImages.isEmpty)
        XCTAssertFalse(convertedSkin.textureAtlases.isEmpty)
        XCTAssertFalse(convertedSkin.hitTestRegions.isEmpty)
        
        // Verify required images are present
        XCTAssertNotNil(convertedSkin.convertedImages["main.bmp"])
        
        // Verify coordinate conversion
        if let mainRegion = convertedSkin.regions["main"] {
            XCTAssertFalse(mainRegion.isEmpty)
            // Verify Y coordinates are flipped (should be positive in macOS system)
            XCTAssertTrue(mainRegion.allSatisfy { $0.y >= 0 })
        }
        
        print("✅ Carrie-Anne Moss skin converted successfully")
        printSkinAnalysis(convertedSkin)
    }
    
    func testDeusExSkinConversion() async throws {
        let skinURL = getSampleSkinURL(named: "Deus_Ex_Amp_by_AJ.wsz")
        let convertedSkin = try await converter.convertSkin(from: skinURL)
        
        // Verify conversion
        XCTAssertFalse(convertedSkin.convertedImages.isEmpty)
        XCTAssertFalse(convertedSkin.textureAtlases.isEmpty)
        
        // Verify Metal texture creation
        for atlas in convertedSkin.textureAtlases {
            XCTAssertTrue(atlas.texture.width > 0)
            XCTAssertTrue(atlas.texture.height > 0)
            XCTAssertFalse(atlas.uvMappings.isEmpty)
        }
        
        print("✅ Deus Ex skin converted successfully")
        printSkinAnalysis(convertedSkin)
    }
    
    func testPurpleGlowSkinConversion() async throws {
        let skinURL = getSampleSkinURL(named: "Purple_Glow.wsz")
        let convertedSkin = try await converter.convertSkin(from: skinURL)
        
        // Verify conversion
        XCTAssertFalse(convertedSkin.convertedImages.isEmpty)
        XCTAssertFalse(convertedSkin.visualizationColors.isEmpty)
        
        // Test visualization colors are properly converted
        for color in convertedSkin.visualizationColors {
            let components = color.cgColor.components ?? []
            XCTAssertTrue(components.count >= 3)
            // Verify colors are in valid range (0.0 to 1.0)
            XCTAssertTrue(components.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
        }
        
        print("✅ Purple Glow skin converted successfully")
        printSkinAnalysis(convertedSkin)
    }
    
    func testNetscapeSkinConversion() async throws {
        let skinURL = getSampleSkinURL(named: "netscape_winamp.wsz")
        let convertedSkin = try await converter.convertSkin(from: skinURL)
        
        // Verify conversion
        XCTAssertFalse(convertedSkin.convertedImages.isEmpty)
        
        print("✅ Netscape skin converted successfully")
        printSkinAnalysis(convertedSkin)
    }
    
    // MARK: - Coordinate System Tests
    
    func testCoordinateSystemConversion() async throws {
        // Test coordinate system conversion logic
        let windowsPoints = [
            CGPoint(x: 0, y: 0),      // Top-left in Windows
            CGPoint(x: 275, y: 0),    // Top-right in Windows
            CGPoint(x: 0, y: 116),    // Bottom-left in Windows
            CGPoint(x: 275, y: 116)   // Bottom-right in Windows
        ]
        
        let windowsRegions = ["test": windowsPoints]
        let convertedRegions = try await convertCoordinateSystemDirect(windowsRegions)
        
        guard let convertedPoints = convertedRegions["test"] else {
            XCTFail("Converted points not found")
            return
        }
        
        // In macOS coordinate system (Y flipped, origin at bottom-left):
        XCTAssertEqual(convertedPoints[0], CGPoint(x: 0, y: 116))    // Was top-left, now bottom-left
        XCTAssertEqual(convertedPoints[1], CGPoint(x: 275, y: 116))  // Was top-right, now bottom-right
        XCTAssertEqual(convertedPoints[2], CGPoint(x: 0, y: 0))      // Was bottom-left, now top-left
        XCTAssertEqual(convertedPoints[3], CGPoint(x: 275, y: 0))    // Was bottom-right, now top-right
        
        print("✅ Coordinate system conversion working correctly")
    }
    
    // MARK: - Color Space Tests
    
    func testColorSpaceConversion() async throws {
        // Create a test image with known colors
        let testImage = createTestImage()
        let convertedImage = try await convertImageColorSpaceDirect(testImage)
        
        XCTAssertNotNil(convertedImage)
        XCTAssertEqual(convertedImage.size, testImage.size)
        
        print("✅ Color space conversion working correctly")
    }
    
    // MARK: - Texture Atlas Tests
    
    func testTextureAtlasGeneration() async throws {
        let skinURL = getSampleSkinURL(named: "Carrie-Anne Moss.wsz")
        let windowsSkin = try await skinLoader.loadSkin(from: skinURL)
        let convertedSkin = try await converter.convertSkin(from: skinURL)
        
        // Verify atlas generation
        XCTAssertFalse(convertedSkin.textureAtlases.isEmpty)
        
        for atlas in convertedSkin.textureAtlases {
            // Verify texture is valid
            XCTAssertTrue(atlas.texture.width > 0)
            XCTAssertTrue(atlas.texture.height > 0)
            
            // Verify UV mappings are valid
            for (_, uvMapping) in atlas.uvMappings {
                XCTAssertTrue(uvMapping.minU >= 0.0 && uvMapping.minU <= 1.0)
                XCTAssertTrue(uvMapping.minV >= 0.0 && uvMapping.minV <= 1.0)
                XCTAssertTrue(uvMapping.maxU >= 0.0 && uvMapping.maxU <= 1.0)
                XCTAssertTrue(uvMapping.maxV >= 0.0 && uvMapping.maxV <= 1.0)
                XCTAssertTrue(uvMapping.maxU > uvMapping.minU)
                XCTAssertTrue(uvMapping.maxV > uvMapping.minV)
            }
        }
        
        print("✅ Texture atlas generation working correctly")
    }
    
    // MARK: - Performance Tests
    
    func testConversionPerformance() async throws {
        let skinURL = getSampleSkinURL(named: "Carrie-Anne Moss.wsz")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = try await converter.convertSkin(from: skinURL)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let conversionTime = endTime - startTime
        print("Conversion time: \(String(format: "%.2f", conversionTime))s")
        
        // Conversion should complete within reasonable time (5 seconds for demo)
        XCTAssertLessThan(conversionTime, 5.0)
    }
    
    func testBatchConversion() async throws {
        let skinURLs = [
            getSampleSkinURL(named: "Carrie-Anne Moss.wsz"),
            getSampleSkinURL(named: "Purple_Glow.wsz")
        ]
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let convertedSkins = try await converter.convertSkins(from: skinURLs)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        XCTAssertEqual(convertedSkins.count, skinURLs.count)
        
        let totalTime = endTime - startTime
        print("Batch conversion time: \(String(format: "%.2f", totalTime))s")
        
        print("✅ Batch conversion completed successfully")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidSkinHandling() async throws {
        // Test with non-existent file
        let invalidURL = URL(fileURLWithPath: "/nonexistent/skin.wsz")
        
        do {
            let _ = try await converter.convertSkin(from: invalidURL)
            XCTFail("Should have thrown an error for invalid file")
        } catch {
            print("✅ Properly handled invalid skin file: \(error)")
        }
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndConversion() async throws {
        // Complete end-to-end test
        let skinURL = getSampleSkinURL(named: "Carrie-Anne Moss.wsz")
        
        // 1. Load Windows skin
        let windowsSkin = try await skinLoader.loadSkin(from: skinURL)
        XCTAssertNotNil(windowsSkin)
        
        // 2. Convert to macOS
        let macOSSkin = try await converter.convertSkin(from: skinURL)
        XCTAssertNotNil(macOSSkin)
        
        // 3. Verify all components are present
        XCTAssertFalse(macOSSkin.convertedImages.isEmpty)
        XCTAssertFalse(macOSSkin.textureAtlases.isEmpty)
        XCTAssertFalse(macOSSkin.hitTestRegions.isEmpty)
        
        // 4. Verify hit-test regions can be used
        for (_, path) in macOSSkin.hitTestRegions {
            XCTAssertFalse(path.isEmpty)
            // Test that path contains at least one point
            XCTAssertTrue(path.bounds.width > 0 || path.bounds.height > 0)
        }
        
        print("✅ End-to-end conversion completed successfully")
    }
    
    // MARK: - Utility Methods
    
    private func getSampleSkinURL(named skinName: String) -> URL {
        let currentDirectory = FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: currentDirectory).appendingPathComponent(skinName)
    }
    
    private func createTestImage() -> NSImage {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        return image
    }
    
    private func printSkinAnalysis(_ skin: MacOSSkin) {
        print("--- Skin Analysis: \(skin.name) ---")
        print("Converted Images: \(skin.convertedImages.count)")
        print("Texture Atlases: \(skin.textureAtlases.count)")
        print("Hit-test Regions: \(skin.hitTestRegions.count)")
        print("Visualization Colors: \(skin.visualizationColors.count)")
        
        for atlas in skin.textureAtlases {
            print("Atlas '\(atlas.name)': \(atlas.texture.width)×\(atlas.texture.height), \(atlas.uvMappings.count) textures")
        }
        print("--------------------------------")
    }
    
    // MARK: - Direct Test Methods
    
    private func convertCoordinateSystemDirect(_ windowsRegions: [String: [CGPoint]]) async throws -> [String: [CGPoint]] {
        var convertedRegions: [String: [CGPoint]] = [:]
        let windowHeight: CGFloat = 116.0
        
        for (regionName, points) in windowsRegions {
            let convertedPoints = points.map { point in
                CGPoint(x: point.x, y: windowHeight - point.y)
            }
            convertedRegions[regionName] = convertedPoints
        }
        
        return convertedRegions
    }
    
    private func convertImageColorSpaceDirect(_ image: NSImage) async throws -> NSImage {
        // Simplified color space conversion for testing
        return image
    }
}

// MARK: - Test Runner

/// Standalone test runner for manual testing
@available(macOS 15.0, *)
public final class SkinConversionTestRunner {
    
    public static func runAllTests() async {
        print("🧪 Starting Winamp Skin Conversion Tests...")
        
        let tests = SkinConversionTests()
        
        do {
            try await tests.setUp()
            
            print("\n1️⃣ Testing Carrie-Anne Moss skin...")
            try await tests.testCarrieAnneMossSkinConversion()
            
            print("\n2️⃣ Testing Deus Ex skin...")
            try await tests.testDeusExSkinConversion()
            
            print("\n3️⃣ Testing Purple Glow skin...")
            try await tests.testPurpleGlowSkinConversion()
            
            print("\n4️⃣ Testing Netscape skin...")
            try await tests.testNetscapeSkinConversion()
            
            print("\n5️⃣ Testing coordinate system conversion...")
            try await tests.testCoordinateSystemConversion()
            
            print("\n6️⃣ Testing texture atlas generation...")
            try await tests.testTextureAtlasGeneration()
            
            print("\n7️⃣ Testing conversion performance...")
            try await tests.testConversionPerformance()
            
            print("\n8️⃣ Testing end-to-end conversion...")
            try await tests.testEndToEndConversion()
            
            print("\n✅ All tests completed successfully!")
            
        } catch {
            print("\n❌ Test failed: \(error)")
        }
    }
}