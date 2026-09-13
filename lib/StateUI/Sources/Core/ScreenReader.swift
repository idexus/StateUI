// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Saying something out loud.
//
// The modifiers say what a view IS, and the platform reads that when the
// reader arrives at it. This is the other half: something CHANGED that the
// reader is not looking at, and nothing on screen will announce itself.
//
//     items.removeAll { $0 == item }
//     try await SemanticScreenReader.announce("Row deleted")
//
// An ACT rather than a property, for the reason every act here is one: it is
// something that HAPPENS, at a moment, and no value on a tree can say "again".

/// What the platform's screen reader says out loud, asked of the host.
/// MAUI: SemanticScreenReader.
public enum SemanticScreenReader {
    /// Says something to the reader now, whatever they were on.
    /// MAUI: SemanticScreenReader.Announce.
    ///
    ///     try await SemanticScreenReader.announce("5 results")
    ///
    /// For what changed WITHOUT the reader doing it - a search that finished, a
    /// row that went, work that ended. A screen reader has one voice and this
    /// takes it, cutting off whatever was being said, so announcing what the
    /// reader's own tap already told them is worse than saying nothing.
    ///
    /// Nothing happens where no screen reader is running, which is the ordinary
    /// case: this is never how the application talks to everybody.
    ///
    /// - Parameter text: what to say, in the reader's own language.
    public static nonisolated(nonsending) func announce(_ text: String) async throws {
        try await stateUICall(.announce, [.string(text)])
    }
}
