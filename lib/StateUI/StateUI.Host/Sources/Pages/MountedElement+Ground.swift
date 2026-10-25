// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension MountedElement {
    /// What a surface laid over the page - a sheet, the sidebar sliding over the detail - stands on where the
    /// application says nothing of it: its window's background, which a host lays over its platform's own surface;
    /// empty for that surface alone.
    /// Design: docs/design/host/pages.md#a-pages-ground
    @MainActor public var overlaidGround: HostMaterial {
        HostMaterial(enclosing(type: .window)?.value(.background))
    }

    /// What this page says it stands on: its own background, else the nearest an arrangement on its path declares for
    /// its pages - on past a sheet to the view presenting it; nil where none says one, and for a sidebar's page, which
    /// stands on its sidebar's material.
    /// Design: docs/design/host/pages.md#a-pages-ground
    @MainActor public var pageBackground: HostValue? {
        if let own = value(.background) { return own }
        var (child, each) = (self, parent)
        while let element = each, element.type != .window {
            if element.type == .splitView, element.children.first === child { return nil }
            if element.isArrangement, let ground = element.value(.background) { return ground }
            (child, each) = (element, element.parent)
        }
        return nil
    }

    /// What a host draws behind this element: a page's background (`pageBackground`), none for an arrangement - its
    /// background is its pages' - and any other element's own.
    /// Design: docs/design/host/pages.md#a-pages-ground
    @MainActor public var drawnBackground: HostValue? {
        if isArrangement { return nil }
        return type == .page ? pageBackground : value(.background)
    }

    /// The pages a host draws the background of again as `changed` moves on this element: an arrangement's, whose
    /// background those that say none stand on; none for any other element.
    /// Design: docs/design/host/pages.md#a-pages-ground
    @MainActor public func pagesGroundedAnew(by changed: Set<Prop>) -> [MountedElement] {
        isArrangement && changed.contains(.background) ? pages : []
    }

    /// Whether this element arranges pages: a stack, tabs, a split view.
    @MainActor public var isArrangement: Bool {
        type != .page && NodeType.pageTypes.contains(type)
    }

    /// The split views in this element's tree, its sheets' among them: what a host grounds again as its window's
    /// background changes, as their sidebars over the detail stand on it.
    /// Design: docs/design/host/pages.md#a-sidebars-material
    @MainActor public var splitViews: [MountedElement] {
        (type == .splitView ? [self] : []) + children.flatMap(\.splitViews)
    }
}
