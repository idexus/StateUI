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

    /// The words this page's own bar shows as its title: its title, or - a sidebar's page that says none - the
    /// application's name, as a sidebar stands under it; nothing for any other page that says none.
    /// Design: docs/design/host/pages.md#a-sidebars-title
    @MainActor public func barTitle(applicationName: String) -> String {
        if let title = value(.title)?.string { return title }
        return standsInSidebar ? applicationName : ""
    }

    /// Whether this page stands in a split view's sidebar - its first child as written, or a stack's page there.
    @MainActor var standsInSidebar: Bool {
        var child = self
        while let parent = child.parent {
            switch parent.type {
            case .navigationStack: child = parent
            case .splitView: return parent.writingOrder[child.id] == 0
            default: return false
            }
        }
        return false
    }
}
