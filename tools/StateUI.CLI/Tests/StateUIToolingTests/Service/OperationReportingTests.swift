// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import Synchronization
import XCTest

final class OperationReportingTests: XCTestCase {
    /// A work that fails has its last words told before its failure is - however slowly they are told - as an
    /// operation ended takes no more output: the compiler's error stands before the operation's end.
    func testAFailuresLastWordsAreToldBeforeIt() async {
        let told = Mutex<[String]>([])
        do {
            _ = try await ToolingService.reporting(tell: { each in
                try? await Task.sleep(for: .milliseconds(100))
                if case .output(let line) = each { told.withLock { $0.append(line.text) } }
            }) { (reporter: RunReporter) -> Int in
                reporter.output(ProcessOutput(stream: .standardError, text: "error: the compiler stopped"))
                throw ToolingError(.toolFailed, "it did not build")
            }
            XCTFail("the work failed")
        } catch {}
        XCTAssertEqual(told.withLock { $0 }, ["error: the compiler stopped"])
    }
}
