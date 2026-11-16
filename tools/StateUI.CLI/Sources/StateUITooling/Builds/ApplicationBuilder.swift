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
    private let destinations: @Sendable (HostFamily) async -> [Destination]

    /// A builder finding its programs through `environment`, waiting on `permit`, and choosing a UIKit or Android
    /// head's destination among those `destinations` lists for its host.
    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment, permit: BuildPermit = BuildPermit(),
        destinations: @escaping @Sendable (HostFamily) async -> [Destination] = { host in
            host == .android ? await AndroidDestinations().list() : await AppleDestinations().list()
        }
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
    /// made anew, in its `outputUri`, else `<workspace>/artifacts/<Name>/<Host>`: a folder that stands empty, or one a
    /// package was laid in - checked before the build.
    ///
    /// - Throws: ``ToolingError`` - besides a build's, `INVALID_CONFIGURATION` for an output holding the application,
    ///   its project or its checkout, `ALREADY_EXISTS` for one holding what no package laid.
    public func package(_ request: BuildRequest, in folder: URL, operation: String, reporter: BuildReporter = BuildReporter())
        async throws -> BuildResult {
        var release = try Self.chosen(request, in: folder)
        release.configuration = request.configuration ?? .release
        let (project, application, host) = try await resolve(release, in: folder)
        let folderOfApplication = try FileURI.url(application.packageUri)
        let root = try project.workspaceUri.map(FileURI.url) ?? folderOfApplication
        let output = try request.outputUri.map(FileURI.url)
            ?? root.appendingPathComponent("artifacts").appendingPathComponent(application.name).appendingPathComponent(host.folder)
        let keeping = [folderOfApplication, root] + (try application.libraryUri.map { [try FileURI.url($0)] } ?? [])
        try PackageOutput.check(output, keeping: keeping)
        let (built, _) = try await built(
            release, project: project, application: application, host: host, operation: operation, reporter: reporter)
        let artifact = try FileURI.url(built.folderUri)
        let head = "\(application.name) \(host.folder)"
        guard let bundleUri = built.bundleUri else {
            // A head with no bundle is its artifact's folder: the program, its libraries, its pictures.
            let files = FileManager.default
            try PackageOutput.lay(output, keeping: keeping, head: head)
            for name in try files.contentsOfDirectory(atPath: artifact.path).sorted() where name != "artifact.json" {
                try files.copyItem(at: artifact.appendingPathComponent(name), to: output.appendingPathComponent(name))
            }
            if built.host == .winui {
                try await WinUIHead.readyForDeployment(
                    output, architecture: built.architecture, compiler: try Self.compilerPath(tools.swift),
                    cache: ArtifactStore(holding: artifact).cache("swift-runtime-\(built.architecture.rawValue)"),
                    reporter: reporter)
            }
            var laid = built
            laid.folderUri = FileURI.string(output)
            laid.programUri = FileURI.string(output.appendingPathComponent(try FileURI.url(built.programUri).lastPathComponent))
            return laid
        }
        let bundle = try FileURI.url(bundleUri)
        let program = try FileURI.url(built.programUri).path.dropFirst(artifact.path.count + 1)
        let files = FileManager.default
        try PackageOutput.lay(output, keeping: keeping, head: head)
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
        let request = try Self.chosen(request, in: folder)
        let (project, application, host) = try await resolve(request, in: folder)
        return try await built(
            request, project: project, application: application, host: host, operation: operation, reporter: reporter)
    }

    /// The build of `application`, of `project`, for `host`, and the root its records stand in.
    private func built(
        _ request: BuildRequest, project: Project, application: Application, host: HostFamily, operation: String,
        reporter: BuildReporter
    ) async throws -> (result: BuildResult, root: URL) {
        guard let libraryUri = application.libraryUri else {
            throw ToolingError(.projectNotFound, "\(application.name) names no StateUI checkout in its Package.swift.")
        }
        let folderOfApplication = try FileURI.url(application.packageUri)
        let configuration = request.configuration ?? .debug
        let machine = Architecture(rawValue: Machine.current.architecture) ?? .arm64
        let target = switch host {
        case .uikit:
            try await BuildTarget.uiKit(
                device: request.device, listed: await destinations(.uikit), architecture: request.architecture, machine: machine,
                identifier: application.identifier)
        case .android:
            try await BuildTarget.android(
                device: request.device, listed: await destinations(.android), architecture: request.architecture,
                tools: AndroidTools(environment: environment))
        case .gtk:
            try BuildTarget.native(request.architecture ?? machine, machine: machine, host: host)
        case .winui:
            try BuildTarget.winUI(request.architecture ?? machine, machine: machine)
        case .web:
            try await BuildTarget.web(compiler: tools.swift)
        default:
            await BuildTarget.appKit(request.architecture ?? machine, machine: machine)
        }
        let compiler = target.compiler ?? tools.swift
        let context = BuildContext(
            application: folderOfApplication, product: "\(application.name)\(host.folder)", host: host,
            configuration: configuration, architecture: target.architecture,
            compiler: (await ToolOutput.text(compiler, ["--version"]))?.split(separator: "\n").first.map(String.init) ?? "",
            sdk: target.sdkIdentity, library: try FileURI.url(libraryUri))

        let lease = try await permit.acquire(for: "\(application.name) for \(host.rawValue), stateui \(ProcessInfo.processInfo.processIdentifier)") {
            reporter.progress("waiting for \($0)")
        }
        defer { lease.release() }

        let root = try project.workspaceUri.map(FileURI.url) ?? folderOfApplication
        let entry = try OperationJournal(root: root).open(id: operation, kind: "application/build", request: try JSONValue(encoding: request))
        do {
            let identity = ApplicationFile(
                identifier: application.identifier, version: application.version, build: application.build,
                name: application.displayName)
            let result = try await compileAndPublish(
                context, target, name: application.name, identity: identity, operation: operation, entry: entry, reporter: reporter)
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
        _ context: BuildContext, _ target: BuildTarget, name: String, identity: ApplicationFile, operation: String,
        entry: OperationJournal.Entry, reporter: BuildReporter
    ) async throws -> BuildResult {
        let common = ["--package-path", context.application.path, "--scratch-path", context.scratch.path,
                      "--configuration", context.configuration.rawValue, "--disable-build-manifest-caching"] + target.arguments
        let environment = target.environment.reduce(ProcessEnvironment.inherited.setting("STATEUI_HOST", to: context.host.rawValue)) {
            $0.setting($1.key, to: $1.value)
        }
        let compiler = target.compiler ?? tools.swift
        if context.host == .winui {
            // A running head holds its executable, which publishing writes again: it stops first.
            RunningPrograms.stop(runningFrom: ArtifactStore(application: context.application).folder(of: context.artifact))
            try await WinUIProjection(library: context.library, packages: WinUIPackages(environment: self.environment)).ready(reporter: reporter)
        }
        reporter.progress("building \(context.product)")
        let said = Gathered()
        let outcome = try await ProcessRunner().run(
            ProcessRequest(compiler, arguments: ["build", "--product", context.product] + common, environment: environment),
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
        let binaries = (await ToolOutput.text(compiler, ["build", "--show-bin-path"] + common, environment: environment))?
            .split(separator: "\n").last.map { URL(fileURLWithPath: String($0).trimmingCharacters(in: .whitespaces)) }
        guard let binaries else { throw ToolingError(.toolFailed, "SwiftPM did not say where it laid \(context.product).") }

        reporter.progress("assembling \(context.product)")
        let store = ArtifactStore(application: context.application)
        let staging = try store.staging(for: operation)
        do {
            // Every line a step of the assembly writes stands in the journal too, as the compiler's does.
            let logged = BuildReporter(progress: reporter.progress, output: { line in
                entry.write(output: line.text + "\n")
                reporter.output(line)
            })
            let head = try await assemble(
                context, target, name: name, identity: identity, binaries: binaries, common: common, environment: environment,
                in: staging, reporter: logged)
            let (bundle, program, signing) = (head.bundle, head.program, head.signing)
            let manifest = ArtifactManifest(
                id: context.artifact, producerOperationId: operation,
                createdAt: Operations.timestamp(), applicationUri: FileURI.string(context.application), host: context.host,
                configuration: context.configuration, architecture: context.architecture, productName: context.product,
                entryPoints: [program], signing: signing, applicationName: identity.name ?? name, identifier: head.identifier)
            let published = try store.publish(staging, as: manifest)
            return BuildResult(
                application: name, host: context.host, configuration: context.configuration, architecture: context.architecture,
                folderUri: FileURI.string(published), programUri: FileURI.string(published.appendingPathComponent(program)),
                bundleUri: bundle.map { FileURI.string(published.appendingPathComponent($0)) }, destination: target.destination,
                identifier: head.identifier, symbolsUri: head.symbols.map { FileURI.string(published.appendingPathComponent($0)) })
        } catch {
            store.discard(staging)
            throw error
        }
    }

    /// What an assembly laid in staging: the bundle's path there and its program's, how it was signed, what the
    /// platform knows it by, and where a debugger reads its symbols where they stand apart.
    private struct Head {
        /// The bundle's path, where the head is one; a GTK head is its folder.
        var bundle: String?
        var program: String
        var signing: ArtifactManifest.Signing
        var identifier: String?
        var symbols: String?
    }

    /// The head assembled in `staging` - an Apple bundle, an Android APK - for the application `identity` says; a head
    /// whose platform keeps no record of the application - WinUI's, GTK's, a page - carries its `stateui.json`.
    /// Design: docs/design/tooling/projects.md#a-head-carries-what-the-application-is
    private func assemble(
        _ context: BuildContext, _ target: BuildTarget, name: String, identity: ApplicationFile, binaries: URL, common: [String],
        environment: ProcessEnvironment, in staging: URL, reporter: BuildReporter
    ) async throws -> Head {
        try Self.lay(identity, for: context.host, in: staging)
        if context.host == .web {
            let page = WebPage(
                application: context.application, name: identity.name ?? name, product: context.product, binaries: binaries,
                library: context.library, stamp: Int(Date().timeIntervalSince1970))
            try page.assemble(in: staging)
            return Head(bundle: nil, program: "index.html", signing: .none, identifier: identity.identifier)
        }
        if context.host == .winui {
            let compiler = try Self.compilerPath(tools.swift)
            let head = WinUIHead(
                application: context.application, product: context.product, binaries: binaries, architecture: context.architecture,
                machine: Architecture(rawValue: Machine.current.architecture) ?? .arm64,
                dependencies: try await WinUIHead.resolvedDependencies(
                    of: context.application, scratch: ["--scratch-path", context.scratch.path], compiler: tools.swift, environment: environment),
                packages: WinUIPackages(environment: self.environment),
                compiler: compiler, cache: ArtifactStore(application: context.application).cache("swift-runtime-\(context.architecture.rawValue)"))
            try await head.assemble(in: staging, reporter: reporter)
            return Head(bundle: nil, program: "\(context.product).exe", signing: .none, identifier: identity.identifier)
        }
        if context.host == .gtk {
            let head = GTKHead(application: context.application, product: context.product, binaries: binaries)
            try head.assemble(in: staging)
            return Head(bundle: nil, program: context.product, signing: .none, identifier: identity.identifier)
        }
        if context.host == .android, let (swiftSDK, ndk) = target.android {
            let head = AndroidHead(
                application: context.application, name: name, identity: identity, product: context.product, library: context.library,
                configuration: context.configuration, work: context.scratch.appendingPathComponent("stateui"),
                tools: AndroidTools(environment: self.environment))
            guard let abi = AndroidDestinations.abi(of: context.architecture) else {
                throw ToolingError(.invalidConfiguration, "No Android ABI is \(context.architecture.rawValue).")
            }
            let package = try await head.assemble(
                abi: abi, binaries: binaries, swiftSDK: swiftSDK, ndk: ndk, in: staging, reporter: reporter)
            return Head(bundle: package.apk, program: package.apk, signing: .development, identifier: package.package, symbols: "symbols/\(abi)")
        }
        #if canImport(AppKit)
        if context.host == .appkit {
            let bundle = AppKitBundle(
                application: context.application, name: name, product: context.product, binaries: binaries,
                identity: identity, minimumSystem: Doctor.appleFloor)
            _ = try await bundle.assemble(in: staging)
            return Head(bundle: bundle.bundlePath, program: bundle.programPath, signing: .adHoc, identifier: identity.identifier)
        }
        let bundle = UIKitBundle(
            application: context.application, name: name, product: context.product, binaries: binaries,
            identity: identity, minimumSystem: Doctor.appleFloor, platform: target.sdk?.platform ?? .iOSSimulator,
            work: context.scratch.appendingPathComponent("stateui"))
        switch target.signing {
        case .adHoc:
            _ = try await bundle.assemble(in: staging, signing: .adHoc)
            return Head(bundle: bundle.bundlePath, program: bundle.programPath, signing: .adHoc, identifier: bundle.identifier)
        case .development(let development):
            _ = try await bundle.assemble(in: staging, signing: .development(development))
            return Head(bundle: bundle.bundlePath, program: bundle.programPath, signing: .development, identifier: bundle.identifier)
        }
        #else
        throw ToolingError(.invalidConfiguration, "An Apple bundle is assembled on a Mac.")
        #endif
    }

    /// Lays `identity` - the name in it - in a head of `host` whose platform keeps no record of the application.
    static func lay(_ identity: ApplicationFile, for host: HostFamily, in staging: URL) throws {
        guard [.web, .winui, .gtk].contains(host) else { return }
        try identity.write(to: staging.appendingPathComponent(ApplicationFile.name))
    }

    /// Where `compiler` stands: its path, or where the search path finds it.
    static func compilerPath(_ compiler: ProcessExecutable) throws -> URL {
        switch compiler {
        case .path(let path): return URL(fileURLWithPath: path)
        case .name(let name):
            guard let found = SearchPath().find(name) else { throw ToolingError(.missingToolchain, "No \(name) stands on the search path.") }
            return found
        }
    }

    /// `request` with what was chosen for its application where it names nothing: the host, and that host's device.
    /// Design: docs/design/tooling/projects.md#what-was-chosen
    ///
    /// - Throws: ``ToolingError`` - the project's, and `INVALID_CONFIGURATION` for no host named or chosen.
    public static func chosen(_ request: BuildRequest, in folder: URL) throws -> BuildRequest {
        var chosen = request
        let application = try ProjectReader.applicationFolder(
            named: request.application, containing: try request.projectUri.map(FileURI.url) ?? folder)
        let settings = try ApplicationSettings.read(in: application)
        guard let host = request.host ?? settings.host else {
            throw ToolingError(
                .invalidConfiguration,
                "Name the host with --host, or choose one for \(application.lastPathComponent): `stateui settings --host <host>`.")
        }
        chosen.host = host
        chosen.device = request.device ?? settings.device(for: host)
        return chosen
    }

    /// The project `request` names - its `projectUri`, else `folder` - the application in it it means
    /// (`ProjectReader.applicationFolder`), and the host it is built for.
    private func resolve(_ request: BuildRequest, in folder: URL) async throws -> (Project, Application, HostFamily) {
        let projectFolder = try request.projectUri.map(FileURI.url) ?? folder
        let project = try await ProjectReader(tools: tools).describe(containing: projectFolder)
        let meant = FileURI.string(try ProjectReader.applicationFolder(named: request.application, containing: projectFolder))
        guard let application = project.applications.first(where: { $0.packageUri == meant }) else {
            throw ToolingError(.internalError, "\(meant) was meant, but the project's description holds no such application.")
        }
        guard let host = request.host else {
            throw ToolingError(.invalidConfiguration, "No host is named for \(application.name).")
        }
        guard application.declaredHosts.contains(host) else {
            throw ToolingError(.invalidConfiguration, "\(application.name) has no \(host.rawValue) head.")
        }
        return (project, application, host)
    }
}
