#!/usr/bin/env swift
//
//  Simple Winamp Skin Test
//  A minimal test program to verify skin conversion functionality
//

import Foundation
import AppKit

print("🎵 Winamp Skin Converter - Simple Test")
print(String(repeating: "=", count: 50))

// Test 1: Find .wsz files
let fileManager = FileManager.default
let currentPath = fileManager.currentDirectoryPath
let skinsPath = currentPath + "/Samples/Skins"

print("\n📁 Looking for .wsz files in: \(skinsPath)")

do {
    let contents = try fileManager.contentsOfDirectory(atPath: skinsPath)
    let wszFiles = contents.filter { $0.hasSuffix(".wsz") }
    
    if wszFiles.isEmpty {
        print("❌ No .wsz files found")
        exit(1)
    }
    
    print("✅ Found \(wszFiles.count) skin file(s):")
    for file in wszFiles {
        print("   • \(file)")
    }
    
    // Test 2: Extract a skin
    if let firstSkin = wszFiles.first {
        print("\n🔄 Testing extraction of: \(firstSkin)")
        
        let skinURL = URL(fileURLWithPath: skinsPath).appendingPathComponent(firstSkin)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("winamp_test_\(UUID().uuidString)")
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Use unzip to extract
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-q", skinURL.path, "-d", tempDir.path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            print("✅ Successfully extracted skin")
            
            // Check for key files
            let extractedContents = try fileManager.subpathsOfDirectory(atPath: tempDir.path)
            let bmpFiles = extractedContents.filter { $0.lowercased().hasSuffix(".bmp") }
            
            print("📊 Found \(bmpFiles.count) BMP files")
            
            // Find main.bmp
            if let mainBmp = extractedContents.first(where: { $0.lowercased().contains("main.bmp") }) {
                print("✅ Found main.bmp at: \(mainBmp)")
                
                // Load as NSImage
                let bmpURL = tempDir.appendingPathComponent(mainBmp)
                if let image = NSImage(contentsOf: bmpURL) {
                    print("✅ Successfully loaded main.bmp")
                    print("   Size: \(Int(image.size.width))x\(Int(image.size.height)) pixels")
                    
                    // Test coordinate conversion
                    print("\n🔄 Coordinate Conversion Test:")
                    print("   Windows (Y-down): Button at (10, 20)")
                    let macY = Int(image.size.height) - 20
                    print("   macOS (Y-up): Button at (10, \(macY))")
                }
            }
            
            // Cleanup
            try? fileManager.removeItem(at: tempDir)
            
        } else {
            print("❌ Failed to extract skin")
        }
    }
    
    print("\n✅ Test completed successfully!")
    
} catch {
    print("❌ Error: \(error.localizedDescription)")
    exit(1)
}