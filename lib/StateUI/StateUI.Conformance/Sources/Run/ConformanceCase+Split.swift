// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// One run proving an element's own members and a tier's, written once and stood in both families.
// Design: docs/design/host/conformance.md#a-case

@_spi(Host) import StateUI

extension ConformanceCase {
    /// The same run under the tier's family: proving the members of `tier` alone, named for its element, the rest
    /// of what it proved what it needs.
    @MainActor
    public func proving(_ tier: any Tier.Type) -> ConformanceCase {
        let (worn, rest) = (proves.filter { $0.tier == tier.name }, proves.filter { $0.tier != tier.name })
        let element = worn.first?.element ?? ""
        return ConformanceCase("\(element).\(name)", proves: worn, needs: rest + needs, body)
    }

    /// The same run under the element's family: proving the element's own members alone, a tier's what it needs.
    @MainActor
    public func provingOwn() -> ConformanceCase {
        let (own, worn) = (proves.filter { $0.tier == nil }, proves.filter { $0.tier != nil })
        return ConformanceCase(name, proves: own, needs: worn + needs, body)
    }
}
