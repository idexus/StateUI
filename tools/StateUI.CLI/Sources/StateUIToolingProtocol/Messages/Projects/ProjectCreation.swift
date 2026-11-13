// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What making a project made: the project it stands as, and the folders and files written.
public struct ProjectCreation: Codable, Equatable, Sendable {
    /// The new project, read as `project/describe` reads one.
    public var project: Project
    /// What was written, as file URIs.
    public var createdUris: [String]

    /// A creation of `project`, which wrote `createdUris`.
    public init(project: Project, createdUris: [String]) {
        self.project = project
        self.createdUris = createdUris
    }
}
