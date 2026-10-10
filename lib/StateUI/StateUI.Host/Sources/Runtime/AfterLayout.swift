// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Work that waits for the layout pass under way to end, the same on every host: it runs once that pass is over,
/// in the order it came, and work that comes while it runs waits for the next. The host says how it is told a
/// pass is over.
/// Design: docs/design/host/runtime.md#after-a-layout-pass
@_spi(Host) @MainActor public final class AfterLayout {
    /// How the host asks to be told the pass under way is over - asked once, until it is.
    public var askForPassEnd: () -> Void = {}

    private var waiting: [@MainActor () -> Void] = []

    /// A queue no host has said how to tell yet.
    public init() {}

    /// Runs `work` once the layout pass under way is over.
    public func run(_ work: @escaping @MainActor () -> Void) {
        waiting.append(work)
        if waiting.count == 1 { askForPassEnd() }
    }

    /// The pass is over: what waited runs, in the order it came. Whether anything did.
    @discardableResult
    public func passEnded() -> Bool {
        let works = waiting
        waiting = []
        for work in works { work() }
        return !works.isEmpty
    }
}
