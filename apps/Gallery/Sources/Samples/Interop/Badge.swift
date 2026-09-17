// A container of the application's OWN, declared once for every host that
// realizes it.
//
// This file is the whole Swift half, and it is the same wherever the gallery
// runs. What the badge IS on screen each host says for itself, beside its own
// head under Platforms/.

import StateUI

/// The gallery's own badge, declared: its node type, the tier it wears, and
/// its one member, with its value's type.
enum BadgeContract: ElementContract {
    static let nodeType: NodeType = "Gallery.Badge"
    static let tiers: [any Contract.Type] = [ViewContract.self]

    /// What the bubble says; at 0 the bubble hides. A count has no half way,
    /// so a change does not travel.
    static let count = ElementProperty<Self, Int>("count", travels: false)

    static let members: [any ContractMember] = [count]
}

/// The Swift half of the badge: a registered control holding content described
/// here.
///
/// What the closure builds travels as the node's child, and the host
/// reconciles it into the registration's one slot - created, patched and kept
/// by identity. One view, like any single-content control; a layout inside
/// holds more.
struct Badge: View {
    var node = Node(contract: BadgeContract.self)

    /// A badge with nothing under the bubble.
    init() {}

    /// A badge over what the closure describes.
    ///
    /// The closure runs as the badge is built, so a state it reads is read by
    /// the view that writes the badge.
    init(@ViewBuilder content: () -> [Element]) {
        node = Node(contract: BadgeContract.self, children: content().map { $0.body })
    }

    /// What the bubble says; at 0 the bubble hides.
    func count(_ value: Int) -> Self {
        setValue(BadgeContract.count, value)
    }
}
