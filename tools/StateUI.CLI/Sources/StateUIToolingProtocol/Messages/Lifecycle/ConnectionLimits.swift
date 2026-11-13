// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The sizes a connection keeps its messages within.
public struct ConnectionLimits: Codable, Equatable, Sendable {
    /// The longest frame body, in bytes.
    public var maxFrameBytes: Int
    /// The most bytes of a program's output one event carries, before they are encoded.
    public var maxEventChunkBytes: Int

    /// Limits of `maxFrameBytes` and `maxEventChunkBytes`.
    public init(maxFrameBytes: Int, maxEventChunkBytes: Int) {
        self.maxFrameBytes = maxFrameBytes
        self.maxEventChunkBytes = maxEventChunkBytes
    }

    /// The limits a connection of this tool keeps.
    public static let current = ConnectionLimits(
        maxFrameBytes: FrameReader.bodyLimit, maxEventChunkBytes: OutputChunker.limit)
}
