// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Bytes that cannot be a frame.
public enum FramingError: Error, Equatable, Sendable {
    /// No blank line within the header's limit.
    case headerTooLong
    /// A header line that is not `Name: value`, or a `Content-Length` that is not one decimal number.
    case malformedHeader(String)
    /// A header with no `Content-Length`.
    case noContentLength
    /// A body longer than the limit, by the length its header gives.
    case bodyTooLong(Int)
}
