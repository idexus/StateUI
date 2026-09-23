// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// A StateUI colour is four sRGB channels, so AppKit draws it in sRGB with
/// exactly those channels. Any other colour space shifts every mid tone.
final class AppKitColorTests: XCTestCase {
    @MainActor
    func testAnAuthoredColorReachesAppKitInSRGB() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var box = HostPatch(id: .manual("box"), type: .colorBox)
        box.properties[.color] = .color(red: 128, green: 64, blue: 32, alpha: 255)
        renderer.applyForTesting(tree(box))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("box")) as? AppKitColorBoxView)
        assertSRGB(native.fillColor, red: 128, green: 64, blue: 32)
    }

    @MainActor
    func testABrushColorIsSRGBToo() throws {
        let color = try XCTUnwrap(nsColor(.color(red: 200, green: 100, blue: 50, alpha: 255)))
        assertSRGB(color, red: 200, green: 100, blue: 50)
    }

    private func assertSRGB(
        _ color: NSColor,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(color.colorSpace, .sRGB, file: file, line: line)
        XCTAssertEqual(color.redComponent, red / 255, accuracy: 0.0005, file: file, line: line)
        XCTAssertEqual(color.greenComponent, green / 255, accuracy: 0.0005, file: file, line: line)
        XCTAssertEqual(color.blueComponent, blue / 255, accuracy: 0.0005, file: file, line: line)
    }
}
#endif
