// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance
@testable import StateUIGTKDriver
import XCTest

final class GTKVocabularyTests: XCTestCase {
    override func setUp() async throws {
        onUIThread { GTKBackends.registered }
    }

    /// Every case of every closed vocabulary, written to each element wearing it - a backend's too - is taken: the
    /// page stands and the log says nothing.
    func testEveryCaseOfEveryClosedVocabularyIsTaken() throws {
        try onUIThread {
            XCTAssertEqual(try ClosedVocabularies.untaken(on: GTKDriver()), [])
        }
    }
}
