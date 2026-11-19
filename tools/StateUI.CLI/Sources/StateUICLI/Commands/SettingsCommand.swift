// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// `stateui settings`: what was chosen on this machine - the workspace's application to start, the application's host
/// and each host's device - shown, or changed where an option names a choice.
struct SettingsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "settings",
        abstract: "Shows what was chosen for a project on this machine, or chooses: the application to start, its host, a device.")

    @Option(help: "A folder of the project; the working directory when left out.")
    var project: String?

    @Option(help: "The application whose host and device are shown or chosen; the one the project means when left out.")
    var application: String?

    @Option(help: "The application the workspace starts.")
    var startup: String?

    @Option(help: "The host the application is built for.")
    var host: HostFamily?

    @Option(help: "The device - a simulator or device, an emulator, a browser - for --host, else for the host chosen.")
    var device: String?

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let folder = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)
        let changes = startup != nil || host != nil || device != nil
        try await output.answer({
            let service = ToolingService()
            guard changes else { return try service.settings(in: folder, application: application) }
            var devices: [String: String]?
            if let device {
                let chosenHost = try service.settings(in: folder, application: application).host
                guard let forHost = host ?? chosenHost else {
                    throw ToolingError(.invalidConfiguration, "Name the host the device is for with --host, or choose one first.")
                }
                devices = [forHost.rawValue: device]
            }
            return try service.changeSettings(
                SettingsChange(application: application, startup: startup, host: host, devices: devices), in: folder)
        }, text: Self.words)
    }

    static func words(_ settings: Settings) -> String {
        var lines: [String] = []
        if let workspace = settings.workspaceUri {
            lines.append((try? FileURI.url(workspace).path) ?? workspace)
            lines.append("  startup  \(settings.startup ?? "-")")
        }
        if let application = settings.applicationUri {
            lines.append((try? FileURI.url(application).path) ?? application)
            lines.append("  host     \(settings.host?.rawValue ?? "-")")
            for host in settings.devices.keys.sorted() {
                lines.append("  device   \(host) \(settings.devices[host] ?? "")")
            }
        }
        return lines.joined(separator: "\n")
    }
}
