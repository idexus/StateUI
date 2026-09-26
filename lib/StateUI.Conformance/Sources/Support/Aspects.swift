// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The cases a member of one kind owes on every element it is written on, written once: a property holds the value
/// the tree gives it, and the value the tree changes it to.
/// Design: docs/design/host/conformance.md#a-members-aspects
@_spi(Host) public enum Aspects {
    /// `member` of `element` holds the value the tree gives it, and then the one the tree changes it to; the
    /// specimen wears `with` too.
    public static func holds<Owner: Contract, Value: HostRepresentable & Sendable & Equatable>(
        _ member: ElementProperty<Owner, Value>, on element: String, _ first: Value, then second: Value,
        with worn: [any Worn] = []
    ) -> ConformanceCase {
        ConformanceCase("\(element).\(member.name).holdsWhatTheTreeGivesAndChanges", covers: [
            Covered(member, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let value = State(wrappedValue: first)
            s.start {
                Specimens.page(element, worn + [Write(member, value.wrappedValue)], beside: [
                    Button("Change").onClicked { value.wrappedValue = second }.id("change"),
                ])
            }
            let specimen = try s.specimen(element)
            s.expect(try s.held(member, on: specimen), first, "the value the tree gave")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(member, on: specimen) == second }
            s.expect(try s.held(member, on: specimen), second, "the value the tree changed it to")
        }
    }

    /// `member` of `element` holds the number the tree gives it, and then the one the tree changes it to, each to a
    /// millionth; the specimen wears `with` too.
    public static func holds<Owner: Contract>(
        _ member: ElementProperty<Owner, Double>, on element: String, _ first: Double, then second: Double,
        with worn: [any Worn] = []
    ) -> ConformanceCase {
        ConformanceCase("\(element).\(member.name).holdsWhatTheTreeGivesAndChanges", covers: [
            Covered(member, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let value = State(wrappedValue: first)
            s.start {
                Specimens.page(element, worn + [Write(member, value.wrappedValue)], beside: [
                    Button("Change").onClicked { value.wrappedValue = second }.id("change"),
                ])
            }
            let specimen = try s.specimen(element)
            s.expect(try s.held(member, on: specimen), first, within: 1e-6, "the number the tree gave")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { abs((try s.held(member, on: specimen) ?? .nan) - second) <= 1e-6 }
            s.expect(try s.held(member, on: specimen), second, within: 1e-6, "the number the tree changed it to")
        }
    }

    /// `member` holds, on every element wearing its tier, the value the tree gives it and then the one the tree
    /// changes it to.
    public static func holdsOnEveryWearer<Owner: Contract, Value: HostRepresentable & Sendable & Equatable>(
        _ member: ElementProperty<Owner, Value>, _ first: Value, then second: Value
    ) -> [ConformanceCase] {
        Specimens.wearing(Owner.self).map { holds(member, on: $0, first, then: second) }
    }

    /// `member` holds, on every element wearing its tier, the number the tree gives it and then the one the tree
    /// changes it to.
    public static func holdsOnEveryWearer<Owner: Contract>(
        _ member: ElementProperty<Owner, Double>, _ first: Double, then second: Double
    ) -> [ConformanceCase] {
        Specimens.wearing(Owner.self).map { holds(member, on: $0, first, then: second) }
    }
}
