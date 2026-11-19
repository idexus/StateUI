// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

/// A page in Safari reached by LLDB through Safari's WebAssembly debugger.
final class SafariDebuggerTests: XCTestCase {
    /// The pages are the processes LLDB's `webinspector-wasm` platform lists, each named by its page's host; none where
    /// it lists none.
    func testThePagesAreTheProcessesItsPlatformLists() {
        let listed = """
            (lldb) platform process list
            3 matching processes were found on "webinspector-wasm"

            PID    PARENT USER       TRIPLE                         NAME
            ====== ====== ========== ============================== ============================
            17415  0                                                127.0.0.1
            24738  0                                                WebAssembly Debugger (WebContent PID 24738)
            24681  0                                                example.com
            """
        XCTAssertEqual(SafariDebugger.pages(in: listed),
                       [17415: "127.0.0.1", 24738: "WebAssembly Debugger (WebContent PID 24738)", 24681: "example.com"])
        XCTAssertEqual(SafariDebugger.pages(in: #"error: no processes were found on the "webinspector-wasm" platform"#), [:])
    }

    /// The page a run opened is the new one of its address's host: another tab of another site, opened meanwhile, is not.
    func testThePageOpenedIsTheNewOneOfItsHost() {
        let before: [Int: String] = [17415: "127.0.0.1"]
        let after: [Int: String] = [17415: "127.0.0.1", 24681: "example.com", 24523: "127.0.0.1"]
        XCTAssertEqual(SafariDebugger.opened("http://127.0.0.1:8460/?STATEUI_RUN=7", before: before, after: after), 24523)
        XCTAssertNil(SafariDebugger.opened("http://127.0.0.1:8460/", before: before, after: [17415: "127.0.0.1", 24681: "example.com"]))
    }

    /// A page opened for a debugger carries its run in its address, so Safari loads it anew rather than bringing
    /// forward an earlier run's tab of the same address.
    func testAPageOpenedForADebuggerHasAnAddressOfItsOwn() {
        XCTAssertEqual(SafariDebugger.address("http://127.0.0.1:8460/", run: 7), "http://127.0.0.1:8460/?STATEUI_RUN=7")
        XCTAssertEqual(SafariDebugger.address("http://127.0.0.1:8460/?STATEUI_TALLY=1", run: 7),
                       "http://127.0.0.1:8460/?STATEUI_TALLY=1&STATEUI_RUN=7")
    }

    /// LLDB attaches to the page's process through Safari's WebAssembly debugger, leaving the page as the session ends.
    func testLLDBAttachesToThePageThroughSafarisDebugger() {
        let way = DebugDescriptors.safari(process: 17423)
        XCTAssertEqual(way.kind, .lldb)
        XCTAssertEqual(way.request, .attach)
        XCTAssertEqual(way.process, 17423)
        XCTAssertEqual(way.initCommands, ["platform select webinspector-wasm"])
        XCTAssertEqual(way.attachCommands, ["process attach --pid 17423"])
        XCTAssertEqual(way.terminateCommands, [])
    }

    /// A debugger follows a page in Chromium's browsers, and in Safari where Safari's WebAssembly debugger stands.
    func testADebuggerFollowsSafariWhereItsDebuggerStands() {
        XCTAssertTrue(Browsers.followed("com.apple.Safari", safariDebugger: true))
        XCTAssertFalse(Browsers.followed("com.apple.Safari", safariDebugger: false))
        XCTAssertTrue(Browsers.followed("com.google.Chrome", safariDebugger: false))
        XCTAssertFalse(Browsers.followed("org.mozilla.firefox", safariDebugger: true))
    }

    /// The doctor finds Safari by its version where its WebAssembly debugger stands, an older one as too old.
    func testTheDoctorFindsSafariWithItsDebugger() {
        guard case .found("27.2") = Doctor.safari(version: "27.2", debugger: true) else { return XCTFail("27.2 with its debugger") }
        guard case .tooOld("26.6.2") = Doctor.safari(version: "26.6.2", debugger: false) else { return XCTFail("26.6.2 alone") }
        guard case .missing = Doctor.safari(version: nil, debugger: false) else { return XCTFail("no Safari") }
    }
}
