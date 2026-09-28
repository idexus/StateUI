// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The contract of one node type: the element the tree describes, every member
/// it has, and which layer realizes it.
///
///     enum TrafficLightContract: ElementContract {
///         static let nodeType: NodeType = "Gallery.TrafficLight"
///         static let tiers: [any Contract.Type] = [ViewContract.self]
///
///         static let signal = ElementProperty<Self, TrafficSignal>("signal")
///
///         static let members: [any ContractMember] = [signal]
///     }
///
///     struct TrafficLight: View {
///         var node = Node(contract: TrafficLightContract.self)
///
///         func signal(_ value: TrafficSignal) -> Self {
///             setValue(TrafficLightContract.signal, value)
///         }
///     }
///
/// Every element exists through its contract: its view builds its node from
/// it, its modifiers write its members, and a host realizes it member by
/// member.
public protocol ElementContract: Contract {
    /// The node type this contract declares.
    static var nodeType: NodeType { get }

    /// Which layer realizes the element.
    static var layer: ElementLayer { get }
}

extension ElementContract {
    /// The node type's name.
    public static var name: String { nodeType.name }

    /// An application's own element, realized by the application's hosts.
    public static var layer: ElementLayer { .provider }
}
