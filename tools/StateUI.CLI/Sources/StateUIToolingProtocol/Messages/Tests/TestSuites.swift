// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The host whose suites are asked for, and the folder that holds them: `tests/discover`'s parameters - no host,
/// every suite as plain Swift.
public struct TestDiscoveryQuery: Codable, Equatable, Sendable {
    public var host: HostFamily?
    /// The folder, as a file URI: the connection's own where left out.
    public var folderUri: String?

    /// The suites of `folderUri` for `host`.
    public init(host: HostFamily?, folderUri: String? = nil) {
        self.host = host
        self.folderUri = folderUri
    }
}

/// One suite a folder holds, and how it runs.
public struct TestSuiteDescription: Codable, Equatable, Sendable {
    /// A package's own tests, by `swift test`; or a host's suite, as `stateui repo test` runs it.
    public enum Kind: String, Codable, Sendable {
        case package, host
    }

    /// What names it: the package's path from the folder - `apps/Gallery` - the folder's own name for its root.
    public var id: String
    public var detail: String
    public var kind: Kind
    /// The package, as a file URI.
    public var packageUri: String
    /// The host it runs as: a host's suite's, or AppKit's for an application built as an AppKit head.
    public var host: HostFamily?
    /// Whether it runs on a device - an Android device, a simulator for UIKit - named when it runs.
    public var onDevice: Bool

    /// Suite `id` of `packageUri`.
    public init(id: String, detail: String, kind: Kind, packageUri: String, host: HostFamily? = nil, onDevice: Bool = false) {
        self.id = id
        self.detail = detail
        self.kind = kind
        self.packageUri = packageUri
        self.host = host
        self.onDevice = onDevice
    }
}

/// The suites a folder holds for a host, in the order they are best run: `tests/discover`'s result.
public struct TestSuiteList: Codable, Equatable, Sendable {
    public var host: HostFamily?
    public var suites: [TestSuiteDescription]

    /// `host`'s `suites`.
    public init(host: HostFamily?, suites: [TestSuiteDescription]) {
        self.host = host
        self.suites = suites
    }
}

/// One suite to run: `tests/run`'s parameters.
public struct TestRunRequest: Codable, Equatable, Sendable {
    /// The suite's id, as `tests/discover` gave it.
    public var suite: String
    public var host: HostFamily?
    /// A suite on a device: its device, simulator or emulator.
    public var device: String?
    public var folderUri: String?

    /// Suite `suite` of `folderUri` for `host`, on `device` where it runs on one.
    public init(suite: String, host: HostFamily?, device: String? = nil, folderUri: String? = nil) {
        self.suite = suite
        self.host = host
        self.device = device
        self.folderUri = folderUri
    }
}
