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
/// `ApplicationTier`, it aims at nothing: `application.call`.
public struct ElementAct<Owner: Contract, Arguments, Answer>: ContractMember {
    /// The act's name: what crosses the boundary.
    public let name: String

    /// Which layer performs it.
    let layer: ElementLayer

    /// An act declared in `Owner`.
    ///
    /// - Parameters:
    ///   - name: its name - the name of the static member holding it.
    ///   - layer: which layer performs it; an application's own unless said.
    public init(_ name: String, layer: ElementLayer = .provider) {
        self.name = name
        self.layer = layer
        token = Act("\(Owner.name).\(name)")
        owner = KeyName(Owner.name)
        ContractNames.claim(Owner.self, named: owner)
    }

    /// The key the act crosses the boundary under, made once: its owner's name, a dot, and its own.
    @_spi(Host) public let token: Act

    /// The key of the contract declaring it, made once.
    @_spi(Host) public let owner: KeyName
}
