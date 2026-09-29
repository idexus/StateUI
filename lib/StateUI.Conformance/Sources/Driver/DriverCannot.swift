// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a driver cannot do on its host: an act on an element, or a read of one.
@_spi(Host) public struct DriverCannot: Error, Equatable, CustomStringConvertible {
    /// What cannot be done, as the driver's `cannot` names it: "step on Stepper", "read value of Stepper".
    public let ability: String

    /// Why it cannot be done at all on this host, where the platform keeps no such thing - a heading's level on a
    /// toolkit that marks only a heading; nil where the driver has no path for it yet.
    public var because: String? = nil

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

    /// What no driver can do on this host, and why: the platform keeps no such thing to read or do.
    public init(_ ability: String, because: String) {
        self.ability = ability
        self.because = because
    }

    public var description: String { ability }
}
