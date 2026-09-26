// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a driver cannot do on its host: an act on an element, or a read of one.
@_spi(Host) public struct DriverCannot: Error, Equatable, CustomStringConvertible {
    /// What cannot be done, as the driver's `cannot` names it: "step on Stepper", "read value of Stepper".
    public let ability: String

    /// `act` on `element`, which the driver has no path for.
    @MainActor public init(_ act: UserAct, on element: MountedElement) {
        ability = "\(act) on \(element.type.name)"
    }

    /// `property` of `element`, which the driver cannot read.
    @MainActor public init(reading property: Prop, of element: MountedElement) {
        ability = "read \(property.name) of \(element.type.name)"
    }

    /// What a driver cannot do, said in its own words: "find the window", "read what is kept".
    public init(_ ability: String) {
        self.ability = ability
    }

    public var description: String { ability }
}
