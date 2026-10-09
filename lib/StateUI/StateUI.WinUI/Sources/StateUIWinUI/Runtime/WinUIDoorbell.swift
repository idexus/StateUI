// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI
import WinSDK

/// The doorbell: a thread parked until a job comes from another thread, posting a turn to the UI thread's queue - the
/// way the UI thread posts one for work of its own.
/// Design: docs/design/platforms/winui/runtime.md#the-doorbell
enum WinUIDoorbell {
    /// Whether the thread runs.
    @MainActor private static var installed = false

    /// Gives the core the way to post a turn, and starts the thread, once; each turn posted reaches the host
    /// through the relay's `turn`.
    @MainActor static func install() {
        CoreLink().postTurns(with: { stateui_winui_post_turn() })
        guard !installed else { return }
        installed = true
        startThread()
    }

    /// Started from a nonisolated function: a closure written in a `@MainActor` one is MainActor's.
    /// Design: docs/design/platforms/winui/runtime.md#the-doorbell
    private nonisolated static func startThread() {
        let thread = CreateThread(nil, 0, { _ in
            CoreLink().ringForever()
        }, nil, 0, nil)
        if let thread { CloseHandle(thread) }
    }

    /// A turn the relay posted: the work a layout pass left, then the turn.
    @MainActor static func turn() {
        let works = pending
        pending = []
        for work in works { work() }
        WinUIRenderer.shared?.runtime.pump.turn()
    }
}

extension WinUIDoorbell {
    /// Runs `work` in the next turn posted, once the layout pass under way is over: what a pass decides - a split
    /// view's first room - is said once WinUI has finished laying out.
    @MainActor static func afterPass(_ work: @escaping @MainActor () -> Void) {
        pending.append(work)
        stateui_winui_post_turn()
    }

    /// Work waiting for the pass under way to end.
    @MainActor private static var pending: [@MainActor () -> Void] = []
}
