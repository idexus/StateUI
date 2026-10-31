// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the application asks of the system as acts: an address launched, a word to the screen reader.
// Design: docs/design/core/acts.md#launching

extension ApplicationSession {
    /// Opens an address in the application the system gives it - a web page in the browser, a mail address in the
    /// mail application.
    ///
    ///     @Environment(\.application) private var application
    ///
    ///     Button("Swift").onClicked(.ignoreWhileRunning) { try await application.launch("https://www.swift.org") }
    ///
    /// - Parameter address: the address, its scheme included.
    /// - Returns: whether an application took it; false where none opens its scheme.
    @discardableResult
    public func launch(_ address: String) async throws -> Bool {
        try await stateUICall(ApplicationContract.launchLink, address)
    }

    /// Says something to the user through the platform's screen reader now, whatever they were on.
    ///
    ///     try await application.announce("5 results")
    ///
    /// For what changed without the user doing it - a search that finished, a row that went, work that ended. A
    /// screen reader has one voice and this takes it, cutting off whatever was being said, so announcing what the
    /// user's own tap already told them is worse than saying nothing. Nothing happens where no screen reader is
    /// running.
    ///
    /// - Parameter text: what to say, in the user's own language.
    public func announce(_ text: String) async throws {
        try await stateUICall(ApplicationContract.announce, text)
    }
}
