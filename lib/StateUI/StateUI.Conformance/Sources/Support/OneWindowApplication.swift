// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// The smallest complete application around one page: one scene, one window.
public struct OneWindowApplication: Application, Sendable {
    /// The page, built again each time the window is - any test's view, which enters the window by its node.
    let page: @MainActor () -> any View

    /// An application showing `page` in its one window.
    public init(@ViewBuilder page: @escaping @MainActor () -> any View) {
        self.page = page
    }

    public var body: some Scene { WindowGroup { ModifiedContent(node: page().node) } }
}
