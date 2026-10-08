// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
import XCTest

/// Glass keeps the tint its material gives it while its window stands inactive.
@MainActor
final class AppKitGlassViewTests: XCTestCase {
    /// macOS draws an inactive window's glass without its tint, never what the glass holds: there the tint stands in
    /// the glass's content.
    func testGlassInAnInactiveWindowKeepsItsTintInWhatItHolds() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered,
            defer: false)
        let glass = AppKitGlassView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        window.contentView?.addSubview(glass)
        let violet = NSColor(srgbRed: 0.13, green: 0.10, blue: 0.26, alpha: 0.7)
        glass.show(try XCTUnwrap(HostMaterial(Material.glass(.regular).propValue).glass), tint: violet)

        XCTAssertFalse(window.isKeyWindow || window.isMainWindow, "a window never shown stands inactive")
        XCTAssertNil(glass.tintColor, "the glass, which an inactive window draws untinted, holds none")
        XCTAssertEqual(glass.wash.layer?.backgroundColor, violet.cgColor, "what it holds wears the tint")
        XCTAssertFalse(glass.wash.isHidden)
    }
}
