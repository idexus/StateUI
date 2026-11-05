// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import StateUIAndroid
import XCTest

final class AndroidRequestTests: XCTestCase {
    static var allTests: [(String, (AndroidRequestTests) -> () throws -> Void)] {
        [
            ("testACompletedRequestLeavesNoNativeRecord", testACompletedRequestLeavesNoNativeRecord),
            ("testCancellationBeforeAConnectionStartsNoIO", testCancellationBeforeAConnectionStartsNoIO),
            ("testAnOpeningThatFailsLeavesNoNativeRecord", testAnOpeningThatFailsLeavesNoNativeRecord),
            ("testRepeatedCancellationDuringIOReleasesOnce", testRepeatedCancellationDuringIOReleasesOnce),
            ("testCancellationAfterTheWorkerLeavesNoNativeRecord", testCancellationAfterTheWorkerLeavesNoNativeRecord),
        ]
    }

    func testACompletedRequestLeavesNoNativeRecord() {
        onMainActor {
            Self.check("completed")
            TestWindow.run(for: 20)
            Self.check("cancelLatest")
        }
    }

    func testCancellationBeforeAConnectionStartsNoIO() {
        onMainActor { Self.check("cancelledBeforeConnection") }
    }

    func testRepeatedCancellationDuringIOReleasesOnce() {
        onMainActor { Self.check("cancelledDuringResponse") }
    }

    func testAnOpeningThatFailsLeavesNoNativeRecord() {
        onMainActor { Self.check("failedBeforeConnection") }
    }

    func testCancellationAfterTheWorkerLeavesNoNativeRecord() {
        onMainActor { Self.check("cancelledAfterWorker") }
    }

    @MainActor
    private static func check(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        Java.frame {
            let method = Java.staticMethod(Self.fixture, name, "()Ljava/lang/String;")
            let failure = Java.text(Java.callStaticObject(Self.fixture, method))
            XCTAssertEqual(failure, "", file: file, line: line)
        }
    }

    @MainActor private static let fixture = Java.findClass("stateui/android/TestRequests")
}
