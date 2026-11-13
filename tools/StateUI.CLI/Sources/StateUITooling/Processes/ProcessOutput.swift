// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A line a captured program wrote, without its line break.
public struct ProcessOutput: Sendable, Equatable {
    /// One of a program's two output streams.
    public enum Stream: Sendable, Equatable {
        /// Standard output.
        case standardOutput
        /// Standard error.
        case standardError
    }

    /// The stream the line came on.
    public var stream: Stream
    /// The line; bytes that are not UTF-8 read as U+FFFD.
    public var text: String

    /// `text`, written on `stream`.
    public init(stream: Stream, text: String) {
        self.stream = stream
        self.text = text
    }
}
