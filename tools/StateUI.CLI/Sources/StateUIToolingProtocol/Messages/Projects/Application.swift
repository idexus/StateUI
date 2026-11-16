// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An application of a project: its package, the hosts it has heads for and the StateUI it builds with.
public struct Application: Codable, Equatable, Sendable {
    /// Its id within the project: its package's path from the project's root, `.` for the root itself.
    public var id: String
    /// Its name, which its products are named after: `Gallery`.
    public var name: String
    /// What names it to every platform, from its `stateui.json`: `com.stateui.gallery`.
    public var identifier: String
    /// The version shown to its user, from its `stateui.json`: `1.0.0`.
    public var version: String
    /// Its build, from its `stateui.json`: `1`.
    public var build: Int
    /// Its package's directory, as a file URI.
    public var packageUri: String
    /// The hosts it has a head for, in the hosts' order.
    public var declaredHosts: [HostFamily]
    /// Its package's products.
    public var products: [String]
    /// Its package's test targets.
    public var testSuites: [String]
    /// The root of the StateUI checkout its package depends on, as a file URI; none when it depends on none.
    public var libraryUri: String?

    /// An application of a project.
    public init(
        id: String, name: String, identifier: String, version: String, build: Int, packageUri: String,
        declaredHosts: [HostFamily], products: [String], testSuites: [String], libraryUri: String?
    ) {
        self.id = id
        self.name = name
        self.identifier = identifier
        self.version = version
        self.build = build
        self.packageUri = packageUri
        self.declaredHosts = declaredHosts
        self.products = products
        self.testSuites = testSuites
        self.libraryUri = libraryUri
    }
}
