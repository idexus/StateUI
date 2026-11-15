// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a change to a workspace wrote: its folder, and every file and folder made or rewritten.
public struct WorkspaceChange: Codable, Equatable, Sendable {
    /// The workspace's folder, as a file URI.
    public var workspaceUri: String
    /// The library its file now names, as written there.
    public var library: String
    /// What was made or rewritten, as file URIs.
    public var changedUris: [String]

    /// A change to the workspace at `workspaceUri`.
    public init(workspaceUri: String, library: String, changedUris: [String]) {
        self.workspaceUri = workspaceUri
        self.library = library
        self.changedUris = changedUris
    }
}
