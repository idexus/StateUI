// A control of the application's OWN, declared once for every host that
// realizes it.
//
// This file is the whole Swift half, and it is the same wherever the gallery
// runs. What the light IS on screen each host says for itself, in
// Platforms/AppKit/Host and Platforms/Maui/Host.
//
// PUBLIC, because a host in the same process registers BY TYPE and lives in a
// module of its own - see GalleryContract.swift.

import StateUI

/// What the light can show.
///
/// A closed vocabulary, so it crosses as its member's number. The numbers are
/// this application's own contract, and every host's control mirrors them.
public enum TrafficSignal: Int32, CaseIterable, HostRepresentable {
    /// Red.
    case stop = 0

    /// Amber.
    case caution = 1

    /// Green.
    case go = 2
}

/// The gallery's own traffic light, declared: its node type, the tier it
/// wears, and its members, each with its value's type.
public enum TrafficLightContract: ElementContract {
    public static let nodeType: NodeType = "Gallery.TrafficLight"
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// Which lamp is lit.
    public static let signal = ElementProperty<Self, TrafficSignal>("signal")

    /// A lamp was tapped, with its index from the top.
    public static let lampTapped = ElementEvent<Self, Int>("lampTapped")

    public static let members: [any ContractMember] = [signal, lampTapped]
}

/// The Swift half of the traffic light: a view whose node its contract makes.
/// `setValue` writes its property and `onEvent` hears its event; margins,
/// alignment, opacity and gestures come with `View`.
public struct TrafficLight: View {
    public var node = Node(contract: TrafficLightContract.self)

    /// A light showing nothing until `signal(_:)` says what.
    public init() {}

    /// Which lamp is lit.
    public func signal(_ value: TrafficSignal) -> Self {
        setValue(TrafficLightContract.signal, value)
    }

    /// A lamp was tapped, with its index from the top.
    public func onLampTapped(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        onEvent(TrafficLightContract.lampTapped, handler)
    }
}
