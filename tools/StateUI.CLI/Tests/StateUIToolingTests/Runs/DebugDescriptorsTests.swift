// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class DebugDescriptorsTests: XCTestCase {
    /// A program of this machine is started by LLDB in its project's folder.
    func testAProgramOfThisMachineIsStartedByLLDB() {
        let way = DebugDescriptors.program(URL(fileURLWithPath: "/w/.build/app/Demo"), working: URL(fileURLWithPath: "/w"))
        XCTAssertEqual(way.kind, .lldb)
        XCTAssertEqual(way.request, .launch)
        XCTAssertEqual(way.programUri, "file:///w/.build/app/Demo")
        XCTAssertEqual(way.workingUri, "file:///w")
        XCTAssertEqual(way.initCommands + way.attachCommands + way.terminateCommands, [])
    }

    /// LLDB attaches to a simulator's process, one of this Mac's, and to a device's through the device, its symbols read
    /// from the bundle built; the session's end ends the application.
    func testAUIKitHeadIsAttachedToOnItsSimulatorOrDevice() {
        let simulator = DebugDescriptors.simulator(process: 4343)
        XCTAssertEqual(simulator.request, .attach)
        XCTAssertEqual(simulator.process, 4343)
        XCTAssertEqual(simulator.attachCommands, [])
        XCTAssertEqual(simulator.terminateCommands, ["process kill"])
        let device = DebugDescriptors.device("PHONE", process: 37779, bundle: URL(fileURLWithPath: "/b/App.app"))
        XCTAssertEqual(device.initCommands, [
            "settings append target.exec-search-paths /b/App.app", "settings append target.exec-search-paths /b/App.app/Frameworks",
        ])
        XCTAssertEqual(device.attachCommands, ["device select PHONE", "device process attach --pid 37779"])
        XCTAssertEqual(device.terminateCommands, ["process kill"])
    }

    /// LLDB reaches an Android head through the lldb-server in its sandbox, on the device named in the address, the
    /// JIT's announcements off and the runtime's own signals passed on.
    func testAnAndroidHeadIsReachedThroughItsServer() {
        let way = DebugDescriptors.android(
            serial: "emulator-5554", socket: "com.stateui.helloworld/stateui-debugger.sock", process: 4242,
            symbols: URL(fileURLWithPath: "/build/symbols/arm64-v8a"))
        XCTAssertEqual(way.initCommands, [
            "settings set plugin.jit-loader.gdb.enable off", "platform select remote-android",
            "platform connect unix-abstract-connect://emulator-5554/com.stateui.helloworld/stateui-debugger.sock",
            "settings append target.exec-search-paths /build/symbols/arm64-v8a",
        ])
        XCTAssertEqual(way.attachCommands, [
            "process attach --pid 4242", "process handle SIGSEGV --pass true --stop false --notify false",
            "process handle SIGBUS --pass true --stop false --notify false",
        ])
    }

    /// A browser's debugger starts the browser on the page, reading the page's sources from its folder.
    func testAPageIsStartedByItsBrowsersDebugger() {
        let way = DebugDescriptors.page(
            "http://127.0.0.1:8460/", browser: URL(fileURLWithPath: "/Applications/Chrome.app/Contents/MacOS/Chrome"),
            site: URL(fileURLWithPath: "/w/.build/stateui/artifacts/web-debug"))
        XCTAssertEqual(way.kind, .browser)
        XCTAssertEqual(way.request, .launch)
        XCTAssertEqual(way.url, "http://127.0.0.1:8460/")
        XCTAssertEqual(way.programUri, "file:///Applications/Chrome.app/Contents/MacOS/Chrome")
        XCTAssertEqual(way.sourceUri, "file:///w/.build/stateui/artifacts/web-debug")
    }
}
