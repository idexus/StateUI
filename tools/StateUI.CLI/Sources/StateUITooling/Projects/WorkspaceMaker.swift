// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A new workspace: a folder with its `stateui.json`, the library it names - a checkout, or a release cloned into
/// it - and a `.gitignore` for what builds write.
/// Design: docs/design/tooling/projects.md#a-new-workspace
public struct WorkspaceMaker: Sendable {
    /// The StateUI a workspace's applications build with.
    public enum Library: Sendable {
        /// A checkout on this machine.
        case checkout(URL)
        /// A release of a repository, cloned into the workspace's `StateUI/`.
        case release(String, repository: String)
    }

    /// A maker.
    public init() {}

    /// Why `name` cannot name a workspace's folder, or `nil`: every build tool takes its path.
    public static func problem(with name: String) -> String? {
        name.wholeMatch(of: /[A-Za-z0-9][A-Za-z0-9._-]*/) == nil
            ? "'\(name)' cannot name a workspace: letters, digits, dots, hyphens and underscores, starting with a letter"
                + " or a digit."
            : nil
    }

    /// Makes workspace `name` in `parent` building with `library`, written beside and put in place whole, then its
    /// first application `application`.
    public func make(_ name: String, in parent: URL, library: Library, application: String?) async throws -> WorkspaceChange {
        if let problem = Self.problem(with: name) { throw ToolingError(.invalidName, problem) }
        if let application, let problem = ApplicationMaker.problem(with: application) {
            throw ToolingError(.invalidName, problem)
        }
        let files = FileManager.default
        try? files.createDirectory(at: parent, withIntermediateDirectories: true)
        let destination = RealPath.of(parent).appendingPathComponent(name)
        if let held = try? files.contentsOfDirectory(atPath: destination.path), !held.isEmpty {
            throw ToolingError(.alreadyExists, "\(destination.path) already holds files.")
        }
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(name).stateui-new-\(UUID().uuidString.lowercased())")
        let path: String
        var cloned = false
        do {
            try files.createDirectory(at: staging, withIntermediateDirectories: true)
            switch library {
            case .checkout(let checkout):
                guard Checkout(at: checkout) != nil else {
                    throw ToolingError(.projectNotFound, "No StateUI checkout stands at \(checkout.path).")
                }
                path = ApplicationMaker.relativePath(from: destination, to: checkout)
            case .release(let release, let repository):
                _ = try await ReleaseCatalog().clone(release, of: repository, into: staging.appendingPathComponent("StateUI"))
                path = "StateUI"
                cloned = true
            }
            try Self.ignored(cloned: cloned).write(to: staging.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
            try WorkspaceFile(library: .init(path: path), projects: []).write(to: staging.appendingPathComponent(WorkspaceFile.name))
            if files.fileExists(atPath: destination.path) { try files.removeItem(at: destination) }
            try files.moveItem(at: staging, to: destination)
        } catch {
            try? files.removeItem(at: staging)
            throw error
        }
        var changed = [FileURI.string(destination)]
        if let application {
            var workspace = Workspace(folder: destination, file: try WorkspaceFile.read(destination.appendingPathComponent(WorkspaceFile.name)))
            let made = try ApplicationMaker().make(application, in: destination, from: workspace.library!)
            try workspace.add(made)
            changed.append(FileURI.string(made))
        }
        return WorkspaceChange(workspaceUri: FileURI.string(destination), library: path, changedUris: changed)
    }

    /// The `.gitignore` of a new workspace: what builds and tools write, and a release cloned into it.
    static func ignored(cloned: Bool) -> String {
        """
        # What builds write: SwiftPM's .build, one per host, and Gradle's beside a head.
        .build*/
        .gradle/
        # The language server's settings and the stateui tool's own state.
        .sourcekit-lsp/
        .stateui/
        # What `stateui package` lays out.
        /artifacts/
        *.dSYM/
        *.pdb
        .DS_Store

        """ + (cloned ? "# The StateUI release cloned here: stateui workspace library --release <release>\n/StateUI/\n" : "")
    }
}
