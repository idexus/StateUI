// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The work ending with an application's tree: its cancelled owned runs and its lifecycle handlers, including
/// gated work those handlers start. A host can keep draining its jobs until this teardown finishes.
/// Design: docs/design/core/render.md#ending-an-application
@_spi(Host) @MainActor public final class HostTeardown {
    @TaskLocal static var current: HostTeardown?

    private var pending = 0
    private var collecting = false
    private var sealed = false

    /// Whether every task this teardown follows has finished.
    public var isFinished: Bool { !collecting && pending == 0 }

    func collect(_ body: () -> Void) {
        collecting = true
        Self.$current.withValue(self, operation: body)
        collecting = false
        sealIfFinished()
    }

    static func record(_ task: Task<Void, Never>) {
        current?.hold(task)
    }

    func hold(_ task: Task<Void, Never>) {
        guard reserve() else { return }
        follow(task)
    }

    func reserve() -> Bool {
        guard !sealed else { return false }
        pending += 1
        return true
    }

    func follow(_ task: Task<Void, Never>) {
        Task.immediate { @MainActor in
            await task.value
            pending -= 1
            sealIfFinished()
        }
    }

    private func sealIfFinished() {
        if isFinished { sealed = true }
    }
}
