// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The system's clipboard, which the user copies to and pastes from in every application - read as the application's
/// `clipboard`.
///
///     @Environment(\.application) private var application
///
///     Button("Copy the link").onClicked(gate: .ignoreWhileRunning) {
///         try await application.clipboard.write(text: link)
///     }
@MainActor
public struct Clipboard {
    /// Puts `text` on the clipboard, in place of whatever it held.
    public func write(text: String) async throws {
        try await stateUICall(ApplicationContract.writeClipboard, text)
    }

    /// The words on the clipboard; nil where it holds none. A browser asks the user before a page reads it, and
    /// throws where they refuse.
    ///
    ///     let pasted = try await application.clipboard.text()
    public func text() async throws -> String? {
        try await stateUICall(ApplicationContract.readClipboard)
    }
}

extension ApplicationSession {
    /// The system's clipboard: the words the user copies and pastes.
    public var clipboard: Clipboard { Clipboard() }
}
