// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A package another connection indexes as another host: its folder, as a file URI, and that host - none, plain
/// Swift.
public struct IndexConflict: Codable, Equatable, Sendable {
    public var rootUri: String
    public var host: HostFamily?

    /// `rootUri`, indexed as `host` by another connection.
    public init(rootUri: String, host: HostFamily?) {
        self.rootUri = rootUri
        self.host = host
    }
}

/// The packages a connection indexes as one host, for as long as it lives - `index/acquire`'s result: the lease
/// taken, or the conflict that kept it from being taken, its former lease kept.
public struct IndexLease: Codable, Equatable, Sendable {
    public var host: HostFamily?
    /// The packages held, as file URIs: none where a conflict stood.
    public var rootUris: [String]
    public var conflict: IndexConflict?

    /// `rootUris` held as `host`, or `conflict`.
    public init(host: HostFamily?, rootUris: [String], conflict: IndexConflict? = nil) {
        self.host = host
        self.rootUris = rootUris
        self.conflict = conflict
    }
}
