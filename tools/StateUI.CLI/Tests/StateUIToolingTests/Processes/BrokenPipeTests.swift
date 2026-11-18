// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class BrokenPipeTests: XCTestCase {
    /// A write to a pipe whose reader ended - a served stateui gone before its input was written - fails, never ending
    /// this process: the tool talks to programs that end as they like.
    func testAWriteToAnEndedReaderFails() throws {
        BrokenPipe.ignore()
        let pipe = Pipe()
        try pipe.fileHandleForReading.close()
        XCTAssertThrowsError(try pipe.fileHandleForWriting.write(contentsOf: Data("lost".utf8)))
    }
}
