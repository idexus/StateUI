// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A workspace: the folder of the nearest `stateui-workspace.json` up from a command's folder, and what its file says.
/// Design: docs/design/tooling/projects.md#a-workspace
struct Workspace: Sendable {
    /// The folder the file stands in.
    let folder: URL
    /// What the file says.
    var file: WorkspaceFile

    /// The workspace whose `stateui-workspace.json` is nearest up from `folder`, itself included.
    static func nearest(from folder: URL) throws(ToolingError) -> Workspace? {
        var current = RealPath.of(folder)
        while true {
            let file = current.appendingPathComponent(WorkspaceFile.name)
            if FileManager.default.fileExists(atPath: file.path) {
                return Workspace(folder: current, file: try WorkspaceFile.read(file))
            }
            guard let parent = Folders.parent(of: current) else { return nil }
            current = parent
        }
    }

    /// The folders of the applications the file lists, each one checked to be an application.
    func applications() throws(ToolingError) -> [URL] {
        try file.projects.map { (path: String) throws(ToolingError) -> URL in
            let folder = ApplicationMaker.folder(named: path, from: self.folder)
            guard ProjectReader.isApplication(folder) else {
                throw ToolingError(
                    .invalidConfiguration,
                    "\(self.folder.appendingPathComponent(WorkspaceFile.name).path) lists \(path), which holds no"
                        + " \(ApplicationFile.name) - no application.")
            }
            return folder
        }
    }

    /// The application a run starts where none is named: the one chosen on this machine, a folder the file lists.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a choice the file does not list.
    func startup() throws(ToolingError) -> URL? {
        guard let path = try WorkspaceSettings.read(in: folder).startup else { return nil }
        guard file.projects.contains(path) else {
            throw ToolingError(
                .invalidConfiguration,
                "\(WorkspaceSettings.file(in: folder).path) starts \(path), which the workspace does not list:"
                    + " choose another with `stateui settings --startup <application>`.")
        }
        return ApplicationMaker.folder(named: path, from: folder)
    }

    /// The checkout the file names for new applications.
    var library: URL? {
        file.library.map { ApplicationMaker.folder(named: $0.path, from: folder) }
    }

    /// Makes `checkout` the workspace's library: every listed application's manifest names it by the path from the
    /// application, then the file does.
    ///
    /// - Returns: The files rewritten.
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a manifest naming its checkout in a form the tool does
    ///   not write - nothing is rewritten then.
    mutating func use(_ checkout: URL) throws -> [URL] {
        let rewritten = try applications().compactMap { try ApplicationManifest.naming(checkout, in: $0) }
        for (manifest, text) in rewritten { try Data(text.utf8).write(to: manifest) }
        file.library = .init(path: ApplicationMaker.relativePath(from: folder, to: checkout))
        let own = folder.appendingPathComponent(WorkspaceFile.name)
        try file.write(to: own)
        return rewritten.map(\.manifest) + [own]
    }

    /// Lists `application` in the file and writes it, unless listed already.
    mutating func add(_ application: URL) throws {
        let path = ApplicationMaker.relativePath(from: folder, to: application)
        guard !file.projects.contains(path) else { return }
        file.projects.append(path)
        try file.write(to: folder.appendingPathComponent(WorkspaceFile.name))
    }
}
