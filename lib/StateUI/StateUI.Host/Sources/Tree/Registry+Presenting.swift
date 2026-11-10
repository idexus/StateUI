// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension Registry {
    /// Applies what changed of `element` to its view through its registration: each member as the element presents
    /// it (`MountedElement.presented`), carried in where a state the host carries holds it - the same on every host.
    /// A member the host shows only `atRest` is read where its state's journey lands, never on its way.
    /// Design: docs/design/host/runtime.md#a-disabled-branch
    @MainActor
    @discardableResult
    public func apply(
        _ changed: Set<Prop>, to view: View, presenting element: MountedElement,
        atRest: @escaping @MainActor (Prop) -> Bool = { _ in false }
    ) -> Set<Prop> {
        apply(
            changed, to: view, of: element.type,
            reading: { [weak element] property in
                guard let element else { return nil }
                return atRest(property)
                    ? element.destination(property) ?? element.presented(property) : element.presented(property)
            },
            carriedIn: { [weak element] in element?.driven[$0]?.mode == .in },
            heading: { [weak element] in element?.destination($0) })
    }
}
