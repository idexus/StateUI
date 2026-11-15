// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a name names, each with its own rule.
public enum NameKind: String, Codable, CaseIterable, Sendable {
    /// An application: a Swift module, a process, a package identifier and a folder.
    case application
    /// A workspace: a folder every build tool reads the path of.
    case workspace
}
