// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A program an element runs: a definition holding code the host runs for the element - a layout's arithmetic -
/// declared by a contract beside its properties, events and acts.
///
///     public static let layout = ElementProgram<Self, LayoutProgramDefinition>("layout", layer: .stateUI)
///
/// The library declares programs and makes their definitions; an application's contract declares none. A program
/// is no value: it does not animate, a state does not carry it, and a host is handed it typed.
/// Design: docs/design/core/contracts.md#a-program
public struct ElementProgram<Owner: Contract, Definition>: ContractMember {
    /// The program's name: the name of the static member holding it.
    public let name: String

    /// Which layer runs it.
    let layer: ElementLayer

    /// The key it is kept under on an element, made once: its owner's name, a dot, and its own.
    let key: KeyName

    /// A program declared in `Owner`, run by `layer`.
    init(_ name: String, layer: ElementLayer) {
        self.name = name
        self.layer = layer
        key = KeyName("\(Owner.name).\(name)")
        ContractNames.claim(Owner.self, named: KeyName(Owner.name))
    }
}

extension ElementProgram: KeyedMember {
    var memberKey: KeyName { key }
}

extension ElementProgram: DeclaredMember {
    /// A program's facts: its layer, and nothing a property's value says - it travels nowhere.
    var facts: MemberFacts {
        MemberFacts(kind: .program, layer: layer, travels: false, cleared: true, moves: [])
    }
}
