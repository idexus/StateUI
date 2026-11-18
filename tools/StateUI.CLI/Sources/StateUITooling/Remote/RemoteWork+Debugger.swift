// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
import Synchronization

extension RemoteWork {
    /// The relays a run opened, closed as it ends - one opened after, at once.
    final class Relays: Sendable {
        private let state = Mutex<(ended: Bool, open: [DebugRelay])>((false, []))

        func keep(_ relay: DebugRelay) {
            let ended = state.withLock { state in
                if !state.ended { state.open.append(relay) }
                return state.ended
            }
            if ended { relay.close() }
        }

        func end() {
            state.withLock { state in
                state.ended = true
                return state.open
            }.forEach { $0.close() }
        }
    }

    /// Tells `launched` to `reporter`: where it is held by an `lldb-server` of another machine, once its program is
    /// fetched home and a relay to it opened, the way rewritten to reach it from here.
    /// Design: docs/design/tooling/service.md#a-debugger-relayed
    func started(_ launched: LaunchedApplication, ready: Ready, relays: Relays, reporter: RunReporter) {
        guard let remote = ready.reached.remote, let port = Self.relayedPort(of: launched.debugger) else {
            return reporter.started(launched)
        }
        Task {
            do {
                let (rewritten, relay) = try await relayed(launched, port: port, remote: remote, ready: ready, reporter: reporter.build)
                relays.keep(relay)
                reporter.started(rewritten)
            } catch {
                reporter.build.progress("no way for a debugger was readied: \(error)")
                var unreached = launched
                unreached.debugger = nil
                reporter.started(unreached)
            }
        }
    }

    /// The port of the other machine's loopback `way` connects LLDB to, where it is an `lldb-server`'s.
    static func relayedPort(of way: DebugDescriptor?) -> UInt16? {
        way?.attachCommands.lazy.compactMap { command -> UInt16? in
            guard command.hasPrefix("gdb-remote 127.0.0.1:") else { return nil }
            return UInt16(command.dropFirst("gdb-remote 127.0.0.1:".count))
        }.first
    }

    /// `launched`'s program folder fetched into the application's `.build/stateui/<machine>`, a relay opened to `port`
    /// of `remote`'s loopback, and the way to it: the program read from the copy here, the sources mapped from where
    /// they were built there.
    private func relayed(
        _ launched: LaunchedApplication, port: UInt16, remote: RemoteMachine, ready: Ready, reporter: BuildReporter
    ) async throws -> (LaunchedApplication, DebugRelay) {
        let built = launched.build
        let home = try FileURI.url(ready.application.packageUri).appendingPathComponent(".build/stateui")
            .appendingPathComponent(remote.name.replacingOccurrences(of: "/", with: "-"))
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        reporter.progress("fetching \(built.application)'s program for the debugger")
        _ = try await ready.reached.served.session { session in
            try await FolderTransfer.fetch(FileURI.shown(built.folderUri), into: home, over: session, progress: reporter.progress)
        }
        let program = try FileURI.url(Self.moved(built.programUri, from: built.folderUri, to: home))
        let relay = try DebugRelay.open(to: remote, port: port)
        var rewritten = launched
        rewritten.debugger = DebugDescriptors.gdbServer(program: program, port: relay.port, sourceMap: (ready.commonThere, ready.common))
        return (rewritten, relay)
    }
}
