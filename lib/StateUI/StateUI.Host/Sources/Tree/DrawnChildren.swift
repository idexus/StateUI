// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The children a registered view draws itself - a map's markers - handed to it alike on every host.
/// Design: docs/design/host/tree.md#children-a-view-draws
extension MountedElement {
    /// The one the host keeps for this element as a child its parent's view draws: its values read, its events
    /// raised and the user's values on it reported through it - the same object for as long as the element lives.
    ///
    /// - Parameter runtime: the runtime its events and values go to.
    /// - Returns: the kept child.
    public func asChild(in runtime: HostRuntime) -> HostChild {
        if let keptChild { return keptChild }

        let child = HostChild(
            reading: { [weak self] in self?.value($0) },
            sending: { [weak self, weak runtime] event, values in
                guard let runtime else { return }
                self?.send(event, values, in: runtime)
            },
            reporting: { [weak self, weak runtime] property, event, value in
                guard let runtime else { return }
                self?.reportUserChange(property, event, value, in: runtime) { _ in }
            })
        keptChild = child
        return child
    }

    /// Whether the element's parent's view draws it, so it has no view of its own.
    ///
    /// - Parameter registry: the host's registrations.
    public func isDrawnByParent<View: AnyObject>(in registry: Registry<View>) -> Bool {
        guard let parent else { return false }

        return registry.childTypes(of: parent.type).contains(type)
    }

    /// Hands the element's view every child it draws itself, where the last patch changed its children - the first
    /// included.
    ///
    /// - Parameters:
    ///   - view: the element's view.
    ///   - registry: the host's registrations.
    ///   - runtime: the runtime the children's events and values go to.
    public func applyDrawnChildren<View: AnyObject>(
        to view: View, through registry: Registry<View>, in runtime: HostRuntime
    ) {
        guard childrenChanged else { return }

        registry.applyChildren(to: view, of: type) { childType in
            children.filter { $0.type == childType }.map { $0.asChild(in: runtime) }
        }
    }
}
