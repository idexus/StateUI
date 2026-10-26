// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The element a `PhaseLayout` stands on, its children placed by a run on its own area.
/// Design: docs/design/views/phase-layout.md#the-element
struct PlacedStack: Layout {
    var node: Node

    init<Content: Views>(@ViewBuilder content: @escaping () -> Content) {
        node = Node(contract: PhaseLayoutContract.self)
        node.producer = { content().nodes }
    }
}
