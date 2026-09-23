// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The one mark that the program, not the user, is writing a native control.
/// Design: docs/design/host/patches.md#program-write
@_spi(Host) @MainActor public enum ProgramWrite {
    private static var depth = 0

    /// Whether the host is writing a native control right now.
    public static var isWriting: Bool { depth > 0 }

    /// Runs `body` as the program's write: a native callback raised inside reports nothing.
    public static func perform<Result>(_ body: () throws -> Result) rethrows -> Result {
        depth += 1
        defer { depth -= 1 }
        return try body()
    }
}
