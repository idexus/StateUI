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

    /// The split views in this element's tree, its sheets' among them: what a host grounds again as its window's
    /// background changes, as their sidebars over the detail stand on it.
    /// Design: docs/design/host/pages.md#a-sidebars-material
    @MainActor public var splitViews: [MountedElement] {
        (type == .splitView ? [self] : []) + children.flatMap(\.splitViews)
    }
}
