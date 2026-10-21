// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
@testable import StateUIWeb
import XCTest

/// An inset's sides as CSS is given them: a padding's side said is a length - nought included, over the padding a
/// control's style keeps - a margin's nought is none, every element's own margin being nought, and an inset not said
/// is none.
final class WebCSSSidesTests: XCTestCase {
    /// A PADDING OF NOUGHT IS A LENGTH: a button with no padding stands with none, not with its style's.
    func testAPaddingOfNoughtIsALength() {
        let sides = WebCSS.sides(Insets(start: 0, top: 0, end: 12, bottom: 0)).map(\.length)
        XCTAssertEqual(sides, ["0px", "0px", "12px", "0px"])
    }

    /// A MARGIN OF NOUGHT IS NONE, and one below nothing shifts its view.
    func testAMarginOfNoughtIsNone() {
        XCTAssertEqual(WebCSS.sides(Insets(start: -4, top: 0, end: 6, bottom: 0), margin: true).map(\.length),
                       ["-4px", nil, "6px", nil])
    }

    /// NO INSET SAYS NOTHING: each side none.
    func testNoInsetSaysNothing() {
        XCTAssertEqual(WebCSS.sides(nil).map(\.length), [nil, nil, nil, nil])
    }
}
