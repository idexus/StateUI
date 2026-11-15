// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A built application installed where its host shows it, from the artifact a build published and never built again:
/// a GTK head's desktop entry and icon for the user. Installing is the one step of a run that changes the user's
/// profile, so it stands apart from the build.
/// Design: docs/design/tooling/gtk-heads.md#installing
public struct ApplicationInstaller: Sendable {
    private let environment: [String: String]
    private let home: URL

    /// An installer writing where `environment` names, else under `home`.
    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment, home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.environment = environment
        self.home = home
    }

    /// Installs the artifact at `artifact`.
    ///
    /// - Throws: ``ToolingError`` `NOT_FOUND` for a folder no build published, `INVALID_CONFIGURATION` for a host
    ///   installed as its run installs it.
    public func install(_ artifact: URL) async throws -> InstallResult {
        guard let data = try? Data(contentsOf: artifact.appendingPathComponent("artifact.json")),
              let manifest = try? JSONDecoder().decode(ArtifactManifest.self, from: data)
        else { throw ToolingError(.notFound, "\(artifact.path) holds no artifact.json: build it with stateui build.") }
        guard manifest.host == .gtk else {
            throw ToolingError(.invalidConfiguration, "A \(manifest.host.rawValue) head is installed as its run installs it; install takes GTK's.")
        }
        let application = try FileURI.url(manifest.applicationUri)
        let icon = application.appendingPathComponent("Resources/AppIcon/appicon_gnome.svg")
        guard let identifier = manifest.identifier, FileManager.default.fileExists(atPath: icon.path),
              let program = manifest.entryPoints.first
        else { return InstallResult(artifactUri: FileURI.string(artifact), writtenUris: []) }
        let written = try await GTKDesktop(environment: environment, home: home).register(
            name: manifest.applicationName ?? manifest.productName, program: artifact.appendingPathComponent(program),
            product: manifest.productName, identifier: identifier, icon: icon, schemes: GTKDesktop.schemes(of: application))
        return InstallResult(artifactUri: FileURI.string(artifact), writtenUris: written.map(FileURI.string))
    }
}
