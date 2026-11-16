// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A project: one application, or a workspace's applications, and the checkouts they build with. The answer of
/// `project/describe` and `stateui project describe`.
public struct Project: Codable, Equatable, Sendable {
    /// Its root, as a file URI.
    public var rootUri: String
    /// Its applications, in the order of their ids.
    public var applications: [Application]
    /// The StateUI checkouts its applications build with, in the order of their roots.
    public var libraries: [Library]
    /// The folder of the workspace it stands in - the nearest `stateui-workspace.json` up - as a file URI.
    public var workspaceUri: String?
    /// The folder of the application a run starts where none is named - the workspace's `startup` - as a file URI.
    public var startupUri: String?

    /// A project at `rootUri`.
    public init(
        rootUri: String, applications: [Application], libraries: [Library], workspaceUri: String? = nil,
        startupUri: String? = nil
    ) {
        self.rootUri = rootUri
        self.applications = applications
        self.libraries = libraries
        self.workspaceUri = workspaceUri
        self.startupUri = startupUri
    }
}
