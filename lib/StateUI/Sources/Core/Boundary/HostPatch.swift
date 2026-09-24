// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What changed about one element, and about the elements under it.
///
/// Every update field is empty or optional when it did not change, so an
/// element that is only carrying the path down to a changed child is two
/// fields wide. The one rule every host reads it by: **absence means
/// unchanged**. A property removed from an element is named explicitly in
/// `clearedProperties`; replacement is reserved for changes a control cannot
/// accept in place.
@_spi(Host) public struct HostPatch: Sendable {
    /// Stable identity used to find or retain the native control.
    public let id: ElementId

    /// The kind of native control or structural element this patch describes.
    public let type: NodeType

    /// The native control cannot be updated into what the node now says, so the
    /// host discards it and builds it again from this complete patch.
    ///
    /// Set when the element type changed, and for a property that has gone away
    /// which no host-neutral operation can put back - a member that says it is
    /// not `cleared`, and nothing else. Every other lost property is named in `clearedProperties`
    /// instead, which costs one property rather than the element and its subtree.
    public var replace = false

    /// Whether this render brings the complete element. Renderer-only merge
    /// bookkeeping; it is not part of the host contract and never crosses a
    /// typed boundary.
    var fresh = false

    /// Only the properties that changed. All of them when `replace` is set or
    /// the element is new.
    public var properties: [Prop: HostValue] = [:]

    /// The properties this element described last render and does not
    /// describe now, in name order.
    ///
    /// The host clears each one, so what the modifier stood for goes back to
    /// that native control's default. Without this a property that has gone
    /// away has nothing arriving to overwrite it, and the only honest answer
    /// left is to build the control again.
    public var clearedProperties: [Prop] = []

    /// The properties among `properties` the host is to move to rather than
    /// assign, and how. Empty on almost every patch there ever is.
    ///
    /// A moved property is ordinary in every other respect: its target is in
    /// `properties`, the differ compares it normally, and a host that ignores
    /// this field simply snaps to that target.
    public var transitions: [Prop: HostTransition] = [:]

    /// The properties driven to a state, sent whole whenever the set changed.
    ///
    /// Nil means unchanged; `.replace([:])` means forget every attachment.
    public var driven: HostDrivenUpdate?

    /// The complete event map, sent only when the set of handled events changed.
    /// Nil means unchanged; `.replace([:])` removes every handler.
    public var events: HostEventUpdate?

    /// How this element's children animate when it puts them somewhere new,
    /// sent when it changed and only by an element that places children.
    public var motion: HostLayoutMotion?

    /// Whether this element's children are recycled, or nil when unchanged.
    public var recycles: Bool?

    /// The recyclable subtree shape, or nil when unchanged. Zero means the
    /// subtree cannot be recycled.
    public var shape: UInt64?

    /// The sparse or complete change to this element's children.
    public var children: HostChildrenUpdate = .unchanged
}

/// A property transition accompanying its target value.
@_spi(Host) public struct HostTransition: Equatable, Sendable {
    /// How the property moves to its target.
    public let motion: Motion
}

/// A changed movement law for children placed by a layout.
@_spi(Host) public struct HostLayoutMotion: Equatable, Sendable {
    /// How the child placement moves.
    public let motion: Motion

    /// Which placement coordinates move under that law.
    public let lanes: MotionLanes
}

/// How a sparse patch changes an element's children.
@_spi(Host) public enum HostChildrenUpdate: Sendable {
    /// The children and their order did not change.
    case unchanged

    /// Only these existing or new descendants changed.
    case changed([HostPatch])

    /// The complete child arrangement, in this order.
    case arranged([HostPatch])
}

extension HostChildrenUpdate: RandomAccessCollection {
    /// The integer position of a patch in this update's payload.
    public typealias Index = Int

    /// The first index in the update's patch payload.
    public var startIndex: Int { patches.startIndex }

    /// One past the last index in the update's patch payload.
    public var endIndex: Int { patches.endIndex }

    /// A patch in the sparse or arranged payload.
    public subscript(position: Int) -> HostPatch { patches[position] }
}

/// How a sparse patch changes host-driven state attachments.
@_spi(Host) public enum HostDrivenUpdate: Sendable {
    /// Replaces the complete attachment map; an empty map removes every attachment.
    case replace([Prop: HostStateBinding])
}

/// How a sparse patch changes native event handlers.
@_spi(Host) public enum HostEventUpdate: Sendable {
    /// Replaces the complete event map; an empty map removes every handler.
    case replace([Event: Int32])
}
