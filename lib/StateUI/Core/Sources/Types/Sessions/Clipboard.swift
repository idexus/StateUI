// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The system's clipboard, which the user copies to and pastes from in every application - read as the application's
/// `clipboard`.
///
///     @Environment(\.application) private var application
///
///     Button("Copy the link").onClicked(policy: .ignoreWhileRunning) {
///         try await application.clipboard.write(link)
///     }
@MainActor
public struct Clipboard {
    /// Puts `text` on the clipboard, in place of whatever it held.
    public func write(_ text: String) async throws {
        try await callAct(ApplicationContract.writeClipboard, text)
    }

    /// The words on the clipboard; nil where it holds none. It throws where the platform keeps them from the
    /// application: a browser asks the user before a page reads it, and Android lets only the window in focus read
    /// it.
    ///
    ///     let pasted = try await application.clipboard.read()
    public func read() async throws -> String? {
        try await callAct(ApplicationContract.readClipboard)
    }
}

extension ApplicationSession {
    /// The system's clipboard: the words the user copies and pastes.
    public var clipboard: Clipboard { Clipboard() }
}
