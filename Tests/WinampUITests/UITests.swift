import XCTest
@testable import WinampUI

final class UITests: XCTestCase {
    
    func testWindowManagerInitialization() throws {
        let windowManager = WinampWindowManager.shared
        XCTAssertNotNil(windowManager)
        XCTAssertEqual(windowManager.windows.count, 0)
    }
    
    func testWinampWindowCreation() throws {
        let contentRect = NSRect(x: 100, y: 100, width: 275, height: 116)
        let window = WinampWindow(contentRect: contentRect, styleMask: [], backing: .buffered, defer: false)
        
        XCTAssertNotNil(window)
        XCTAssertEqual(window.frame.size.width, 275)
        XCTAssertEqual(window.frame.size.height, 116)
    }
}