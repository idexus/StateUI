// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What was chosen for a workspace on this machine, out of git: the application a run starts where none is named.
/// Design: docs/design/tooling/projects.md#what-was-chosen
public struct WorkspaceSettings: ToolFile, Equatable {
    public static let currentVersion = 1

    public var schemaVersion: Int
    /// The application chosen to start - its folder, as the workspace's `projects` names it.
    public var startup: String?

    /// A workspace's choices: `startup` to start.
    public init(startup: String? = nil) {
        schemaVersion = Self.currentVersion
        self.startup = startup
    }

    /// Where a workspace in `folder` keeps them: `.stateui/workspace-settings.json`.
    public static func file(in folder: URL) -> URL {
        folder.appendingPathComponent(".stateui").appendingPathComponent("workspace-settings.json")
    }

    /// What was chosen for the workspace in `folder`; nothing where no file stands.
    public static func read(in folder: URL) throws(ToolingError) -> WorkspaceSettings {
        let file = file(in: folder)
        return FileManager.default.fileExists(atPath: file.path) ? try read(file) : WorkspaceSettings()
    }
}
