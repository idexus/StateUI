// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance
@testable import StateUIWinUIDriver
import XCTest

final class WinUIVocabularyTests: XCTestCase {
    override func setUp() {
        onUIThread { WinUIBackends.registered }
    }

    /// Every case of every closed vocabulary, written to each element wearing it - a backend's too - is taken: the
    /// page stands and the log says nothing.
    func testEveryCaseOfEveryClosedVocabularyIsTaken() throws {
        try onUIThread {
            XCTAssertEqual(try ClosedVocabularies.untaken(on: WinUIDriver()), [])
        }
    }
}
