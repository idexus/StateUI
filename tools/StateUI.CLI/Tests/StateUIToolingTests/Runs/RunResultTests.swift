// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class RunResultTests: XCTestCase {
    /// A desktop head's run - AppKit's on a Mac paired too - ends the command with its program's status, a signal's as
    /// 128 and the signal; a head a device or a browser runs ends it with none.
    func testADesktopHeadsStatusIsTheCommands() {
        func ran(_ host: HostFamily, _ status: Int?) -> RunResult {
            let built = BuildResult(application: "Notes", host: host, configuration: .debug, architecture: .arm64, folderUri: "file:///b", programUri: "file:///b/p")
            return RunResult(launched: LaunchedApplication(build: built, process: nil, held: false), exitStatus: status)
        }
        XCTAssertEqual(ran(.appkit, 7).failureStatus, 7)
        XCTAssertEqual(ran(.appkit, 137).failureStatus, 137)
        XCTAssertEqual(ran(.gtk, 1).failureStatus, 1)
        XCTAssertEqual(ran(.winui, 3).failureStatus, 3)
        XCTAssertNil(ran(.appkit, 0).failureStatus)
        XCTAssertNil(ran(.uikit, 7).failureStatus)
        XCTAssertNil(ran(.web, nil).failureStatus)
        XCTAssertEqual(HostFamily.desktop, [.appkit, .gtk, .winui])
    }
}
