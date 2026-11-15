// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation
import Synchronization

/// The programs a captured program started, found by the session it leads, and stopped with it.
/// Design: docs/design/tooling/processes.md#a-program-and-everything-it-started
final class ProcessSession: Sendable {
    private struct State {
        var leader: Int?
        var stopRequested = false
        var stopping: Task<Void, Never>?
    }

    private let state = Mutex(State())
    private let gracePeriod: Duration

    init(gracePeriod: Duration) {
        self.gracePeriod = gracePeriod
    }

    /// The program leading the session started as process `leader`.
    func started(_ leader: Int) {
        let stopRequested = state.withLock { state in
            state.leader = leader
            return state.stopRequested
        }
        if stopRequested { stop() }
    }

    /// Asks every program of the session to stop, and kills those still running when the grace period passes.
    func stop() {
        let gracePeriod = gracePeriod
        state.withLock { state in
            state.stopRequested = true
            guard let leader = state.leader, state.stopping == nil else { return }
            state.stopping = Task { await Self.end(session: leader, gracePeriod: gracePeriod) }
        }
    }

    /// Returns once a stop that began has ended.
    func stopped() async {
        await state.withLock { $0.stopping }?.value
    }

    private static func end(session: Int, gracePeriod: Duration) async {
        #if !os(Windows)
        for member in members(of: session) { kill(member, SIGTERM) }
        let deadline = ContinuousClock.now + gracePeriod
        while ContinuousClock.now < deadline, !members(of: session).isEmpty {
            try? await Task.sleep(for: .milliseconds(50))
        }
        for member in members(of: session) { kill(member, SIGKILL) }
        #endif
    }

    #if !os(Windows)
    /// The running processes of `session`, this one aside.
    static func members(of session: Int) -> [pid_t] {
        let own = getpid()
        return processes().filter { $0 > 0 && $0 != own && Int(getsid($0)) == session }
    }

    private static func processes() -> [pid_t] {
        #if canImport(Darwin)
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var identifiers = [pid_t](repeating: 0, count: Int(count) + 64)
        let filled = identifiers.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        return Array(identifiers.prefix(Int(max(filled, 0))))
        #else
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: "/proc")) ?? []
        return entries.compactMap { pid_t($0) }
        #endif
    }
    #endif
}
