// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension MountedElement {
    /// What this split view's sidebar stands on: its flyout's material while it stands `over` the detail, its own
    /// beside it; empty where the split view says none - the platform's own there, never the window's over the
    /// detail.
    /// Design: docs/design/host/pages.md#a-sidebars-material
    @MainActor public func sidebarMaterial(over: Bool) -> HostMaterial {
        HostMaterial(value(over ? .flyoutBackground : .sidebarBackground))
    }
}
