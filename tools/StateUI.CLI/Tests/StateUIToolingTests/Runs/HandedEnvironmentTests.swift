// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class HandedEnvironmentTests: XCTestCase {
    private let tool = ["STATEUI_TALLY": "1", "STATEUI_INSPECT": "1", "STATEUI_HOST": "web", "PATH": "/usr/bin", "HOME": "/Users/a"]

    /// A run hands an application it starts elsewhere each `STATEUI_` variable of the tool's environment but the
    /// host's, which names what a build is for, and nothing else of it.
    func testARunHandsItsApplicationEveryStateUIVariableButTheHost() {
        XCTAssertEqual(HandedEnvironment(of: tool).variables, ["STATEUI_TALLY": "1", "STATEUI_INSPECT": "1"])
        XCTAssertEqual(HandedEnvironment(of: ["PATH": "/usr/bin"]).variables, [:])
    }

    /// Every launch hands them in its platform's form, in their names' order: an extra of Android's start, a
    /// parameter of the page's address, a variable of a simulator's or a device's process - nothing where none is
    /// handed.
    func testEveryLaunchHandsTheVariablesInItsPlatformsForm() {
        let handed = HandedEnvironment(of: tool), none = HandedEnvironment(of: ["PATH": "/usr/bin"])
        XCTAssertEqual(AndroidLaunch.switches(handed), ["-e", "STATEUI_INSPECT", "1", "-e", "STATEUI_TALLY", "1"])
        XCTAssertEqual(AndroidLaunch.switches(none), [])
        #if canImport(NIOPosix)
        XCTAssertEqual(WebLaunch.query(of: handed), "?STATEUI_INSPECT=1&STATEUI_TALLY=1")
        XCTAssertEqual(WebLaunch.query(of: none), "")
        #endif
        #if os(macOS)
        XCTAssertEqual(DeviceLaunch.handing(handed), ["--environment-variables", #"{"STATEUI_INSPECT":"1","STATEUI_TALLY":"1"}"#])
        XCTAssertEqual(DeviceLaunch.handing(none), [])
        let simctl = SimulatorLaunch.environment(handing: handed).set
        XCTAssertEqual(simctl["SIMCTL_CHILD_STATEUI_TALLY"], "1")
        XCTAssertEqual(simctl["SIMCTL_CHILD_STATEUI_INSPECT"], "1")
        XCTAssertNil(simctl["SIMCTL_CHILD_STATEUI_HOST"])
        XCTAssertEqual(SimulatorLaunch.environment(handing: none).set.keys.filter { $0.hasPrefix("SIMCTL_CHILD_") }, [])
        #endif
    }
}
