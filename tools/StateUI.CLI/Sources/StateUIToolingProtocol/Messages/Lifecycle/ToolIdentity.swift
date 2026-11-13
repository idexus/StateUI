// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A program taking part in the tooling API - the tool itself, or an editor's client - by name and release.
public struct ToolIdentity: Codable, Equatable, Sendable {
    /// The program's name, `stateui` for the tool.
    public var name: String
    /// The program's release.
    public var version: String

    /// A program's name and release.
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}
