// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a suite of the repository's own came to, phase by phase: its tests, then each record checked after them.
public struct SuiteResult: Codable, Equatable, Sendable {
    /// One phase and whether it passed.
    public struct Phase: Codable, Equatable, Sendable {
        public var name: String
        public var passed: Bool

        /// Phase `name`, passed or not.
        public init(name: String, passed: Bool) {
            self.name = name
            self.passed = passed
        }
    }

    /// The suite: `host:appkit`.
    public var suite: String
    public var phases: [Phase]
    /// What a build of the suite alone made, to run elsewhere, as a file URI: Android's test APK and its identity.
    public var artifactUri: String?

    /// Whether every phase passed.
    public var passed: Bool { phases.allSatisfy(\.passed) }

    /// Suite `suite`'s phases, and what its build alone made.
    public init(suite: String, phases: [Phase], artifactUri: String? = nil) {
        self.suite = suite
        self.phases = phases
        self.artifactUri = artifactUri
    }
}
