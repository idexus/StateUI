// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The runs of what an element's walk finds to run - its watches, its visual states, its making - each under a
/// key its element keeps from one render to the next.
/// Design: docs/design/core/runs.md#what-a-walk-runs
@MainActor
final class RunSlots {
    private var slots: [String: RunSlot] = [:]

    /// The runs kept under `key`, begun now if none are.
    func slot(_ key: String) -> RunSlot {
        if let slot = slots[key] { return slot }

        let slot = RunSlot()
        slots[key] = slot
        return slot
    }

    /// The element left: every run of it is superseded.
    func orphan() {
        for slot in slots.values { slot.orphan() }
    }
}
