// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What a host moves frame by frame: the properties its views present and whose values travel, and nothing else.
final class TransitionSurfaceTests: XCTestCase {
    /// A colour box's colour, size and corners travel, as a view's opacity, a page's padding, a line's transform, a
    /// window's place and a title bar's colours do; a turn about a flat view's axis, a stepper's value, an indicator's
    /// opacity and a property no host knows arrive at once.
    func testTheSurfaceIsClosedAroundWhatAViewPresents() {
        for property: Prop in [.color, .width, .height, .cornerRadius] {
            XCTAssertTrue(TransitionSurface.presents(property, on: .colorBox), "\(property)")
        }
        XCTAssertTrue(TransitionSurface.presents(.opacity, on: .label))
        XCTAssertTrue(TransitionSurface.presents(.padding, on: .page))
        XCTAssertTrue(TransitionSurface.presents(.renderTransform, on: .line))
        XCTAssertTrue(TransitionSurface.presents(.x, on: .window))
        XCTAssertTrue(TransitionSurface.presents(.barBackgroundColor, on: .splitView))
        XCTAssertTrue(TransitionSurface.presents(.barForegroundColor, on: .modalStack))

        XCTAssertFalse(TransitionSurface.presents(.rotationX, on: .label))
        XCTAssertFalse(TransitionSurface.presents(.value, on: .stepper))
        XCTAssertFalse(TransitionSurface.presents(.opacity, on: .positionIndicator))
        XCTAssertFalse(TransitionSurface.presents(Prop("custom"), on: .label))
    }

    /// What a host's toolkit paints only at rest arrives at once on that host, and the rest of the surface travels.
    func testWhatAToolkitPaintsAtRestArrivesAtOnce() {
        let atRest: [NodeType: Set<Prop>] = [.label: [.padding, .background]]

        XCTAssertFalse(TransitionSurface.presents(.padding, on: .label, atRest: atRest))
        XCTAssertFalse(TransitionSurface.presents(.background, on: .label, atRest: atRest))
        XCTAssertTrue(TransitionSurface.presents(.textColor, on: .label, atRest: atRest))
        XCTAssertTrue(TransitionSurface.presents(.padding, on: .vStack, atRest: atRest))
    }
}
