// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The parameters naming a project: `project/describe`'s.
public struct ProjectReference: Codable, Equatable, Sendable {
    /// The project's root, or a folder in it, as a file URI; the connection's workspace when left out.
    public var projectUri: String?

    /// The project at `projectUri`.
    public init(projectUri: String? = nil) {
        self.projectUri = projectUri
    }
}
