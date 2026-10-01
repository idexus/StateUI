// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The doorbell every host rings the same way: a thread of its own parked until the core has work.
/// Design: docs/design/host/runtime.md#one-turn
extension CoreLink {
    /// Parks this thread until the core has work, then hands `post` a turn to put on the UI thread's queue, for
    /// as long as the process runs. Called on a thread of the host's own, never the UI thread.
    public func ringForever(_ post: () -> Void) -> Never {
        while true {
            _ = waitForWork()
            post()
        }
    }
}
