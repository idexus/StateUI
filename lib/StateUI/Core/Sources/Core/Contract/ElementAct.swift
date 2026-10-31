// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An act a host performs: its name, and the types of its arguments and its
/// answer.
///
///     static let flash = ElementAct<Self, Int, Void>("flash")
///     static let batteryLevel = ElementAct<Self, Void, (Double, Bool)>("batteryLevel")
///
/// Declared in an element's contract, it is performed on one element of that
/// kind: `Aim.call` puts the aimed element first. Declared in an
/// `ApplicationTier`, it aims at nothing: `stateUICall`.
public struct ElementAct<Owner: Contract, Arguments, Answer>: ContractMember {
    /// The act's name: what crosses the boundary.
    public let name: String

    /// An act declared in `Owner`.
    ///
    /// - Parameter name: its name - the name of the static member holding it.
    public init(_ name: String) {
        self.name = name
        token = Act(name)
        owner = KeyName(Owner.name)
    }

    /// The key the act crosses the boundary under, made once.
    @_spi(Host) public let token: Act

    /// The key of the contract declaring it, made once.
    @_spi(Host) public let owner: KeyName
}
