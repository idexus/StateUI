// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A workspace's file, `stateui-workspace.json`: the applications it lists, the StateUI they build with, and the
/// machines it declares for everyone who works on it.
/// Design: docs/design/tooling/projects.md#a-workspace
public struct WorkspaceFile: ToolFile, Equatable {
    /// The StateUI checkout a workspace's new applications build with.
    public struct LibraryReference: Codable, Equatable, Sendable {
        /// The checkout's folder, relative to the file.
        public var path: String

        /// The checkout at `path`.
        public init(path: String) {
            self.path = path
        }
    }

    /// The file's name, found upward from a command's folder.
    public static let name = "stateui-workspace.json"
    /// The version of the file's form this tool reads.
    public static let currentVersion = 1

    /// The version of the file's form.
    public var schemaVersion: Int
    /// The checkout new applications build with.
    public var library: LibraryReference?
    /// The applications' folders, relative to the file.
    public var projects: [String]
    /// The machines it declares (`stateui remote declare`).
    public var remotes: [DeclaredMachine]?

    /// A workspace listing `projects`, declaring `remotes`.
    public init(library: LibraryReference? = nil, projects: [String], remotes: [DeclaredMachine]? = nil) {
        schemaVersion = Self.currentVersion
        self.library = library
        self.projects = projects
        self.remotes = remotes
    }

    public var problem: String? {
        remotes.flatMap(DeclaredMachine.problem(of:))
    }

    /// Writes the file: its keys and projects in sorted order, a line break at its end - the same file every time.
    public func write(to url: URL) throws {
        var sorted = self
        sorted.projects.sort()
        try (ToolingJSON.encoder(pretty: true).encode(sorted) + Data("\n".utf8)).write(to: url)
    }
}
