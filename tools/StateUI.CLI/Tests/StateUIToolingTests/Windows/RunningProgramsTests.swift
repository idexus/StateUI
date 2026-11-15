// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class RunningProgramsTests: XCTestCase {
    /// A build stops only the program running from the folder it writes again: one of the same name running from
    /// another folder - another checkout's, another architecture's - runs on.
    func testOnlyTheProgramRunningFromTheFolderStops() async throws {
        #if os(Windows)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("running-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        var started: [Process] = []
        for folder in ["mine", "other"] {
            let place = root.appendingPathComponent(folder)
            try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
            let program = place.appendingPathComponent("NotesWinUI.exe")
            try FileManager.default.copyItem(at: URL(fileURLWithPath: Probe.path), to: program)
            let process = Process()
            process.executableURL = program
            process.arguments = ["sleep", "60"]
            try process.run()
            started.append(process)
        }
        defer { started.filter(\.isRunning).forEach { $0.terminate() } }
        try await Task.sleep(for: .seconds(1))

        RunningPrograms.stop(runningFrom: root.appendingPathComponent("mine"))

        let gone = try await Probe.waitUntilGone(started[0].processIdentifier)
        XCTAssertTrue(gone, "the program running from the folder stopped")
        XCTAssertTrue(started[1].isRunning, "the program of the same name elsewhere runs on")
        #else
        throw XCTSkip("a running program holds its file on Windows alone")
        #endif
    }
}
