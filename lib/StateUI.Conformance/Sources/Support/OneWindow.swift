// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// The window of a `OneWindowApplication`, its page built again each time the window is.
public struct OneWindow: Window {
    /// The page the window shows.
    public let content: @Sendable () -> any Page

    /// A window showing `content`.
    public init(content: @escaping @Sendable () -> any Page) {
        self.content = content
    }

    public var page: any Page { content() }
}
