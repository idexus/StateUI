// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a member says about itself - read by the tables the library derives
/// from its contracts and by the guards that hold those contracts.
/// Design: docs/design/core/contracts.md#member-facts
struct MemberFacts: Equatable {
    enum Kind: Equatable {
        case property
        case event
        case act
    }

    /// Which of the three it is: a property, an event or an act.
    let kind: Kind

    /// Which layer realizes it; nil for an act.
    let layer: ElementLayer?

    /// Whether a change animates to the new value.
    let travels: Bool

    /// Whether a value no longer described is put back to the default.
    let cleared: Bool

    /// Which of a view's values it is, where the value cannot say.
    let moves: MotionValues

    /// What an application's own property says: it travels, it is cleared, no motion.
    static let undeclared = MemberFacts(kind: .property, layer: nil, travels: true, cleared: true, moves: [])
}

/// A member whose facts the library can read out of a list of members.
protocol DeclaredMember: ContractMember {
    /// What it says about itself.
    var facts: MemberFacts { get }
}

/// A property, read as the type of its value - for the guard of its round trip.
protocol PropertyMember: DeclaredMember {
    /// The type of the value the property holds.
    var valueType: any HostRepresentable.Type { get }
}

extension ElementProperty: PropertyMember {
    var facts: MemberFacts {
        MemberFacts(kind: .property, layer: layer, travels: travels, cleared: cleared, moves: moves)
    }

    var valueType: any HostRepresentable.Type { Value.self }
}

extension ElementEvent: DeclaredMember {
    /// An event's facts: its layer, and nothing a property's value says.
    var facts: MemberFacts {
        MemberFacts(kind: .event, layer: layer, travels: true, cleared: true, moves: [])
    }
}

extension ElementAct: DeclaredMember {
    /// An act's facts: none a layer or a value says.
    var facts: MemberFacts {
        MemberFacts(kind: .act, layer: nil, travels: true, cleared: true, moves: [])
    }
}
