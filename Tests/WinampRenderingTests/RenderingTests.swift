import XCTest
@testable import WinampRendering

final class RenderingTests: XCTestCase {
    
    func testMetalDeviceAvailability() throws {
        // Test that Metal device is available
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal device not available")
            return
        }
        
        XCTAssertNotNil(device.name)
        print("Metal device: \(device.name)")
    }
    
    func testMetalRendererInitialization() throws {
        // Basic test to ensure MetalRenderer can be initialized
        do {
            let renderer = try MetalRenderer()
            XCTAssertNotNil(renderer)
        } catch {
            XCTFail("Failed to initialize MetalRenderer: \(error)")
        }
    }
}