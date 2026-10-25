// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the user shares from a window: words or a link handed to the platform's share sheet.
// Design: docs/design/core/acts.md#sharing

extension WindowSession {
    /// Offers `text` to the platform's share sheet over this window - a message, a mail, a note - for the user to
    /// send where they choose.
    ///
    ///     Button("Share").onClicked(.ignoreWhileRunning) { try await window.share(text: summary) }
    ///
    /// - Returns: whether the user shared it; false where they cancelled.
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` where the platform has no share sheet.
    @discardableResult
    public func share(text: String) async throws -> Bool {
        try await shared(text, nil)
    }

    /// Offers a link to the platform's share sheet over this window.
    ///
    ///     try await window.share(link: "https://www.swift.org")
    @discardableResult
    public func share(link: String) async throws -> Bool {
        try await shared(nil, link)
    }

    /// Offers words and the link they speak of, together, to the platform's share sheet over this window.
    ///
    ///     try await window.share(text: "The talk I mentioned", link: talk)
    @discardableResult
    public func share(text: String, link: String) async throws -> Bool {
        try await shared(text, link)
    }

    /// Offers what is given to the share sheet; at least one of them is, as the overloads take it.
    private func shared(_ text: String?, _ link: String?) async throws -> Bool {
        let (scene, window) = try address
        return try await stateUICall(ApplicationContract.share, scene, window, text, link)
    }
}
