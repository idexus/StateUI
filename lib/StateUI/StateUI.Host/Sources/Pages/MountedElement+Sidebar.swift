// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension MountedElement {
    /// A split view's two materials for its sidebar: a change of either stands the sidebar again, said by the tree
    /// or written into a state the host carries.
    public static let sidebarMaterials: Set<Prop> = [.sidebarBackground, .flyoutBackground]

    /// What this split view's sidebar stands on: its flyout's material while it stands `over` the detail - else, as
    /// any surface over the page, its window's background (`overlaidGround`) - and its own beside it; empty where
    /// nothing is said - the platform's own there.
    /// Design: docs/design/host/pages.md#a-sidebars-material
    @MainActor public func sidebarMaterial(over: Bool) -> HostMaterial {
        let own = HostMaterial(value(over ? .flyoutBackground : .sidebarBackground))
        return over && own.isEmpty ? overlaidGround : own
    }

    /// Says whether this split view's sidebar lies `over` the detail, as the host stands it for the room, onto the
    /// state its place drives - where that changed since it last said, or the state is another. A host says it with
    /// the split view's frame, once laid out (`readsOwnFrame`).
    /// Design: docs/design/host/pages.md#where-a-sidebar-stands
    @MainActor public func reportSidebarOverlays(_ over: Bool, in runtime: HostRuntime) {
        guard let binding = driven[.sidebarOverlays],
              reportedOverlays.map({ $0.binding != binding || $0.over != over }) ?? true
        else { return }
        reportedOverlays = (binding, over)
        if !runtime.report(.lanes([over ? 1 : 0]), through: binding) { reportedOverlays = nil }
    }

    /// Whether this split view gives its sidebar a material of its own, beside the detail or over it - the
    /// sidebar is then the application's to paint, not the platform's.
    /// Design: docs/design/host/pages.md#a-sidebars-material
    @MainActor public var paintsSidebar: Bool {
        !HostMaterial(value(.sidebarBackground)).isEmpty || !HostMaterial(value(.flyoutBackground)).isEmpty
    }

    /// Whether this split view's bar offers the toggle showing and hiding its sidebar: unless it says it offers none.
    /// Design: docs/design/host/pages.md#the-windows-chrome
    @MainActor public var offersSidebarToggle: Bool {
        value(.showsSidebarToggle)?.bool != false
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
            case .navigationStack, .anchor: child = parent
            case .splitView: return parent.writingOrder[child.id] == 0
            default: return false
            }
        }
        return false
    }
}
