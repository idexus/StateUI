// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

#if !os(WASI)
/// The doorbell every host rings the same way: a thread of its own parked until a job comes from another thread.
/// Design: docs/design/host/runtime.md#one-turn
extension CoreLink {
    /// Parks this thread until a job comes, then asks for a turn the way the host said (`postTurns`), for as long
    /// as the process runs. Called on a thread of the host's own, never the UI thread.
    public nonisolated func ringForever() -> Never {
        while true {
            if waitForWork() > 0 { askForTurn() }
        }
    }
}
#endif
