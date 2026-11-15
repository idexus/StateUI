// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Output a client was not sent, said where it lies: never presented as a whole log.
public struct OutputGap: Codable, Equatable, Sendable {
    /// The stream the output came on.
    public var stream: StandardStream
    /// The stream's cursor before the output not sent.
    public var fromCursor: String
    /// The stream's cursor after it.
    public var toCursor: String
    /// Whether the output can still be read from the operation's log.
    public var replayAvailable: Bool

    /// A gap in `stream` between two cursors.
    public init(stream: StandardStream, fromCursor: String, toCursor: String, replayAvailable: Bool) {
        self.stream = stream
        self.fromCursor = fromCursor
        self.toCursor = toCursor
        self.replayAvailable = replayAvailable
    }
}
