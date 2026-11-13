// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The sizes a connection keeps its messages within.
public struct ConnectionLimits: Codable, Equatable, Sendable {
    /// The longest frame body, in bytes.
    public var maxFrameBytes: Int

    /// Limits of `maxFrameBytes`.
    public init(maxFrameBytes: Int) {
        self.maxFrameBytes = maxFrameBytes
    }

    /// The limits a connection of this tool keeps.
    public static let current = ConnectionLimits(maxFrameBytes: FrameReader.bodyLimit)
}
