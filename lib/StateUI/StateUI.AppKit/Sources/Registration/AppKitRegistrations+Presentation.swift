// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// The presentation elements whose VIEWS THE HOST MAKES: a split view is
    /// woven through its page machinery - its report walks into its first
    /// child's page lifetime, which no contract describes - so a registration
    /// takes its values alone, and both the making and the arranging of its
    /// children stay the host's.
    static func presentation(_ registry: Registry<NSView>) {
        registry.add(SplitViewContract.self, madeByHost: AppKitSplitView.self) { split in
            split.property(SplitViewContract.showsSidebar) { view, visible in
                view.apply(presented: visible ?? false)
            }
            split.property(SplitViewContract.sidebarBackground) { view, material in
                view.setSidebarGround(material?.propValue)
            }
        }
    }
}

#endif
