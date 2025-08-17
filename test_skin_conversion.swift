#!/usr/bin/env swift

import Foundation
import AppKit
import UniformTypeIdentifiers

// Simple test script to demonstrate skin conversion
print("🎵 Winamp Skin Converter Test")
print(String(repeating: "=", count: 50))

// Find .wsz files in current directory
let fileManager = FileManager.default
let currentPath = fileManager.currentDirectoryPath
print("📁 Searching for .wsz files in: \(currentPath)")

do {
    let contents = try fileManager.contentsOfDirectory(atPath: currentPath)
    let wszFiles = contents.filter { $0.hasSuffix(".wsz") }
    
    guard !wszFiles.isEmpty else {
        print("❌ No .wsz files found in current directory")
        exit(1)
    }
    
    print("✅ Found \(wszFiles.count) skin file(s):")
    for (index, file) in wszFiles.enumerated() {
        print("  \(index + 1). \(file)")
    }
    
    // Test with the first skin file
    let testSkin = wszFiles[0]
    print("\n🔄 Testing conversion with: \(testSkin)")
    
    // Check if it's a valid ZIP file
    let skinURL = URL(fileURLWithPath: currentPath).appendingPathComponent(testSkin)
    let skinData = try Data(contentsOf: skinURL)
    
    // Check ZIP signature (50 4B = "PK")
    let signature = skinData.prefix(2)
    if signature[0] == 0x50 && signature[1] == 0x4B {
        print("✅ Valid ZIP archive detected")
    } else {
        print("⚠️  File may not be a valid ZIP archive")
    }
    
    // Create temporary directory for extraction
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("winamp_skin_\(UUID().uuidString)")
    try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
    print("📂 Created temp directory: \(tempDir.lastPathComponent)")
    
    // Extract using unzip command (simple approach for testing)
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    task.arguments = ["-q", skinURL.path, "-d", tempDir.path]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    try task.run()
    task.waitUntilExit()
    
    if task.terminationStatus == 0 {
        print("✅ Successfully extracted skin archive")
        
        // List extracted files
        let extractedFiles = try fileManager.contentsOfDirectory(atPath: tempDir.path)
        print("📋 Extracted \(extractedFiles.count) files:")
        
        // Categorize files
        var images: [String] = []
        var configs: [String] = []
        var others: [String] = []
        
        for file in extractedFiles {
            let lowercased = file.lowercased()
            if lowercased.hasSuffix(".bmp") || lowercased.hasSuffix(".png") || lowercased.hasSuffix(".jpg") {
                images.append(file)
            } else if lowercased.hasSuffix(".txt") || lowercased.hasSuffix(".ini") {
                configs.append(file)
            } else {
                others.append(file)
            }
        }
        
        print("  🎨 Images: \(images.count) files")
        if !images.isEmpty {
            print("     - \(images.prefix(5).joined(separator: ", "))\(images.count > 5 ? ", ..." : "")")
        }
        
        print("  ⚙️  Config: \(configs.count) files")
        if !configs.isEmpty {
            print("     - \(configs.joined(separator: ", "))")
        }
        
        print("  📄 Other: \(others.count) files")
        
        // Check for key Winamp skin files
        let keyFiles = ["main.bmp", "pledit.bmp", "eqmain.bmp", "cbuttons.bmp", "titlebar.bmp"]
        let foundKeyFiles = keyFiles.filter { file in
            extractedFiles.contains { $0.lowercased() == file }
        }
        
        print("\n🔍 Key Winamp skin components found:")
        for keyFile in foundKeyFiles {
            print("  ✅ \(keyFile)")
        }
        
        let missingKeyFiles = keyFiles.filter { file in
            !extractedFiles.contains { $0.lowercased() == file }
        }
        
        if !missingKeyFiles.isEmpty {
            print("  ⚠️  Missing: \(missingKeyFiles.joined(separator: ", "))")
        }
        
        // Check for configuration files
        if extractedFiles.contains(where: { $0.lowercased() == "region.txt" }) {
            print("\n📐 Region mapping file found (for non-rectangular windows)")
        }
        
        if extractedFiles.contains(where: { $0.lowercased() == "viscolor.txt" }) {
            print("🎨 Visualization colors file found")
        }
        
        if extractedFiles.contains(where: { $0.lowercased() == "pledit.txt" }) {
            print("📝 Playlist editor colors file found")
        }
        
        // Test loading a BMP file
        if let mainBMP = extractedFiles.first(where: { $0.lowercased() == "main.bmp" }) {
            let bmpURL = tempDir.appendingPathComponent(mainBMP)
            if let image = NSImage(contentsOf: bmpURL) {
                print("\n✅ Successfully loaded main.bmp:")
                print("  📐 Size: \(Int(image.size.width))x\(Int(image.size.height)) pixels")
                
                // Simulate coordinate conversion
                print("\n🔄 Simulating Windows → macOS coordinate conversion:")
                print("  Windows (Y-down): Button at (10, 20)")
                let macY = Int(image.size.height) - 20
                print("  macOS (Y-up): Button at (10, \(macY))")
            }
        }
        
        print("\n✨ Skin analysis complete!")
        print("This skin is ready for conversion to macOS format.")
        
        // Cleanup
        try? fileManager.removeItem(at: tempDir)
        
    } else {
        print("❌ Failed to extract skin archive")
    }
    
} catch {
    print("❌ Error: \(error.localizedDescription)")
}

print("\n" + String(repeating: "=", count: 50))
print("💡 Next steps:")
print("1. Load extracted assets into Metal textures")
print("2. Parse configuration files for layout")
print("3. Generate NSBezierPath for window shapes")
print("4. Create hit-test regions for buttons")
print("5. Apply skin to Winamp interface")