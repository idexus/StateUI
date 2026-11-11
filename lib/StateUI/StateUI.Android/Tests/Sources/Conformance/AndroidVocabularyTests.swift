// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance
import XCTest

/// The walk of every case of every closed vocabulary, in parts of a few elements each: each part an item, which the
/// runner runs in a message of the UI thread of its own.
/// Design: docs/design/platforms/android/conformance.md#a-message-an-item
final class AndroidVocabularyTests: XCTestCase {
    /// How many items the walk runs in: some two elements each, a few seconds on a phone.
    static let parts = 24

    static var allTests: [(String, (AndroidVocabularyTests) -> () throws -> Void)] {
        (1...parts).map { number in
            ("testEveryCaseOfEveryClosedVocabularyIsTaken@\(number)/\(parts)", { test in
                { try test.walk(Conformance.Part(number, of: parts)) }
            })
        }
    }

    /// Every case of every closed vocabulary, written to each of `part`'s elements wearing it, is taken: the page
    /// stands and the log says nothing.
    private func walk(_ part: Conformance.Part) throws {
        try onMainActor {
            let driver = AndroidDriver()
            defer { driver.close() }
            XCTAssertEqual(try ClosedVocabularies.untaken(on: driver, part: part), [])
        }
    }
}
