// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The library's composed views - a list, a gallery, a motion layout, position dots - take their own modifiers and
// every view's in any order, as a control does.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class LibraryViewModifierTests: XCTestCase {
    /// A LIBRARY VIEW TAKES ITS OWN MODIFIERS AFTER EVERY VIEW'S: one view either way, what every view's modifier
    /// wrote standing on its placeholder.
    func testALibraryViewTakesItsOwnModifiersAfterEveryViews() {
        let chosen = State<Int?>(wrappedValue: nil)
        let turn = State(wrappedValue: 0.0)
        let shown = State(wrappedValue: 0)

        let lists = [
            ItemsView([1, 2]) { Text("\($0)") }.margin(8).selection(chosen.projectedValue).node,
            ItemsView([1, 2]) { Text("\($0)") }.selection(chosen.projectedValue).margin(8).node,
        ]
        let galleries = [
            GalleryView([1, 2], id: \.self) { Text("\($0)") }.margin(8).position(shown.projectedValue).node,
            GalleryView([1, 2], id: \.self) { Text("\($0)") }.position(shown.projectedValue).margin(8).node,
        ]
        let layouts = [
            MotionLayout([1], parameters: turn.projectedValue) { Text("\($0)") } placements: { _, _ in [] }
                .height(200).parameterMotion(.none).node,
            MotionLayout([1], parameters: turn.projectedValue) { Text("\($0)") } placements: { _, _ in [] }
                .parameterMotion(.none).height(200).node,
        ]
        let dots = [
            PositionDots().opacity(0.5).dotColor(.red).node,
            PositionDots().dotColor(.red).opacity(0.5).node,
        ]

        for (made, property) in [(lists, ViewContract.margin.token), (galleries, ViewContract.margin.token),
                                 (layouts, VisualElementContract.height.token),
                                 (dots, VisualElementContract.opacity.token)] {
            XCTAssertNotNil(made[0].props[property], "written on the placeholder")
            XCTAssertEqual(made[0].props, made[1].props, "the same, whichever came first")
            XCTAssertNotNil(made[0].stateful, "a placeholder for the body")
        }
    }

    /// WHAT IS WRITTEN ON A LIBRARY VIEW IS NO INPUT OF ITS BODY: a margin, a handler - the differ's to say again,
    /// never a reason to build the body anew.
    func testWhatIsWrittenOnALibraryViewIsNoInputOfItsBody() {
        let plain = PositionDots().count(3)

        let written = plain.margin(8).opacity(0.5).onTapped {}

        XCTAssertEqual(stateParts(in: written).inputs.count, stateParts(in: plain).inputs.count)
    }
}
