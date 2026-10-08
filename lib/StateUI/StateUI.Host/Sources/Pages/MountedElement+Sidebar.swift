// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension MountedElement {
    /// A split view's two materials for its sidebar: a change of either stands the sidebar again, said by the tree
    /// or written into a state the host carries.
    public static let sidebarMaterials: Set<Prop> = [.sidebarBackground, .flyoutBackground]

    /// What this split view's sidebar stands on: its flyout's material while it stands `over` the detail, its own
    /// beside it; empty where the split view says none - the platform's own there, never the window's over the
    /// detail.
    /// Design: docs/design/host/pages.md#a-sidebars-material
    @MainActor public func sidebarMaterial(over: Bool) -> HostMaterial {
        HostMaterial(value(over ? .flyoutBackground : .sidebarBackground))
    }

    /// Whether this split view gives its sidebar a material of its own, beside the detail or over it - the
    /// sidebar is then the application's to paint, not the platform's.
    /// Design: docs/design/host/pages.md#a-sidebars-material
    @MainActor public var paintsSidebar: Bool {
        !sidebarMaterial(over: false).isEmpty || !sidebarMaterial(over: true).isEmpty
    }
}
