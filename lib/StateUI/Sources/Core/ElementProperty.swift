// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A property of an element: its name, and the type of the value it holds.
///
///     static let signal = ElementProperty<Self, TrafficSignal>("signal")
///
/// `Owner` is the contract it is declared in, written `Self` there. `Value` is
/// what it holds, and what a modifier hands it:
///
///     func signal(_ value: TrafficSignal) -> Self {
///         setValue(TrafficLightContract.signal, value)
///     }
public struct ElementProperty<Owner: Contract, Value: HostRepresentable>: ContractMember {
    /// The property's name: what crosses the boundary.
    public let name: String

    /// Which layer realizes it.
    let layer: ElementLayer

    /// Whether a change animates to the new value - the default.
    /// Design: docs/design/core/contracts.md#member-facts
    let travels: Bool

    /// Whether a value no longer described is put back to the control's default.
    let cleared: Bool

    /// Which of a view's values it is, for `.motion(_:_:)`, where the value cannot say.
    let moves: MotionValues

    /// A property declared in `Owner`.
    ///
    /// - Parameters:
    ///   - name: its name - the name of the static member holding it.
    ///   - layer: which layer realizes it; an application's own unless said.
    ///   - travels: whether a change animates to the new value.
    ///   - cleared: whether a value no longer described is put back to the
    ///     control's default.
    ///   - moves: which of a view's values it is, where the value cannot say.
    public init(
        _ name: String,
        layer: ElementLayer = .provider,
        travels: Bool = true,
        cleared: Bool = true,
        moves: MotionValues = []
    ) {
        self.name = name
        self.layer = layer
        self.travels = travels
        self.cleared = cleared
        self.moves = moves
    }

    /// The key the property crosses the boundary under.
    @_spi(Host) public var token: Prop { Prop(name) }
}
