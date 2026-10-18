// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUIHost
import XCTest

/// What a host holds by number until it is taken out or let go.
@MainActor
final class NumberedTests: XCTestCase {
    private final class View {}

    /// A value is found by its number while it is held, and an answer is taken out once.
    func testAValueIsFoundByItsNumberAndTakenOutOnce() {
        let answers = Numbered<String>()
        let first = answers.hold("yes")
        let second = answers.reserve()
        answers.hold("no", as: second)

        XCTAssertEqual(answers.find(first), "yes")
        XCTAssertEqual(answers.take(first), "yes")
        XCTAssertNil(answers.take(first), "an answer comes once")
        answers.release(second)
        XCTAssertNil(answers.find(second))
        XCTAssertEqual(answers.count, 0)
    }

    /// No number is given twice across the process: one left over from a table finds nothing in another.
    func testNoNumberIsGivenTwiceAcrossTables() {
        let dialogs = Numbered<String>()
        let callbacks = Numbered<() -> Void>()
        let views = LiveViews<View>()

        let numbers = [dialogs.hold("a"), callbacks.hold({}), views.reserve(), dialogs.hold("b")]

        XCTAssertEqual(Set(numbers).count, numbers.count)
        XCTAssertEqual(numbers, numbers.sorted(), "in the order they were given")
        XCTAssertNil(dialogs.find(numbers[1]), "a callback's number holds no dialog")
    }
}
