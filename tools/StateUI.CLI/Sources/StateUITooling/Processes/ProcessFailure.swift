// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A program the runner could not run.
public enum ProcessFailure: Error, Sendable, Equatable {
    /// No such program on the search path or at the path.
    case notFound(String)
    /// The working directory could not be entered.
    case directoryUnusable(String)
    /// An empty argument on Windows, where the command line the program reads would lose it.
    case emptyArgument
    /// The system could not start or follow the program, for the reason given.
    case systemFailure(String)
}
