// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What `swift package describe --type json` says of a package, as far as the tool reads it.
struct PackageDescription: Decodable, Sendable {
    struct Dependency: Decodable, Sendable {
        var identity: String
        var path: String?
    }

    struct Product: Decodable, Sendable {
        var name: String
    }

    struct Target: Decodable, Sendable {
        var name: String
        var type: String
    }

    var dependencies: [Dependency]
    var products: [Product]
    var targets: [Target]
}
