// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ApplicationRunnerTests: XCTestCase {
    /// A run starts UIKit, Android, Web, GTK and WinUI heads - an AppKit head runs from the program its build names -
    /// runs a GTK head alone under gdb, never one both under gdb and held for LLDB, and holds only a debug build; each
    /// is refused before anything is built.
    func testWhatARunCannotStartIsRefusedFirst() async throws {
        let nowhere = FileManager.default.temporaryDirectory.appendingPathComponent("run-\(UUID().uuidString)")
        for (request, said) in [
            (RunRequest(build: BuildRequest(host: .appkit)), "starts UIKit, Android, Web, GTK and WinUI heads"),
            (RunRequest(build: BuildRequest(host: .winui), gdb: true), "A GTK head alone runs under gdb"),
            (RunRequest(build: BuildRequest(host: .gtk), debugger: true, gdb: true), "under gdb, or is held for LLDB"),
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

    /// A GTK head run under gdb says every GTK critical's stack and a crash's, Swift's own backtrace off; a GTK or WinUI
    /// head held for LLDB is started by the `lldb-dap` listening on the loopback port the way names; any other run is
    /// its program alone.
    func testAGTKHeadForADebuggerRunsUnderGDB() throws {
        XCTAssertNoThrow(try ApplicationRunner.refuse(RunRequest(build: BuildRequest(host: .gtk), gdb: true)))
        for host in [HostFamily.gtk, .winui] {
            XCTAssertNoThrow(try ApplicationRunner.refuse(RunRequest(build: BuildRequest(host: host), debugger: true)))
        }
        let held = DebugDescriptors.adapter(program: URL(fileURLWithPath: "/home/me/Notes/NotesGTK"), port: 41300)
        XCTAssertEqual([held.request.rawValue, String(held.adapterPort ?? 0)], ["launch", "41300"], "an lldb-dap listening")
        XCTAssertEqual(held.programUri, FileURI.string(URL(fileURLWithPath: "/home/me/Notes/NotesGTK")))
        XCTAssertEqual(held.workingUri, FileURI.string(URL(fileURLWithPath: "/home/me/Notes")))
        let (program, commands) = (URL(fileURLWithPath: "/home/me/Notes/NotesGTK"), URL(fileURLWithPath: "/tmp/gdb.cmd"))
        let under = DesktopLaunch.request(program, gdbCommands: commands)
        XCTAssertEqual(under.executable, .name("gdb"))
        XCTAssertEqual(under.arguments, ["-batch", "-x", "/tmp/gdb.cmd", "--args", "/home/me/Notes/NotesGTK"])
        XCTAssertEqual(under.environment.set["SWIFT_BACKTRACE"], "enable=no")
        XCTAssertEqual(DesktopLaunch.request(program, gdbCommands: nil).executable, .path("/home/me/Notes/NotesGTK"))
        XCTAssertTrue(GTKHead.gdbCommands(for: .arm64).contains("break g_return_if_fail_warning"))
    }

    /// What gdb says of Clang modules' debug information it cannot read as split DWARF - thousands of lines a start,
    /// which no setting of gdb 17 quiets - is left out of a run's output; a critical, a stop and the program's own
    /// words stay.
    func testGDBsNoiseOfModulesIsLeftOut() {
        XCTAssertTrue(DesktopLaunch.gdbNoise(
            "During symbol reading: Could not find DWO CU /home/me/.build/out/ModuleCache.noindex/3VP/Dispatch-3U3.pcm(0x5174cdc4c6e3d656) referenced by CU at offset 0x878e7 [in module /home/me/libStateUIHost.so]"))
        for kept in ["=== CRITICAL Gtk: GTK_IS_WIDGET (widget)", "=== STOPPED", "StateUI-Message: 01:05:15.012: StateUI GTK: x",
                     "During symbol reading: unsupported tag"] {
            XCTAssertFalse(DesktopLaunch.gdbNoise(kept), kept)
        }
    }

    /// A port is relayed to only while a run's `lldb-server` holds it.
    func testADebugPortIsHeldWhileItsRunLasts() async throws {
        let port = try DebugPorts.free()
        XCTAssertFalse(DebugPorts.holds(port))
        let inside = await DebugPorts.holding(port) { DebugPorts.holds(port) }
        XCTAssertTrue(inside)
        XCTAssertFalse(DebugPorts.holds(port))
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
