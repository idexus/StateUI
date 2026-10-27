// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The members of the look a bar's items wear where a host draws the bar itself: the tiers only they wear -
/// `BarItemElement`'s and `BarButtonElement`'s - the room between the bar's groups and inside a group, and, on each
/// item, the box and the words its tiers shared with controls say - `BorderElement`'s, `PaddingElement`'s,
/// `TextColorElement`'s and `FontElement`'s. A host judges them all alike.
/// Design: docs/design/host/pages.md#a-bars-items-in-the-applications-look
@_spi(Host) public enum BarItemLook {
    /// Each member, on every item wearing it, realized in full.
    public static var realized: [HostRecord] {
        records(tier: { .complete($0) }, item: { .complete($0, on: $1) })
    }

    /// Each member, on every item wearing it, not planned on a host whose bar is the platform's own: `reason` says
    /// why.
    public static func notPlanned(reason: String) -> [HostRecord] {
        records(tier: { .notPlanned($0, reason: reason) }, item: { .notPlanned($0, on: $1, reason: reason) })
    }

    /// The records `tier` and `item` make of each member.
    private static func records(
        tier: (any ContractMember) -> HostRecord, item: (any ContractMember, any Contract.Type) -> HostRecord
    ) -> [HostRecord] {
        let own = BarItemElementContract.members + BarButtonElementContract.members
            + [BarElementContract.toolbarSpacing as any ContractMember]
        let box = BorderElementContract.members + PaddingElementContract.members
        let words = TextColorElementContract.members + FontElementContract.members
        let buttons: [any Contract.Type] = [ToolbarButtonContract.self, ToolbarToggleContract.self]
        let items: [any Contract.Type] = buttons + [ToolbarGroupContract.self]
        return own.map(tier)
            + [item(ToolbarGroupContract.spacing, ToolbarGroupContract.self)]
            + items.flatMap { element in box.map { item($0, element) } }
            + buttons.flatMap { element in words.map { item($0, element) } }
    }
}
