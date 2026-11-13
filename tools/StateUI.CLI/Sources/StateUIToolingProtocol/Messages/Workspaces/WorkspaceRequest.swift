// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A new workspace asked for: `workspace/create`'s parameters.
public struct WorkspaceRequest: Codable, Equatable, Sendable {
    /// Its folder's name.
    public var name: String
    /// The folder it is made in, as a file URI.
    public var parentUri: String
    /// A StateUI checkout its applications build with, as a file URI; one of this or `release`.
    public var checkoutUri: String?
    /// A release cloned into the workspace for its applications to build with; one of this or `checkoutUri`.
    public var release: String?
    /// The repository a release is cloned from; StateUI's own when left out.
    public var repository: String?
    /// The name of a first application made in it.
    public var application: String?

    /// Workspace `name` in `parentUri`.
    public init(
        name: String, parentUri: String, checkoutUri: String? = nil, release: String? = nil, repository: String? = nil,
        application: String? = nil
    ) {
        self.name = name
        self.parentUri = parentUri
        self.checkoutUri = checkoutUri
        self.release = release
        self.repository = repository
        self.application = application
    }
}
