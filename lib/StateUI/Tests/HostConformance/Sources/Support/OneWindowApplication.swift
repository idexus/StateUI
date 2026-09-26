// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// The smallest complete application around one page: one scene, one window.
public struct OneWindowApplication: Application {
    /// The page, built again each time the window is.
    public let page: @Sendable () -> any Page

    /// An application showing `page` in its one window.
    public init(page: @escaping @Sendable () -> any Page) {
        self.page = page
    }

    public var scene: any Scene { OneWindow(content: page) }
}
