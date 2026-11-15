// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The workspace a connection serves.
public struct Workspace: Codable, Equatable, Sendable {
    /// Its root, as a file URI.
    public var uri: String

    /// The workspace at `uri`.
    public init(uri: String) {
        self.uri = uri
    }
}
