// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Announcements, as an act: something changed that the user is not looking at.
// Design: docs/design/core/acts.md#announcements

/// What the platform's screen reader says out loud, asked of the host.
public enum ScreenReader {
    /// Says something to the user now, whatever they were on.
    ///
    ///     try await ScreenReader.announce("5 results")
    ///
    /// For what changed without the user doing it - a search that finished, a row
    /// that went, work that ended. A screen reader has one voice and this takes it,
    /// cutting off whatever was being said, so announcing what the user's own tap
    /// already told them is worse than saying nothing. Nothing happens where no
    /// screen reader is running.
    ///
    /// - Parameter text: what to say, in the user's own language.
    public static nonisolated(nonsending) func announce(_ text: String) async throws {
        try await stateUICall(ApplicationContract.announce, text)
    }
}
