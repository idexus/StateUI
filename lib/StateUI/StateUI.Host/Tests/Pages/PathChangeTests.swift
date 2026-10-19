// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUIHost
import XCTest

/// How a navigation stack's pages change, and which changes move on screen.
final class PathChangeTests: XCTestCase {
    private func change(_ old: [String], _ new: [String]) -> PathChange? {
        PathChange.of(from: old, to: new, same: ==)
    }

    /// Pages joining on top of every page that stays are a push, however many join.
    func testPagesJoiningOnTopArePushed() {
        XCTAssertEqual(change(["A"], ["A", "B"]), .push)
        XCTAssertEqual(change(["A"], ["A", "B", "C"]), .push, "several: the last arrives")
    }

    /// Pages taken away from the top are one pop back to those that stay, however many go.
    func testPagesTakenFromTheTopArePopped() {
        XCTAssertEqual(change(["A", "B"], ["A"]), .pop(staying: 1))
        XCTAssertEqual(change(["A", "B", "C"], ["A"]), .pop(staying: 1), "several: one move back")
        XCTAssertEqual(change(["A", "B", "C"], ["A", "B"]), .pop(staying: 2))
    }

    /// A page under the top replaced, the first pages shown and the stack emptied are replacements; the same
    /// pages are no change.
    func testEveryOtherChangeIsAReplacement() {
        XCTAssertEqual(change(["A", "B"], ["C"]), .replace)
        XCTAssertEqual(change(["A", "B"], ["A", "C"]), .replace)
        XCTAssertEqual(change([], ["A", "B"]), .replace, "a stack's first pages do not arrive")
        XCTAssertEqual(change(["A"], []), .replace)
        XCTAssertNil(change(["A", "B"], ["A", "B"]))
    }

    /// A push and a pop move, a replacement does not, and none moves for a user who asked for less motion.
    func testOnlyAPushAndAPopMove() {
        XCTAssertTrue(PathChange.push.moves(reducingMotion: false))
        XCTAssertTrue(PathChange.pop(staying: 1).moves(reducingMotion: false))
        XCTAssertFalse(PathChange.replace.moves(reducingMotion: false))
        XCTAssertFalse(PathChange.push.moves(reducingMotion: true))
        XCTAssertFalse(PathChange.pop(staying: 1).moves(reducingMotion: true))
    }
}
