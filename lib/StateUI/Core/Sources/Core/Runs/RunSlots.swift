// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The runs of what an element's walk finds to run - its watches, its visual states, its making - each under a
/// key its element keeps from one render to the next.
/// Design: docs/design/core/runs.md#what-a-walk-runs
@MainActor
final class RunSlots {
    private var owners: [(key: String, owner: RunOwner)] = []

    /// Who starts the runs kept under `key`, made now if nobody does yet.
    func owner(_ key: String) -> RunOwner {
        if let kept = owners.first(where: { $0.key == key }) { return kept.owner }

        let owner = RunOwner()
        owners.append((key, owner))
        return owner
    }

    /// The element left: every run of it is superseded, in the order its key was first asked for.
    func orphan() {
        for entry in owners { entry.owner.orphan() }
    }
}
