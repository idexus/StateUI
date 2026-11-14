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

/// An application built for a host - AppKit, or UIKit for a simulator or a device - and published as an artifact: for
/// the machine one application build at a time, its operation journaled, and nothing published unless every step
/// succeeded.
/// Design: docs/design/tooling/builds.md#an-application-build
public struct ApplicationBuilder: Sendable {
    private let environment: [String: String]
    private let permit: BuildPermit
    private let tools: ToolResolver
    private let destinations: @Sendable () async -> [Destination]

    /// A builder finding its programs through `environment`, waiting on `permit`, and choosing a UIKit head's
    /// destination among those `destinations` lists.
    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment, permit: BuildPermit = BuildPermit(),
        destinations: @escaping @Sendable () async -> [Destination] = { await AppleDestinations().list() }
    ) {
        self.environment = environment
        self.permit = permit
        self.destinations = destinations
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
            ?? root.appendingPathComponent("artifacts").appendingPathComponent(built.application).appendingPathComponent(built.host.folder)
        let artifact = try FileURI.url(built.folderUri)
        guard let bundleUri = built.bundleUri else { return built }
        let bundle = try FileURI.url(bundleUri)
        let program = try FileURI.url(built.programUri).path.dropFirst(artifact.path.count + 1)
        let files = FileManager.default
        try? files.removeItem(at: output)
        try files.createDirectory(at: output, withIntermediateDirectories: true)
        try files.copyItem(at: bundle, to: output.appendingPathComponent(bundle.lastPathComponent))
        var laid = built
        laid.folderUri = FileURI.string(output)
        laid.bundleUri = FileURI.string(output.appendingPathComponent(bundle.lastPathComponent))
        laid.programUri = FileURI.string(output.appendingPathComponent(String(program)))
        return laid
    }

    /// The build, and the project root its records stand in: the workspace's folder, else the application's.
    func built(_ request: BuildRequest, in folder: URL, operation: String, reporter: BuildReporter)
        async throws -> (result: BuildResult, root: URL) {
        let (project, application) = try await resolve(request, in: folder)
        guard [.appkit, .uikit].contains(request.host) else {
            throw ToolingError(.invalidConfiguration, "\(request.host.rawValue) is built by its .scripts until its row moves to the tool.")
        }
        guard let libraryUri = application.libraryUri else {
            throw ToolingError(.projectNotFound, "\(application.name) names no StateUI checkout in its Package.swift.")
        }
        let folderOfApplication = try FileURI.url(application.packageUri)
        let configuration = request.configuration ?? .debug
        let machine = Architecture(rawValue: Machine.current.architecture) ?? .arm64
        let target = request.host == .uikit
            ? try await BuildTarget.uiKit(
                device: request.device, listed: await destinations(), architecture: request.architecture, machine: machine,
                application: folderOfApplication, name: application.name)
            : await BuildTarget.appKit(request.architecture ?? machine, machine: machine)
        let context = BuildContext(
            application: folderOfApplication, product: "\(application.name)\(request.host.folder)", host: request.host,
            configuration: configuration, architecture: target.architecture,
            compiler: (await ToolOutput.text(tools.swift, ["--version"]))?.split(separator: "\n").first.map(String.init) ?? "",
            sdk: target.sdk?.identity ?? "", library: try FileURI.url(libraryUri))

        let lease = try await permit.acquire(for: "\(application.name) for \(request.host.rawValue), stateui \(ProcessInfo.processInfo.processIdentifier)") {
            reporter.progress("waiting for \($0)")
        }
        defer { lease.release() }

        let root = try project.workspaceUri.map(FileURI.url) ?? folderOfApplication
        let entry = try OperationJournal(root: root).open(id: operation, kind: "application/build", request: try JSONValue(encoding: request))
        do {
            let result = try await compileAndPublish(context, target, name: application.name, operation: operation, entry: entry, reporter: reporter)
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
        _ context: BuildContext, _ target: BuildTarget, name: String, operation: String, entry: OperationJournal.Entry,
        reporter: BuildReporter
    ) async throws -> BuildResult {
        let common = ["--package-path", context.application.path, "--scratch-path", context.scratch.path,
                      "--configuration", context.configuration.rawValue, "--disable-build-manifest-caching"] + target.arguments
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
        do {
            let (bundle, program, signing) = try await assemble(context, target, name: name, binaries: binaries, in: staging)
            let manifest = ArtifactManifest(
                id: "\(context.host.rawValue)-\(context.key)-\(context.configuration.rawValue)", producerOperationId: operation,
                createdAt: Operations.timestamp(), applicationUri: FileURI.string(context.application), host: context.host,
                configuration: context.configuration, architecture: context.architecture, productName: context.product,
                entryPoints: [program], signing: signing)
            let published = try store.publish(staging, as: manifest)
            return BuildResult(
                application: name, host: context.host, configuration: context.configuration, architecture: context.architecture,
                folderUri: FileURI.string(published), programUri: FileURI.string(published.appendingPathComponent(program)),
                bundleUri: FileURI.string(published.appendingPathComponent(bundle)), destination: target.destination)
        } catch {
            store.discard(staging)
            throw error
        }
        #else
        throw ToolingError(.invalidConfiguration, "An Apple bundle is assembled on a Mac.")
        #endif
    }

    #if canImport(AppKit)
    /// The head's bundle assembled in `staging`: its folder's and its program's paths there, and how it was signed.
    private func assemble(_ context: BuildContext, _ target: BuildTarget, name: String, binaries: URL, in staging: URL)
        async throws -> (bundle: String, program: String, signing: ArtifactManifest.Signing) {
        if context.host == .appkit {
            let bundle = AppKitBundle(
                application: context.application, name: name, product: context.product, binaries: binaries,
                release: Release.version, minimumSystem: Doctor.appleFloor)
            _ = try await bundle.assemble(in: staging)
            return (bundle.bundlePath, bundle.programPath, .adHoc)
        }
        let bundle = UIKitBundle(
            application: context.application, name: name, product: context.product, binaries: binaries,
            release: Release.version, minimumSystem: Doctor.appleFloor, platform: target.sdk?.platform ?? .iOSSimulator,
            work: context.scratch.appendingPathComponent("stateui"))
        switch target.signing {
        case .adHoc:
            _ = try await bundle.assemble(in: staging, signing: .adHoc)
            return (bundle.bundlePath, bundle.programPath, .adHoc)
        case .development(let development):
            _ = try await bundle.assemble(in: staging, signing: .development(development))
            return (bundle.bundlePath, bundle.programPath, .development)
        }
    }
    #endif

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
