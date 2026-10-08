// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension Registry {
    /// Applies what changed of `element` to its view through its registration: each member as the element presents
    /// it (`MountedElement.presented`), carried in where a state the host carries holds it - the same on every host.
    /// Design: docs/design/host/runtime.md#a-disabled-branch
    @MainActor
    @discardableResult
    public func apply(_ changed: Set<Prop>, to view: View, presenting element: MountedElement) -> Set<Prop> {
        apply(
            changed, to: view, of: element.type,
            reading: { [element] in element.presented($0) },
            carriedIn: { [element] in element.driven[$0]?.mode == .in })
    }
}
