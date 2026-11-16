// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a project's library changed wrote: the project - a workspace or one application - the library it names now,
/// and every file and folder made or rewritten.
public struct LibraryChange: Codable, Equatable, Sendable {
    /// The project's folder, as a file URI.
    public var projectUri: String
    /// The library it names now, by the path from its folder: `../StateUI`.
    public var library: String
    /// What was made or rewritten, as file URIs.
    public var changedUris: [String]

    /// A change to the library of the project at `projectUri`.
    public init(projectUri: String, library: String, changedUris: [String]) {
        self.projectUri = projectUri
        self.library = library
        self.changedUris = changedUris
    }
}
