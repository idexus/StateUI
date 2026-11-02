// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Aim {
    /// Scrolls the list until `item` stands where `anchor` says, as the
    /// platform scrolls.
    ///
    /// The list finds the item itself, whatever section holds it, and throws where it holds no such item.
    public func scrollTo<ID>(_ item: ID, anchor: ScrollAnchor = .nearest) async throws
    where Target == ItemsView<ID> {
        try await call(ItemsViewContract.scrollTo, try identity(of: item), anchor)
    }

    /// The identity the list wrote for `item`; before the list is built, its words.
    private func identity<ID>(of item: ID) throws -> String where Target == ItemsView<ID> {
        guard let resolves = box.resolves else { return String(describing: item) }
        guard let identity = resolves(item).first else {
            throw StateUIError.noItem("\(item)")
        }
        return identity
    }
}
