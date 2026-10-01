// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// Insets travel as left, top, right, bottom.
    /// The presentation elements whose VIEWS THE HOST MAKES: a page and a
    /// split view are woven through its page machinery - a split view's report
    /// walks into its first child's page lifetime, which no contract describes
    /// - so a registration takes their values alone, and both the making and
    /// the arranging of their children stay the host's.
    static func presentation(_ registry: Registry<NSView>) {
        registry.add(PageContract.self, madeByHost: AppKitSingleChildView.self) { page in
            page.property(PageContract.padding) { view, padding in
                view.padding = Self.edgeInsets(padding)
            }
        }

        registry.add(SplitViewContract.self, madeByHost: AppKitSplitView.self) { split in
            split.property(SplitViewContract.isSidebarVisible) { view, visible in
                view.apply(presented: visible ?? false)
            }
        }
    }
}

#endif
