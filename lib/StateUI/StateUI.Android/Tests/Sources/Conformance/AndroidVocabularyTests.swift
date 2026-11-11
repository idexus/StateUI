// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance
import XCTest

final class AndroidVocabularyTests: XCTestCase {
    static var allTests: [(String, (AndroidVocabularyTests) -> () throws -> Void)] {
        [("testEveryCaseOfEveryClosedVocabularyIsTaken", testEveryCaseOfEveryClosedVocabularyIsTaken)]
    }

    /// Every case of every closed vocabulary, written to each element wearing it, is taken: the page stands and the
    /// log says nothing.
    func testEveryCaseOfEveryClosedVocabularyIsTaken() throws {
        try onMainActor {
            let driver = AndroidDriver()
            defer { driver.close() }
            XCTAssertEqual(try ClosedVocabularies.untaken(on: driver), [])
        }
    }
}
