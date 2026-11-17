// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The host an editor's language server indexes as, and the folders it holds: `index/describe`'s and `index/clean`'s
/// parameters - no host, the code as plain Swift.
public struct IndexQuery: Codable, Equatable, Sendable {
    public var host: HostFamily?
    /// The folders whose index is meant, as file URIs: `index/clean`'s.
    public var rootUris: [String]?

    /// The index of `host`, in `rootUris` where given.
    public init(host: HostFamily?, rootUris: [String]? = nil) {
        self.host = host
        self.rootUris = rootUris
    }
}

/// What a language server indexes a host's code with - the host's trait, SwiftPM's scratch folder, and the triple and
/// SDK it compiles for where the host's heads run elsewhere - and why it falls back to this machine where that SDK is
/// missing.
public struct IndexContext: Codable, Equatable, Sendable {
    public var host: HostFamily?
    /// The trait an application's own package enables to be indexed as the host - a head's package enables its own;
    /// nil for plain Swift.
    public var trait: String?
    /// The scratch folder, from a package's folder: `.build/uikit/index-build`.
    public var scratchPath: String
    public var triple: String?
    /// An Apple SDK's path: the iOS simulator's.
    public var sdk: String?
    /// A Swift SDK's id: `swift-6.4.2-RELEASE_android`.
    public var swiftSDK: String?
    /// Where the SDK the host compiles against is missing, why the code is indexed for this machine instead.
    public var fallback: String?

    /// The index of `host` in `scratchPath`, for `triple` against an SDK where given.
    public init(
        host: HostFamily?, trait: String? = nil, scratchPath: String, triple: String? = nil, sdk: String? = nil,
        swiftSDK: String? = nil, fallback: String? = nil
    ) {
        self.host = host
        self.trait = trait
        self.scratchPath = scratchPath
        self.triple = triple
        self.sdk = sdk
        self.swiftSDK = swiftSDK
        self.fallback = fallback
    }
}

/// The scratch folders `index/clean` took away.
public struct IndexCleaning: Codable, Equatable, Sendable {
    public var removedUris: [String]
    /// The roots another connection indexes, left as they stand; nil where there is none.
    public var conflicts: [IndexConflict]?

    /// The folders removed, and the roots left to the connections holding them.
    public init(removedUris: [String], conflicts: [IndexConflict]? = nil) {
        self.removedUris = removedUris
        self.conflicts = conflicts
    }
}
