// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import UIKit
import XCTest

/// A layout that cuts what it shows to its shape takes a touch only within that shape: a corner the cut leaves bare
/// reaches nothing of it.
@MainActor
final class UIKitBoxTests: XCTestCase {
    func testATouchOutsideAnOvalCutReachesNothingOfIt() throws {
        let host = UIKitRenderer.running {
            VStack {
                ZStack { ColorBox(.red).onTapped {} }
                    .width(100)
                    .height(100)
                    .shape(.ellipse)
                    .clipsContent(true)
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        let layout = try XCTUnwrap(host.views(UIKitZStackView.self).first)
        let window = try XCTUnwrap(layout.window)
        func reaches(_ point: CGPoint) -> Bool {
            window.hitTest(layout.convert(point, to: window), with: nil)?.isDescendant(of: layout) ?? false
        }

        XCTAssertFalse(reaches(CGPoint(x: 3, y: 3)), "a corner the oval leaves bare")
        XCTAssertTrue(reaches(CGPoint(x: 50, y: 50)), "within the oval")
    }
}
