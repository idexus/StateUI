// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A workspace's file, `stateui.json`: the applications it lists and the StateUI they build with.
/// Design: docs/design/tooling/projects.md#a-workspace
public struct WorkspaceFile: Codable, Equatable, Sendable {
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
    public static let name = "stateui.json"
    /// The version of the file's form this tool reads.
    public static let currentVersion = 1

    /// The version of the file's form.
    public var schemaVersion: Int
    /// The checkout new applications build with.
    public var library: LibraryReference?
    /// The applications' folders, relative to the file.
    public var projects: [String]
    /// The application a run starts when none is named.
    public var startup: String?

    /// A workspace listing `projects`.
    public init(library: LibraryReference? = nil, projects: [String], startup: String? = nil) {
        schemaVersion = Self.currentVersion
        self.library = library
        self.projects = projects
        self.startup = startup
    }

    /// The file at `url`, read whole.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` naming what cannot be read and where.
    public static func read(_ url: URL) throws(ToolingError) -> WorkspaceFile {
        let invalid = { (reason: String) in ToolingError(.invalidConfiguration, "\(url.path): \(reason)") }
        guard let data = try? Data(contentsOf: url) else { throw invalid("it cannot be read.") }
        guard let json = try? ToolingJSON.decoder().decode(JSONValue.self, from: data) else { throw invalid("it is not JSON.") }
        let file: WorkspaceFile
        do {
            file = try json.decode(WorkspaceFile.self)
        } catch let error as StrictDecodingError {
            throw invalid("it has no field \(error.unread.joined(separator: ", ")).")
        } catch {
            throw invalid("\(error)")
        }
        guard file.schemaVersion == currentVersion else {
            throw invalid("its schemaVersion \(file.schemaVersion) is not \(currentVersion), the one this tool reads.")
        }
        return file
    }

    /// Writes the file: its keys and projects in sorted order, a line break at its end - the same file every time.
    public func write(to url: URL) throws {
        var sorted = self
        sorted.projects.sort()
        try (ToolingJSON.encoder(pretty: true).encode(sorted) + Data("\n".utf8)).write(to: url)
    }
}
