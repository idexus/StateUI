// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The releases a repository publishes, newest first.
public struct ReleaseList: Codable, Equatable, Sendable {
    /// The repository read.
    public var repository: String
    /// Its releases from the minimum asked, newest first: `0.8.5`.
    public var releases: [String]

    /// The `releases` of `repository`.
    public init(repository: String, releases: [String]) {
        self.repository = repository
        self.releases = releases
    }
}
