// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A StateUI checkout an application builds with.
public struct Library: Codable, Equatable, Sendable {
    /// Its root, as a file URI.
    public var rootUri: String
    /// The release it states, such as `0.8.5`.
    public var release: String?
    /// The commit it stands at, where it is a Git working tree.
    public var revision: String?
    /// Whether tracked files differ from that commit.
    public var dirty: Bool?

    /// A checkout at `rootUri`.
    public init(rootUri: String, release: String?, revision: String?, dirty: Bool?) {
        self.rootUri = rootUri
        self.release = release
        self.revision = revision
        self.dirty = dirty
    }
}
