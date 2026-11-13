// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Dispatch
import Foundation
import Synchronization
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import WinSDK
#endif

/// The terminal's interrupt: the first cancels the command's work, which stops what it started; the second ends
/// the tool at once.
/// Design: docs/design/tooling/command-line.md#an-interrupt
enum Interruption {
    private static let count = Mutex(0)
    private static let work = Mutex<Task<Void, any Error>?>(nil)

    /// Runs `body` as the command's work; an interrupted command ends with status 130 once its work has stopped.
    static func run(_ body: sending @escaping () async throws -> Void) async throws {
        let task = Task { try await body() }
        work.withLock { $0 = task }
        listen()
        do {
            try await task.value
        } catch is CancellationError where task.isCancelled {
        }
        if task.isCancelled {
            StandardOutput.diagnose("stateui: interrupted")
            throw ExitCode(ExitStatus.interrupted)
        }
    }

    private static func interrupted() {
        let times = count.withLock { count in
            count += 1
            return count
        }
        if times == 1 {
            work.withLock { $0?.cancel() }
        } else {
            exit(ExitStatus.interrupted)
        }
    }

    #if os(Windows)
    private static func listen() {
        SetConsoleCtrlHandler({ kind in
            guard kind == DWORD(CTRL_C_EVENT) || kind == DWORD(CTRL_BREAK_EVENT) else { return false }
            Interruption.interrupted()
            return true
        }, true)
    }
    #else
    private static let source = Mutex<(any DispatchSourceSignal)?>(nil)

    private static func listen() {
        signal(SIGINT, SIG_IGN)
        let signals = DispatchSource.makeSignalSource(signal: SIGINT, queue: DispatchQueue(label: "stateui interrupt"))
        signals.setEventHandler { interrupted() }
        signals.resume()
        source.withLock { $0 = signals }
    }
    #endif
}
