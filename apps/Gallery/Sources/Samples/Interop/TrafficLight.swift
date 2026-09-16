// A control of the application's OWN, declared once for every host that
// realizes it.
//
// This file is the whole Swift half, and it is the same wherever the gallery
// runs. What the light IS on screen each host says for itself, in
// Platforms/AppKit/Host and Platforms/Maui/Host.

import StateUI

/// What the light can show.
///
/// A closed vocabulary, so it crosses as its member's number. The numbers are
/// this application's own contract, and every host's control mirrors them.
enum TrafficSignal: Int32, CaseIterable, HostRepresentable {
    /// Red.
    case stop = 0

    /// Amber.
    case caution = 1

    /// Green.
    case go = 2
}

/// The gallery's own traffic light, declared: its node type, the tier it
/// wears, and its members, each with its value's type.
enum TrafficLightContract: ElementContract {
    static let nodeType: NodeType = "Gallery.TrafficLight"
    static let tiers: [any Contract.Type] = [ViewContract.self]

    /// Which lamp is lit.
    static let signal = ElementProperty<Self, TrafficSignal>("signal")

    /// A lamp was tapped, with its index from the top.
    static let lampTapped = ElementEvent<Self, Int>("lampTapped")

    static let members: [any ContractMember] = [signal, lampTapped]
}

/// The Swift half of the traffic light: a view whose node its contract makes.
/// `setValue` writes its property and `onEvent` hears its event; margins,
/// alignment, opacity and gestures come with `View`.
struct TrafficLight: View {
    var node = Node(contract: TrafficLightContract.self)

    /// Which lamp is lit.
    func signal(_ value: TrafficSignal) -> Self {
        setValue(TrafficLightContract.signal, value)
    }

    /// A lamp was tapped, with its index from the top.
    func onLampTapped(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        onEvent(TrafficLightContract.lampTapped, handler)
    }
}
