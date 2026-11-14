// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a host's conformance verdicts stand: each family, the revision its verdicts are to stand at, the files
/// recorded for it and whether they do - as the library's own reader of a revision says.
public struct ConformanceStatus: Codable, Equatable, Sendable {
    /// One family's verdicts.
    public struct Family: Codable, Equatable, Sendable {
        /// Whether the recorded verdicts stand at the family's revision, at another, are not recorded, or not read.
        public enum State: String, Codable, Sendable {
            case fresh, stale, missing, invalid
        }

        /// A verdict file, and the revision it names - none where it names none.
        public struct File: Codable, Equatable, Sendable {
            public var name: String
            public var revision: String?

            /// File `name`, at `revision`.
            public init(name: String, revision: String?) {
                self.name = name
                self.revision = revision
            }
        }

        public var name: String
        /// The revision its verdicts are to stand at: `1.1`.
        public var revision: String
        public var status: State
        public var files: [File]

        /// Family `name`, to stand at `revision`, its files recorded and how they stand.
        public init(name: String, revision: String, status: State, files: [File]) {
            self.name = name
            self.revision = revision
            self.status = status
            self.files = files
        }
    }

    public var host: HostFamily
    public var families: [Family]

    /// The families whose verdicts do not stand at their revision.
    public var stale: [Family] { families.filter { $0.status != .fresh } }

    /// `host`'s `families`.
    public init(host: HostFamily, families: [Family]) {
        self.host = host
        self.families = families
    }
}
