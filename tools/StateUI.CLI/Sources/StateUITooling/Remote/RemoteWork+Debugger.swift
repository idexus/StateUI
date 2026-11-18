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

    /// Tells `launched` to `reporter`: where an `lldb-dap` of another machine holds it, once a relay to it is opened,
    /// the way rewritten to reach it from here.
    /// Design: docs/design/tooling/service.md#a-debugger-relayed
    func started(_ launched: LaunchedApplication, ready: Ready, relays: Relays, reporter: RunReporter) {
        guard let remote = ready.reached.remote, var way = launched.debugger, let port = way.adapterPort.flatMap(UInt16.init(exactly:)) else {
            return reporter.started(launched)
        }
        do {
            // LLDB there takes no source map to a folder it has not: the relay turns the paths instead.
            let translation = PathTranslation(here: ready.common.path, there: ready.commonThere, windows: ready.reached.places.windows)
            let relay = try DebugRelay.open(to: remote, port: port, translation: translation)
            relays.keep(relay)
            way.adapterPort = Int(relay.port)
            var rewritten = launched
            rewritten.debugger = way
            reporter.started(rewritten)
        } catch {
            reporter.build.progress("no way for a debugger was readied: \(error)")
            var unreached = launched
            unreached.debugger = nil
            reporter.started(unreached)
        }
    }
}
