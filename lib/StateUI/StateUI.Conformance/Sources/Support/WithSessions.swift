// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A view handing what it shows the sessions of the window and the application it stands in - what a case's page,
/// written as a closure, reads no environment for.
struct WithSessions<Content: View>: View {
    @Environment(\.window) private var window
    @Environment(\.application) private var application
    private let content: (WindowSession, ApplicationSession) -> Content

    /// Shows `content`, handed the window's session and the application's.
    init(@ViewBuilder _ content: @escaping (WindowSession, ApplicationSession) -> Content) {
        self.content = content
    }

    var body: some View {
        content(window, application)
    }
}
