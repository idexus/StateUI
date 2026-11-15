// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A workspace's library changed: `workspace/useLibrary`'s parameters.
public struct LibraryRequest: Codable, Equatable, Sendable {
    /// A folder of the workspace, as a file URI; the connection's workspace when left out.
    public var workspaceUri: String?
    /// The StateUI checkout its applications build with from now on; one of this or `release`.
    public var checkoutUri: String?
    /// A release cloned into the workspace for them to build with; one of this or `checkoutUri`.
    public var release: String?
    /// The repository a release is cloned from; StateUI's own when left out.
    public var repository: String?

    /// The library of the workspace at `workspaceUri`.
    public init(workspaceUri: String? = nil, checkoutUri: String? = nil, release: String? = nil, repository: String? = nil) {
        self.workspaceUri = workspaceUri
        self.checkoutUri = checkoutUri
        self.release = release
        self.repository = repository
    }
}
