// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ApplicationRunnerTests: XCTestCase {
    /// A run starts UIKit, Android, Web, GTK and WinUI heads - an AppKit head runs from the program its build names -
    /// holds a WinUI head for no debugger, and holds only a debug build for one; each is refused before anything is
    /// built.
    func testWhatARunCannotStartIsRefusedFirst() async throws {
        let nowhere = FileManager.default.temporaryDirectory.appendingPathComponent("run-\(UUID().uuidString)")
        for (request, said) in [
            (RunRequest(build: BuildRequest(host: .appkit)), "starts UIKit, Android, Web, GTK and WinUI heads"),
            (RunRequest(build: BuildRequest(host: .winui), debugger: true), "WinUI head is debugged from the program"),
            (RunRequest(build: BuildRequest(host: .uikit, configuration: .release), debugger: true), "Only a debug build"),
        ] {
            do {
                _ = try await ApplicationRunner().run(request, in: nowhere, operation: "op")
                XCTFail("\(request) ran")
            } catch let error as ToolingError {
                XCTAssertEqual(error.code, .invalidConfiguration)
                XCTAssertTrue(error.message.contains(said), error.message)
            }
        }
    }

    /// A GTK head run for a debugger runs under gdb - every GTK critical's stack and a crash's said, Swift's own
    /// backtrace off - and any other run is its program alone.
    func testAGTKHeadForADebuggerRunsUnderGDB() throws {
        XCTAssertNoThrow(try ApplicationRunner.refuse(RunRequest(build: BuildRequest(host: .gtk), debugger: true)))
        let (program, commands) = (URL(fileURLWithPath: "/home/me/Notes/NotesGTK"), URL(fileURLWithPath: "/tmp/gdb.cmd"))
        let under = DesktopLaunch.request(program, gdbCommands: commands)
        XCTAssertEqual(under.executable, .name("gdb"))
        XCTAssertEqual(under.arguments, ["-batch", "-x", "/tmp/gdb.cmd", "--args", "/home/me/Notes/NotesGTK"])
        XCTAssertEqual(under.environment.set["SWIFT_BACKTRACE"], "enable=no")
        XCTAssertEqual(DesktopLaunch.request(program, gdbCommands: nil).executable, .path("/home/me/Notes/NotesGTK"))
        XCTAssertTrue(GTKHead.gdbCommands(for: .arm64).contains("break g_return_if_fail_warning"))
    }

    /// A file another process writes is read in lines as it grows, the last one at the end though no line feed ended it.
    func testAFilesLinesAreReadAsItGrows() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("tail-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: file) }
        var tail = FileTail(file, as: .standardError)
        XCTAssertEqual(tail.read(), [])
        try Data("one\ntw".utf8).write(to: file)
        XCTAssertEqual(tail.read().map(\.text), ["one"])
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("o\nthree".utf8))
        try handle.close()
        XCTAssertEqual(tail.read().map(\.text), ["two"])
        XCTAssertEqual(tail.read(end: true).map(\.text), ["three"])
        XCTAssertEqual(tail.read(end: true).first?.stream, nil)
    }

    #if os(macOS)
    /// A device's application is the process whose program is `<Product>.app/<Product>`, not one merely named alike.
    func testADevicesApplicationIsFoundByItsProgram() {
        let json = Data("""
            {"result": {"runningProcesses": [
              {"executable": "file:///usr/libexec/springboard", "processIdentifier": 50},
              {"executable": "file:///private/var/containers/Bundle/Application/X/HelloWorldUIKitTests.app/HelloWorldUIKitTests", "processIdentifier": 70},
              {"executable": "file:///private/var/containers/Bundle/Application/Y/HelloWorldUIKit.app/HelloWorldUIKit", "processIdentifier": 1276}
            ]}}
            """.utf8)
        XCTAssertEqual(DeviceLaunch.process(of: "HelloWorldUIKit", in: json), 1276)
        XCTAssertNil(DeviceLaunch.process(of: "Notes", in: json))
        XCTAssertNil(DeviceLaunch.process(of: "Notes", in: Data("{}".utf8)))
    }

    /// A process of this Mac is alive while it runs - a stopped one too - and not once it ended.
    func testAProcessIsAliveUntilItEnds() async throws {
        XCTAssertTrue(SimulatorLaunch.alive(Int(ProcessInfo.processInfo.processIdentifier)))
        XCTAssertFalse(SimulatorLaunch.alive(Int(Int32.max)))
    }
    #endif
}
