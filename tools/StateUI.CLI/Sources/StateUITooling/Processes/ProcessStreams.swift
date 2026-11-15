// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a program's standard streams go, and what stopping it reaches.
public enum ProcessStreams: Sendable, Equatable {
    /// The program reads nothing and its output comes to the runner line by line. It runs in a session of its own,
    /// apart from any terminal, so stopping it stops every program it started.
    case captured
    /// The program shares this tool's standard input, output and error, as a program a shell runs in the foreground.
    case terminal
}
