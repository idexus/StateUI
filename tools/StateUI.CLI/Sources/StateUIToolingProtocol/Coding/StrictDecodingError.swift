// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A message holding what its type does not read.
public struct StrictDecodingError: Error, Equatable, Sendable {
    /// Where each unread part stands, as a JSON pointer: `/params/extra`.
    public var unread: [String]
}
