// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// What a window asks its host to show, as it changes.
@MainActor
final class WindowPresentationTests: XCTestCase {
    /// A window shows the first arrangement of pages among its children and its overlay, says each only when it
    /// changes, and is told it was made once.
    func testAWindowSaysWhatItShowsOnlyAsItChanges() throws {
        let runtime = HostRuntime.still()
        func window(_ children: [HostPatch]) -> HostPatch {
            var window = HostPatch(id: .manual("window"), type: .window)
            window.events = .replace([.created: 5])
            window.children = .arranged(children)
            return window
        }
        runtime.tree.apply(window([HostPatch(id: .manual("page"), type: .page)]), complete: true)
        let presentation = WindowPresentation()

        let first = presentation.show(try XCTUnwrap(runtime.tree.root))
        XCTAssertEqual(first.arrangement?.shown?.id, .manual("page"))
        XCTAssertNil(first.arrangement?.previous)
        XCTAssertEqual(first.created, 5)
        XCTAssertTrue(first.overlay == nil, "no overlay, before or now: nothing to say")

        let again = presentation.show(try XCTUnwrap(runtime.tree.root))
        XCTAssertNil(again.arrangement)
        XCTAssertTrue(again.overlay == nil, "nothing new to lay over")
        XCTAssertNil(again.created, "told it was made once")
    }
}
