// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// What a build says while it works: what it is doing, and each line its programs write.
public struct BuildReporter: Sendable {
    public var progress: @Sendable (String) -> Void
    public var output: @Sendable (ProcessOutput) -> Void

    /// A reporter telling `progress` and `output`.
    public init(progress: @escaping @Sendable (String) -> Void = { _ in }, output: @escaping @Sendable (ProcessOutput) -> Void = { _ in }) {
        self.progress = progress
        self.output = output
    }
}

/// An application built for a host and published as an artifact - for the machine one application build at a
/// time, its operation journaled, and nothing published unless every step succeeded.
/// Design: docs/design/tooling/builds.md#an-application-build
public struct ApplicationBuilder: Sendable {
    private let environment: [String: String]
    private let permit: BuildPermit
    private let tools: ToolResolver

    /// A builder finding its programs through `environment` and waiting on `permit`.
    public init(environment: [String: String] = ProcessInfo.processInfo.environment, permit: BuildPermit = BuildPermit()) {
        self.environment = environment
        self.permit = permit
        tools = ToolResolver(environment: environment)
    }

    /// Builds `request`'s application as operation `operation` and publishes it.
    ///
    /// - Throws: ``ToolingError`` - `PROJECT_NOT_FOUND`, `INVALID_CONFIGURATION`, `TOOL_FAILED` - or `CancellationError`.
    public func build(_ request: BuildRequest, in folder: URL, operation: String, reporter: BuildReporter = BuildReporter())
        async throws -> BuildResult {
        try await built(request, in: folder, operation: operation, reporter: reporter).result
    }

    /// Builds `request`'s application for release - unless it names another configuration - and lays its bundle,
    /// made anew, in its `outputUri`, else `<workspace>/artifacts/<Name>/<Host>`.
    public func package(_ request: BuildRequest, in folder: URL, operation: String, reporter: BuildReporter = BuildReporter())
        async throws -> BuildResult {
        var release = request
        release.configuration = request.configuration ?? .release
        let (built, root) = try await built(release, in: folder, operation: operation, reporter: reporter)
        let output = try request.outputUri.map(FileURI.url)
            ?? root.appendingPathComponent("artifacts").appendingPathComponent(built.application).appendingPathComponent("AppKit")
        let artifact = try FileURI.url(built.folderUri)
        let bundle = "\(built.application)AppKit.app"
        let files = FileManager.default
        try? files.removeItem(at: output)
        try files.createDirectory(at: output, withIntermediateDirectories: true)
        try files.copyItem(at: artifact.appendingPathComponent(bundle), to: output.appendingPathComponent(bundle))
        var laid = built
        laid.folderUri = FileURI.string(output)
        laid.programUri = FileURI.string(output.appendingPathComponent("\(bundle)/Contents/MacOS/\(built.application)AppKit"))
        return laid
    }

    /// The build, and the project root its records stand in: the workspace's folder, else the application's.
    private func built(_ request: BuildRequest, in folder: URL, operation: String, reporter: BuildReporter)
        async throws -> (result: BuildResult, root: URL) {
        let (project, application) = try await resolve(request, in: folder)
        guard request.host == .appkit else {
            throw ToolingError(.invalidConfiguration, "\(request.host.rawValue) is built by its .scripts until its row moves to the tool.")
        }
        guard let libraryUri = application.libraryUri else {
            throw ToolingError(.projectNotFound, "\(application.name) names no StateUI checkout in its Package.swift.")
        }
        let folderOfApplication = try FileURI.url(application.packageUri)
        let configuration = request.configuration ?? .debug
        let machine = Architecture(rawValue: Machine.current.architecture) ?? .arm64
        let architecture = request.architecture ?? machine
        let context = BuildContext(
            application: folderOfApplication, product: "\(application.name)AppKit", host: .appkit,
            configuration: configuration, architecture: architecture,
            compiler: (await ToolOutput.text(tools.swift, ["--version"]))?.split(separator: "\n").first.map(String.init) ?? "",
            sdk: await AppleSDK.find(.macOS)?.identity ?? "",
            library: try FileURI.url(libraryUri))

        let lease = try await permit.acquire(for: "\(application.name) for \(request.host.rawValue), stateui \(ProcessInfo.processInfo.processIdentifier)") {
            reporter.progress("waiting for \($0)")
        }
        defer { lease.release() }

        let root = try project.workspaceUri.map(FileURI.url) ?? folderOfApplication
        let entry = try OperationJournal(root: root).open(id: operation, kind: "application/build", request: try JSONValue(encoding: request))
        do {
            let result = try await compileAndPublish(context, name: application.name, operation: operation, entry: entry, reporter: reporter, machine: machine)
            try entry.finish(.succeeded)
            return (result, root)
        } catch let error as ToolingError {
            try? entry.finish(.failed, failure: error)
            throw error
        } catch {
            try? entry.finish(error is CancellationError ? .cancelled : .failed)
            throw error
        }
    }

    private func compileAndPublish(
        _ context: BuildContext, name: String, operation: String, entry: OperationJournal.Entry, reporter: BuildReporter,
        machine: Architecture
    ) async throws -> BuildResult {
        let triple = context.architecture == machine ? [] : ["--triple", AppleSDK.Platform.macOS.triple(context.architecture, floor: Doctor.appleFloor)]
        let common = ["--package-path", context.application.path, "--scratch-path", context.scratch.path,
                      "--configuration", context.configuration.rawValue, "--disable-build-manifest-caching"] + triple
        let environment = ProcessEnvironment.inherited.setting("STATEUI_HOST", to: context.host.rawValue)
        reporter.progress("building \(context.product)")
        let said = Gathered()
        let outcome = try await ProcessRunner().run(
            ProcessRequest(tools.swift, arguments: ["build", "--product", context.product] + common, environment: environment),
            output: { line in
                said.add(line)
                entry.write(output: line.text + "\n")
                reporter.output(line)
            })
        try Task.checkCancellation()
        guard outcome.succeeded else {
            let last = (said.lines(of: .standardOutput) + said.lines(of: .standardError)).suffix(12).joined(separator: "\n")
            throw ToolingError(.toolFailed, "\(context.product) did not build; nothing was published:\n\(last)")
        }
        let binaries = (await ToolOutput.text(tools.swift, ["build", "--show-bin-path"] + common, environment: environment))?
            .split(separator: "\n").last.map { URL(fileURLWithPath: String($0).trimmingCharacters(in: .whitespaces)) }
        guard let binaries else { throw ToolingError(.toolFailed, "SwiftPM did not say where it laid \(context.product).") }

        #if canImport(AppKit)
        reporter.progress("assembling \(context.product).app")
        let store = ArtifactStore(application: context.application)
        let staging = try store.staging(for: operation)
        let bundle = AppKitBundle(
            application: context.application, name: name, product: context.product, binaries: binaries,
            release: Release.version, minimumSystem: Doctor.appleFloor)
        do {
            _ = try await bundle.assemble(in: staging)
            let manifest = ArtifactManifest(
                id: "\(context.host.rawValue)-\(context.key)-\(context.configuration.rawValue)", producerOperationId: operation,
                createdAt: Operations.timestamp(), applicationUri: FileURI.string(context.application), host: context.host,
                configuration: context.configuration, architecture: context.architecture, productName: context.product,
                entryPoints: [bundle.programPath], signing: .adHoc)
            let published = try store.publish(staging, as: manifest)
            return BuildResult(
                application: name, host: context.host, configuration: context.configuration, architecture: context.architecture,
                folderUri: FileURI.string(published), programUri: FileURI.string(published.appendingPathComponent(bundle.programPath)))
        } catch {
            store.discard(staging)
            throw error
        }
        #else
        throw ToolingError(.invalidConfiguration, "An AppKit bundle is assembled on a Mac.")
        #endif
    }

    /// The project `request` names - its `projectUri`, else `folder` - and the application in it it means.
    private func resolve(_ request: BuildRequest, in folder: URL) async throws -> (Project, Application) {
        let project = try await ProjectReader(tools: tools).describe(containing: try request.projectUri.map(FileURI.url) ?? folder)
        let named = request.application.map { name in project.applications.filter { $0.name == name } } ?? project.applications
        guard named.count == 1, let application = named.first else {
            let names = project.applications.map(\.name).joined(separator: ", ")
            throw ToolingError(.invalidConfiguration, named.isEmpty
                ? "No application \(request.application ?? "") here; the project holds \(names)."
                : "Name the application to build: the project holds \(names).")
        }
        guard application.declaredHosts.contains(request.host) else {
            throw ToolingError(.invalidConfiguration, "\(application.name) has no \(request.host.rawValue) head.")
        }
        return (project, application)
    }
}
