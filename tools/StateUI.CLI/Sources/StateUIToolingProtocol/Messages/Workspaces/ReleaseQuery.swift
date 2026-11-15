// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The releases asked for: `releases/list`'s parameters.
public struct ReleaseQuery: Codable, Equatable, Sendable {
    /// The oldest release wanted; the oldest the tool can make an application from when left out.
    public var minimum: String?
    /// The repository read, as Git names it; StateUI's own when left out.
    public var repository: String?

    /// Releases from `minimum` of `repository`.
    public init(minimum: String? = nil, repository: String? = nil) {
        self.minimum = minimum
        self.repository = repository
    }
}
