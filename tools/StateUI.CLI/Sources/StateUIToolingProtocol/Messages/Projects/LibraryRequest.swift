// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The StateUI a project builds with, changed: `project/useLibrary`'s parameters. A workspace's applications take a
/// checkout or a release cloned into it; one application a checkout.
public struct LibraryRequest: Codable, Equatable, Sendable {
    /// A folder of the project, as a file URI; the connection's workspace when left out.
    public var projectUri: String?
    /// The StateUI checkout it builds with from now on; one of this or `release`.
    public var checkoutUri: String?
    /// A release cloned into the workspace for its applications to build with; one of this or `checkoutUri`.
    public var release: String?
    /// The repository a release is cloned from; StateUI's own when left out.
    public var repository: String?

    /// The library of the project at `projectUri`.
    public init(projectUri: String? = nil, checkoutUri: String? = nil, release: String? = nil, repository: String? = nil) {
        self.projectUri = projectUri
        self.checkoutUri = checkoutUri
        self.release = release
        self.repository = repository
    }
}
