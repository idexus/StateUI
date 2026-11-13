// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The work every client of the tool asks for, by the tooling API's methods: the terminal's commands and an
/// editor's JSON-RPC requests both call it.
public struct ToolingService: Sendable {
    /// A service for this process.
    public init() {}

    /// The tool's name and release.
    public static let identity = ToolIdentity(name: "stateui", version: Release.version)

    /// The tool's name, release, API versions and machine - `server/info`.
    public func serverInfo() -> ServerInfo {
        ServerInfo(server: Self.identity, apiVersions: Release.apiVersions, machine: .current)
    }

    /// The project holding `folder` - `project/describe`.
    public func describeProject(containing folder: URL) async throws -> Project {
        try await ProjectReader().describe(containing: folder)
    }

    /// Makes application `name` in `parent` from a checkout's HelloWorld - `checkout`, else the workspace's library,
    /// else the checkout `parent` stands in - and lists it in the workspace - `project/create`.
    public func createApplication(_ name: String, in parent: URL, from checkout: URL?) async throws -> ProjectCreation {
        var workspace = try Workspace.nearest(from: parent)
        guard let checkout = checkout ?? workspace?.library ?? Checkout.holding(parent)?.root else {
            throw ToolingError(
                .projectNotFound, "No StateUI checkout is named for \(parent.path): name one with --checkout, or in a"
                    + " stateui.json's library.")
        }
        let made = try ApplicationMaker().make(name, in: parent, from: checkout)
        var created = [FileURI.string(made)]
        if workspace != nil {
            try workspace?.add(made)
            created.append(FileURI.string(workspace!.folder.appendingPathComponent(WorkspaceFile.name)))
        }
        let project = try await ProjectReader().describe(containing: made)
        return ProjectCreation(project: project, createdUris: created)
    }

    /// What this machine has of every component it needs - `toolchain/check`.
    public func checkToolchain() async -> ToolchainReport {
        await Doctor().check()
    }

    /// The methods an editor calls, each answered by this service.
    public var methods: Methods {
        var methods = Methods()
        methods.query("server/info") { (_: NoParameters) in serverInfo() }
        methods.query("toolchain/check") { (_: NoParameters) in await checkToolchain() }
        methods.mutation("project/create") { (request: ApplicationRequest, _: OperationContext) in
            try await createApplication(
                request.name, in: try FileURI.url(request.parentUri), from: try request.checkoutUri.map(FileURI.url))
        }
        methods.query("project/describe") { (reference: ProjectReference, context: RequestContext) in
            guard let uri = reference.projectUri ?? context.workspaceUri else {
                throw ToolingError(.projectNotFound, "No project is named, and the connection opened no workspace.")
            }
            return try await describeProject(containing: try FileURI.url(uri))
        }
        return methods
    }
}
