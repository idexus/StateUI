// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

extension ToolingService {
    /// What was chosen in the project `folder` stands in - `settings/get`: its workspace's application to start, and
    /// the host and devices of `application`, else of the one the project means - none where it means several.
    /// Design: docs/design/tooling/projects.md#what-was-chosen
    public func settings(in folder: URL, application: String?) throws -> Settings {
        let folder = RealPath.of(RealPath.lexical(folder))
        let workspace = try Workspace.nearest(from: folder)
        var answer = Settings()
        if let workspace {
            answer.workspaceUri = FileURI.string(workspace.folder)
            answer.startup = try workspace.startup()?.lastPathComponent
        }
        let meant: URL?
        do {
            meant = try ProjectReader.applicationFolder(named: application, containing: folder)
        } catch {
            guard application == nil, workspace != nil, error.code == .invalidConfiguration else { throw error }
            meant = nil
        }
        if let meant {
            let chosen = try ApplicationSettings.read(in: meant)
            answer.applicationUri = FileURI.string(meant)
            answer.host = chosen.host
            answer.devices = chosen.devices
        }
        return answer
    }

    /// Makes the choices `change` says - `settings/set` - and answers what is chosen then: the workspace's application
    /// to start, one it lists; the application's host, one it has a head for; the device of that host.
    /// Design: docs/design/tooling/projects.md#what-was-chosen
    public func changeSettings(_ change: SettingsChange, in folder: URL) throws -> Settings {
        let folder = RealPath.of(RealPath.lexical(folder))
        if let startup = change.startup {
            guard let workspace = try Workspace.nearest(from: folder) else {
                throw ToolingError(.invalidConfiguration, "No workspace stands in or above \(folder.path): an application alone starts itself.")
            }
            let listed = zip(workspace.file.projects, try workspace.applications())
            guard let path = listed.first(where: { $0.1.lastPathComponent == startup })?.0 else {
                let names = listed.map(\.1.lastPathComponent).joined(separator: ", ")
                throw ToolingError(.invalidConfiguration, "The workspace lists no \(startup); it lists \(names).")
            }
            try WorkspaceSettings(startup: path).write(to: WorkspaceSettings.file(in: workspace.folder))
        }
        if change.host != nil || change.device != nil {
            let application = try ProjectReader.applicationFolder(named: change.application, containing: folder)
            var chosen = try ApplicationSettings.read(in: application)
            if let host = change.host {
                guard ProjectReader.hosts(of: application).contains(host) else {
                    throw ToolingError(.invalidConfiguration, "\(application.lastPathComponent) has no \(host.rawValue) head.")
                }
                chosen.host = host
            }
            if let device = change.device {
                guard let host = change.host ?? chosen.host else {
                    throw ToolingError(.invalidConfiguration, "Name the host the device is for, or choose one first.")
                }
                chosen.devices[host.rawValue] = device
            }
            try chosen.write(to: ApplicationSettings.file(in: application))
        }
        return try settings(in: folder, application: change.application)
    }
}
