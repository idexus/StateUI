// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// The Web host moves frame by frame what its views present, and nothing else.
@MainActor
final class WebTransitionSurfaceTests: XCTestCase {
    func testTheTransitionSurfaceIsClosedAroundWhatTheHostPresents() {
        XCTAssertTrue(WebTransitionSurface.presents(.color, on: .colorBox))
        XCTAssertTrue(WebTransitionSurface.presents(.width, on: .colorBox))
        XCTAssertTrue(WebTransitionSurface.presents(.cornerRadius, on: .colorBox))
        XCTAssertTrue(WebTransitionSurface.presents(.opacity, on: .text))
        XCTAssertTrue(WebTransitionSurface.presents(.translationX, on: .button))
        XCTAssertTrue(WebTransitionSurface.presents(.value, on: .slider))
        XCTAssertTrue(WebTransitionSurface.presents(.spacing, on: .vStack))
        XCTAssertFalse(WebTransitionSurface.presents(.value, on: .text))
        XCTAssertFalse(WebTransitionSurface.presents(.width, on: .window), "the browser keeps its window")
        XCTAssertFalse(WebTransitionSurface.presents(Prop("custom"), on: .text))
    }
}
