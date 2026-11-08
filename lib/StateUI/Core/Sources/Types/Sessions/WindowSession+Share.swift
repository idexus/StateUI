// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the user shares from a window: words or an address handed to the platform's share sheet.
// Design: docs/design/core/acts.md#sharing

extension WindowSession {
    /// Offers `text` to the platform's share sheet over this window - a message, a mail, a note - for the user to
    /// send where they choose.
    ///
    ///     Button("Share").onClicked(policy: .ignoreWhileRunning) { try await window.share(text: summary) }
    ///
    /// - Returns: whether the user shared it; false where they cancelled.
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` where the platform has no share sheet.
    @discardableResult
    public func share(text: String) async throws -> Bool {
        try await shared(text, nil)
    }

    /// Offers an address to the platform's share sheet over this window.
    ///
    ///     try await window.share(address: "https://www.swift.org")
    @discardableResult
    public func share(address: String) async throws -> Bool {
        try await shared(nil, address)
    }

    /// Offers words and the address they speak of, together, to the platform's share sheet over this window.
    ///
    ///     try await window.share(text: "The talk I mentioned", address: talk)
    @discardableResult
    public func share(text: String, address: String) async throws -> Bool {
        try await shared(text, address)
    }

    /// Offers what is given to the share sheet; at least one of them is, as the overloads take it.
    private func shared(_ text: String?, _ shared: String?) async throws -> Bool {
        let (scene, window) = try address
        return try await callAct(ApplicationContract.share, scene, window, text, shared)
    }
}
