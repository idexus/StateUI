// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Aim {
    /// Scrolls the list until `item` stands where `anchor` says, as the
    /// platform scrolls.
    ///
    /// The list finds the item itself - in a list of groups, the first group holding it - and throws where it
    /// holds no such item.
    public func scrollTo<ID>(_ item: ID, anchor: ScrollAnchor = .nearest) async throws
    where Target == ItemsView<ID> {
        try await call(ItemsViewContract.scrollTo, try identity(of: item, unbuilt: "\(item)", where: { _ in true }), anchor)
    }

    /// Scrolls a list of groups until `item` of the group named `group` stands
    /// where `anchor` says.
    public func scrollTo<ID>(
        _ item: ID, inGroup group: some Hashable, anchor: ScrollAnchor = .nearest
    ) async throws where Target == ItemsView<ID> {
        try await call(
            ItemsViewContract.scrollTo,
            try identity(of: item, unbuilt: "\(group)\u{1F}\(item)", where: { $0.hasPrefix("\(group)\u{1F}") }),
            anchor)
    }

    /// The identity the list wrote for `item` that `matches`; before the list is built, `unbuilt`.
    private func identity<ID>(of item: ID, unbuilt: String, where matches: (String) -> Bool) throws -> String
    where Target == ItemsView<ID> {
        guard let resolves = box.resolves else { return unbuilt }
        guard let identity = resolves(item).first(where: matches) else {
            throw StateUIError(message: "the list holds no item \(item) to scroll to")
        }
        return identity
    }
}
