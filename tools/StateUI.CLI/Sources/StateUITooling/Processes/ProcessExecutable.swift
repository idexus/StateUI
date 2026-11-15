// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The program a request runs.
public enum ProcessExecutable: Sendable, Equatable {
    /// A program found by name on the search path, such as `swift`.
    case name(String)
    /// The program at a path.
    case path(String)
}
