// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

/// A view drawn faded: the whole of it, wherever what it holds stands.
final class AndroidOpacityTests: XCTestCase {
    static var allTests: [(String, (AndroidOpacityTests) -> () throws -> Void)] {
        [
            ("testAFadedLayoutDrawsAViewStandingPastItsBounds", testAFadedLayoutDrawsAViewStandingPastItsBounds),
        ]
    }

    /// A FADED LAYOUT DRAWS A VIEW STANDING PAST ITS BOUNDS: it fades as a whole, and a view a transition or a move
    /// carries past its edge fades with it - never cut where Android's own layer for a faded view ends, at the view's
    /// bounds. At two pixels a point: the box stands 40 high, the red view in it 60 to 100 down, at half its opacity.
    func testAFadedLayoutDrawsAViewStandingPastItsBounds() {
        onMainActor {
            let whole = Self.pastTheBox(at: 1)
            XCTAssertEqual(whole, 0xFFFF_0000, "whole, the view stands past the box: \(String(whole, radix: 16))")

            let faded = Self.pastTheBox(at: 0.5)
            let said = String(faded, radix: 16)
            XCTAssertTrue((0x7C...0x84).contains(faded >> 24), "faded, it is drawn there at half its opacity: \(said)")
            XCTAssertEqual((faded >> 16) & 0xFF, 0xFF, "red: \(said)")
        }
    }

    /// The pixel in the middle, 80 points down a box 40 high across the page, drawn at `opacity`, whose red view
    /// stands 60 to 100 down.
    @MainActor
    private static func pastTheBox(at opacity: Double) -> UInt32 {
        let host = AndroidRenderer.running {
            VStack {
                ZStack {
                    Rectangle()
                        .fill(Color(red: 255, green: 0, blue: 0))
                        .width(200)
                        .height(40)
                        .translationY(60)
                }
                .width(200)
                .height(40)
                .opacity(opacity)
            }
            .width(200)
            .height(200)
            .verticalAlignment(.start)
        }
        defer { host.finish() }
        host.layOut()
        return host.views(AndroidStackView.self).first?.pixels(at: [(200, 160)])[0] ?? 0
    }
}
