// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A project: a folder of StateUI applications - one application, a StateUI checkout, or a group of them - and the
/// checkouts they build with. The answer of `project/describe` and `stateui project describe`.
public struct Project: Codable, Equatable, Sendable {
    /// Its root, as a file URI.
    public var rootUri: String
    /// Its applications, in the order of their ids.
    public var applications: [Application]
    /// The StateUI checkouts its applications build with, in the order of their roots.
    public var libraries: [Library]

    /// A project at `rootUri`.
    public init(rootUri: String, applications: [Application], libraries: [Library]) {
        self.rootUri = rootUri
        self.applications = applications
        self.libraries = libraries
    }
}
