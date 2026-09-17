// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)

/// The one mark that a native control is being written by the host - the
/// program's description applied, or the host moving a control itself - and
/// not moved by the reader.
///
/// While it stands, a control's own callback - an action, a delegate call, a
/// clip view's notification - is the write's echo and reports nothing, so an
/// application write never returns as a user event. A callback the platform
/// delivers after the write has returned is not covered by it; a control that
/// raises one - a pop-up menu opened for the program - marks it where it
/// opens.
@MainActor
enum AppKitProgramWrite {
    private static var depth = 0

    /// Whether the host is writing a native control right now.
    static var isWriting: Bool { depth > 0 }

    /// Runs `body` as the host's write: every native callback it raises inside
    /// is dropped.
    static func perform<Result>(_ body: () throws -> Result) rethrows -> Result {
        depth += 1
        defer { depth -= 1 }
        return try body()
    }
}
#endif
