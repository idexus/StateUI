// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// One run proving the members of two contracts, written once and stood in each one's family.
// Design: docs/design/host/conformance.md#a-case

@_spi(Host) import StateUI

extension ConformanceCase {
    /// The same run under `contract`'s family: proving that contract's members alone - an element's own, or a
    /// tier's - the rest of what it proved what it needs; under a tier's, named for its element.
    @MainActor
    public func proving(_ contract: any Contract.Type) -> ConformanceCase {
        let owns = { (covered: Covered) in (covered.tier ?? covered.element) == contract.name }
        let (own, rest) = (proves.filter(owns), proves.filter { !owns($0) })
        let element = own.first?.element ?? ""
        let named = contract is any Tier.Type && !name.hasPrefix("\(element).") ? "\(element).\(name)" : name
        return ConformanceCase(named, proves: own, needs: rest + needs, body)
    }
}

@_spi(Host) extension Array where Element == ConformanceCase {
    /// The cases proving any of `contract`'s members, each proving them alone.
    @MainActor
    public func proving(_ contract: any Contract.Type) -> [ConformanceCase] {
        map { $0.proving(contract) }.filter { !$0.proves.isEmpty }
    }
}
