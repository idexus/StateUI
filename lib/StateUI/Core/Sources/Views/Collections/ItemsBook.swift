// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Each occurrence keeps its token while it remains in the list; allocated tokens are never reused.
// Design: docs/design/views/items.md#identities-in-order
final class ItemsBook<ID: Hashable> {
    var items: [ID: [String]] = [:]
    var sections: [AnyHashable: [String]] = [:]
    private var nextItem = 1
    private var nextSection = 1

    @MainActor func item() -> String {
        defer { nextItem += 1 }
        Renderer.shared.texts += 1
        return "\u{1D}i\(nextItem)"
    }

    @MainActor func section() -> String {
        defer { nextSection += 1 }
        Renderer.shared.texts += 1
        return "\u{1D}s\(nextSection)"
    }
}
