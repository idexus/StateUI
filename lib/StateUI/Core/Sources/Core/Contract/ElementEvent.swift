// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An event an element reports: its name, and the types of what it carries.
///
///     static let lampTapped = ElementEvent<Self, Int>("lampTapped")
///     static let batteryChanged = ElementEvent<Self, (Double, Bool)>("batteryChanged")
///     static let closed = ElementEvent<Self, Void>("closed")
///
/// What it carries is positional - nothing, one value or a tuple of them, each
/// `HostRepresentable` - and a handler takes the values as its parameters:
///
///     onEvent(TrafficLightContract.lampTapped) { index in … }
public struct ElementEvent<Owner: Contract, Payload>: ContractMember {
    /// The event's name: what crosses the boundary.
    public let name: String

    /// Which layer reports it.
    let layer: ElementLayer

    /// An event declared in `Owner`.
    ///
    /// - Parameters:
    ///   - name: its name - the name of the static member holding it.
    ///   - layer: which layer reports it; an application's own unless said.
    public init(_ name: String, layer: ElementLayer = .provider) {
        self.name = name
        self.layer = layer
        token = Event(name)
        owner = KeyName(Owner.name)
    }

    /// The key the event crosses the boundary under, made once.
    @_spi(Host) public let token: Event

    /// The key of the contract declaring it, made once.
    @_spi(Host) public let owner: KeyName
}
