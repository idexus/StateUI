// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Aim {
    /// Scrolls the list until `item` stands where `anchor` says, as the
    /// platform scrolls.
    public func scrollTo<ID>(_ item: ID, anchor: ScrollAnchor = .nearest) async throws
    where Target == ItemsView<ID> {
        try await call(ItemsViewContract.scrollTo, String(describing: item), anchor)
    }

    /// Scrolls a list of groups until `item` of the group named `group` stands
    /// where `anchor` says.
    public func scrollTo<ID>(
        _ item: ID, inGroup group: some Hashable, anchor: ScrollAnchor = .nearest
    ) async throws where Target == ItemsView<ID> {
        try await call(ItemsViewContract.scrollTo, "\(group)\u{1F}\(item)", anchor)
    }
}
