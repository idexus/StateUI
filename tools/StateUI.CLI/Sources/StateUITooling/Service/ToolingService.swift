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

    /// Why `name` cannot name a `kind` made in `parent` - its rule, or a folder already there - or a verdict taking
    /// it - `name/check`.
    public func checkName(_ name: String, of kind: NameKind, in parent: URL?) -> NameVerdict {
        let rule = switch kind {
        case .application: ApplicationMaker.problem(with: name)
        case .workspace: WorkspaceMaker.problem(with: name)
        }
        return NameVerdict(problem: rule ?? parent.flatMap { Folders.taken(RealPath.of($0).appendingPathComponent(name)) })
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

    /// The releases of `repository` from `minimum`, newest first - `releases/list`.
    public func listReleases(of repository: String?, from minimum: String?) async throws -> ReleaseList {
        let repository = repository ?? Release.repository
        let releases = try await ReleaseCatalog().releases(of: repository, from: minimum ?? Release.oldestUsable)
        return ReleaseList(repository: repository, releases: releases)
    }

    /// Makes workspace `name` in `parent`, building with `checkout` or `release`, with a first `application` -
    /// `workspace/create`.
    public func createWorkspace(
        _ name: String, in parent: URL, checkout: URL?, release: String?, repository: String?, application: String?
    ) async throws -> WorkspaceChange {
        try await WorkspaceMaker().make(
            name, in: parent, library: try Self.library(checkout, release, repository), application: application)
    }

    /// Makes `checkout` or `release` the library of the workspace `folder` stands in, rewriting its applications'
    /// manifests - `workspace/useLibrary`.
    public func useLibrary(in folder: URL, checkout: URL?, release: String?, repository: String?) async throws -> WorkspaceChange {
        guard var workspace = try Workspace.nearest(from: folder) else {
            throw ToolingError(.projectNotFound, "No stateui.json stands in or above \(folder.path).")
        }
        let library: URL
        switch try Self.library(checkout, release, repository) {
        case .checkout(let named):
            guard Checkout(at: named) != nil else {
                throw ToolingError(.projectNotFound, "No StateUI checkout stands at \(named.path).")
            }
            library = named
        case .release(let release, let repository):
            library = try await Self.replaceClone(in: workspace.folder, with: release, of: repository)
        }
        let rewritten = try workspace.use(library)
        return WorkspaceChange(
            workspaceUri: FileURI.string(workspace.folder), library: workspace.file.library?.path ?? "",
            changedUris: rewritten.map(FileURI.string))
    }

    private static func library(_ checkout: URL?, _ release: String?, _ repository: String?) throws -> WorkspaceMaker.Library {
        switch (checkout, release) {
        case (let checkout?, nil): return .checkout(checkout)
        case (nil, let release?): return .release(release, repository: repository ?? Release.repository)
        default: throw ToolingError(.invalidConfiguration, "Name one library: a checkout or a release.")
        }
    }

    /// Clones `release` into `workspace`'s `StateUI/`, in place of a clone there with no changes of its own.
    private static func replaceClone(in workspace: URL, with release: String, of repository: String) async throws -> URL {
        let files = FileManager.default
        let clone = workspace.appendingPathComponent("StateUI")
        let staging = workspace.appendingPathComponent(".StateUI.stateui-new-\(UUID().uuidString.lowercased())")
        if files.fileExists(atPath: clone.path) {
            let changes = Gathered()
            let status = ProcessRequest(ToolResolver().git, arguments: ["-C", clone.path, "status", "--porcelain"])
            let outcome = try? await ProcessRunner().run(status, output: changes.add)
            guard outcome?.succeeded == true, changes.lines(of: .standardOutput).isEmpty else {
                throw ToolingError(.alreadyExists, "\(clone.path) holds changes of its own; it is left as it is.")
            }
        }
        do {
            _ = try await ReleaseCatalog().clone(release, of: repository, into: staging)
            if files.fileExists(atPath: clone.path) { try files.removeItem(at: clone) }
            try files.moveItem(at: staging, to: clone)
        } catch {
            try? files.removeItem(at: staging)
            throw error
        }
        return clone
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
        methods.query("name/check") { (check: NameCheck) in
            checkName(check.name, of: check.kind, in: try check.parentUri.map(FileURI.url))
        }
        methods.query("releases/list") { (query: ReleaseQuery) in
            try await listReleases(of: query.repository, from: query.minimum)
        }
        methods.mutation("workspace/create") { (request: WorkspaceRequest, _: OperationContext) in
            try await createWorkspace(
                request.name, in: try FileURI.url(request.parentUri), checkout: try request.checkoutUri.map(FileURI.url),
                release: request.release, repository: request.repository, application: request.application)
        }
        methods.mutation("workspace/useLibrary") { (request: LibraryRequest, _: OperationContext) in
            guard let uri = request.workspaceUri else {
                throw ToolingError(.projectNotFound, "No workspace is named.")
            }
            return try await useLibrary(
                in: try FileURI.url(uri), checkout: try request.checkoutUri.map(FileURI.url), release: request.release,
                repository: request.repository)
        }
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
