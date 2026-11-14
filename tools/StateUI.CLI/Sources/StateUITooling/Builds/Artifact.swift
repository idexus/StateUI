// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// `artifact.json`: what a build made, published whole once it was compiled, assembled and checked.
public struct ArtifactManifest: Codable, Equatable, Sendable {
    /// The version of this file's schema.
    public static let currentVersion = 1

    /// How a published artifact is signed.
    public enum Signing: String, Codable, Sendable {
        case none
        case adHoc
        case development
    }

    public var schemaVersion: Int
    /// `<host>-<context key>-<configuration>`: one artifact a build, replaced by the next.
    public var id: String
    public var producerOperationId: String
    public var createdAt: String
    /// The application, as a file URI of its folder.
    public var applicationUri: String
    public var host: HostFamily
    public var configuration: BuildConfiguration
    public var architecture: Architecture
    public var productName: String
    /// The programs it starts by, relative to its folder: `GalleryAppKit.app/Contents/MacOS/GalleryAppKit`.
    public var entryPoints: [String]
    public var signing: Signing
    /// The application's name: `Gallery`.
    public var applicationName: String?
    /// What the platform knows the application by: a bundle's identifier, an APK's package, a GTK application ID.
    public var identifier: String?

    /// The manifest of artifact `id`, made by operation `producerOperationId`.
    public init(
        schemaVersion: Int = ArtifactManifest.currentVersion, id: String, producerOperationId: String, createdAt: String,
        applicationUri: String, host: HostFamily, configuration: BuildConfiguration, architecture: Architecture,
        productName: String, entryPoints: [String], signing: Signing, applicationName: String? = nil, identifier: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.producerOperationId = producerOperationId
        self.createdAt = createdAt
        self.applicationUri = applicationUri
        self.host = host
        self.configuration = configuration
        self.architecture = architecture
        self.productName = productName
        self.entryPoints = entryPoints
        self.signing = signing
        self.applicationName = applicationName
        self.identifier = identifier
    }
}

/// An application's published artifacts and their staging: `<application>/.build/stateui/{artifacts,staging}/`.
/// An artifact is assembled in staging and published whole; a failed operation never replaces the last one.
/// Design: docs/design/tooling/builds.md#an-artifact-published-whole
public struct ArtifactStore: Sendable {
    /// The application's folder.
    public let application: URL

    /// The store of the application at `application`.
    public init(application: URL) {
        self.application = application
    }

    private var root: URL { application.appendingPathComponent(".build").appendingPathComponent("stateui") }

    /// The folder of the published artifact `id`.
    public func folder(of id: String) -> URL {
        root.appendingPathComponent("artifacts").appendingPathComponent(id)
    }

    /// A staging folder of its own for operation `operation`, empty.
    public func staging(for operation: String) throws -> URL {
        let staging = root.appendingPathComponent("staging").appendingPathComponent(operation)
        try? FileManager.default.removeItem(at: staging)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        return staging
    }

    /// Publishes `staging` as the artifact `manifest` describes - its `artifact.json` written in, then put in place
    /// of the last one at once - and answers its folder.
    public func publish(_ staging: URL, as manifest: ArtifactManifest) throws -> URL {
        let files = FileManager.default
        try (ToolingJSON.encoder(pretty: true).encode(manifest) + Data("\n".utf8))
            .write(to: staging.appendingPathComponent("artifact.json"))
        let destination = folder(of: manifest.id)
        try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let previous = destination.deletingLastPathComponent().appendingPathComponent(".\(manifest.id).old-\(UUID().uuidString)")
        if files.fileExists(atPath: destination.path) { try files.moveItem(at: destination, to: previous) }
        do {
            try files.moveItem(at: staging, to: destination)
        } catch {
            if files.fileExists(atPath: previous.path) { try? files.moveItem(at: previous, to: destination) }
            throw error
        }
        try? files.removeItem(at: previous)
        return destination
    }

    /// The published artifact `id`'s manifest, where one stands.
    public func manifest(of id: String) -> ArtifactManifest? {
        (try? Data(contentsOf: folder(of: id).appendingPathComponent("artifact.json")))
            .flatMap { try? ToolingJSON.decoder().decode(ArtifactManifest.self, from: $0) }
    }

    /// Drops `staging`, what a failed operation assembled.
    public func discard(_ staging: URL) {
        try? FileManager.default.removeItem(at: staging)
    }
}
