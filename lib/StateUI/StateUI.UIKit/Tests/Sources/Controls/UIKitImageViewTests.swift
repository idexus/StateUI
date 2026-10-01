// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A picture is read from the application's images and measured in points.
final class UIKitImageViewTests: XCTestCase {
    /// An SVG of 40 by 20 points, drawn three times over; a PNG of 6 by 4 pixels kept at a pixel a point; a name
    /// with no picture, which takes no room.
    @MainActor
    func testAPictureIsMeasuredAtItsOwnSizeInPoints() {
        let host = UIKitRenderer.running {
            VStack {
                Image("test_wide.png").horizontalAlignment(.start)
                Image("test_dot.png").horizontalAlignment(.start)
                Image("nowhere.png").horizontalAlignment(.start)
            }
        }
        defer { host.finish() }

        let images = host.views(UIKitImageView.self)
        XCTAssertEqual(images.count, 3)
        XCTAssertEqual(images.map(\.frame), [
            CGRect(x: 0, y: 0, width: 40, height: 20), CGRect(x: 0, y: 20, width: 6, height: 4),
            CGRect(x: 0, y: 24, width: 0, height: 0),
        ])
        XCTAssertEqual(images[0].image?.scale, 3, "the SVG's drawing, three pixels a point")
    }
}
