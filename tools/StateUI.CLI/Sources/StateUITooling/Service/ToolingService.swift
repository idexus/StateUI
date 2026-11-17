// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The work every client of the tool asks for, by the tooling API's methods: the terminal's commands and an
/// editor's JSON-RPC requests both call it.
public struct ToolingService: Sendable {
    /// The packages this connection indexes, and as which host.
    private let indexLeases: IndexLeases

    /// A service for this process, its index leases kept in `leases`.
    public init(leases: IndexLeases = IndexLeases()) {
        indexLeases = leases
    }

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
    /// else the checkout `parent` stands in - named `identifier`, and lists it in the workspace, else gives it the
    /// `.gitignore` a workspace has - `project/create`.
    public func createApplication(
        _ name: String, identifier: String? = nil, platforms: [HostFamily]? = nil, in parent: URL, from checkout: URL?
    ) async throws -> ProjectCreation {
        var workspace = try Workspace.nearest(from: parent)
        guard let checkout = checkout ?? workspace?.library ?? Checkout.holding(parent)?.root else {
            throw ToolingError(
                .projectNotFound, "No StateUI checkout is named for \(parent.path): name one with --checkout, or in a"
                    + " stateui-workspace.json's library.")
        }
        let made = try ApplicationMaker().make(name, identifier: identifier, platforms: platforms, in: parent, from: checkout)
        var created = [FileURI.string(made)]
        if workspace == nil {
            // An application standing alone keeps what its builds and the tool write out of git, as a workspace does.
            try Data(WorkspaceMaker.ignored(cloned: false).utf8).write(to: made.appendingPathComponent(".gitignore"))
        }
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

    /// Makes `checkout` or `release` the library of the project `folder` stands in - `project/useLibrary`: the
    /// application, whose manifest names a checkout from then on, else the workspace, every listed application's
    /// manifest and its file naming a checkout or a release cloned into it.
    /// Design: docs/design/tooling/projects.md#a-library-changed
    public func useLibrary(in folder: URL, checkout: URL?, release: String?, repository: String?) async throws -> LibraryChange {
        let folder = RealPath.of(RealPath.lexical(folder))
        let chosen = try Self.library(checkout, release, repository)
        if let application = ProjectReader.application(holding: folder) {
            guard case .checkout(let named) = chosen else {
                throw ToolingError(
                    .invalidConfiguration,
                    "A release is cloned into a workspace's StateUI/: name a checkout for \(application.lastPathComponent),"
                        + " or change its workspace's library.")
            }
            guard Checkout(at: named) != nil else {
                throw ToolingError(.projectNotFound, "No StateUI checkout stands at \(named.path).")
            }
            let rewritten = try ApplicationManifest.naming(named, in: application)
            for (manifest, text) in rewritten { try Data(text.utf8).write(to: manifest) }
            return LibraryChange(
                projectUri: FileURI.string(application), library: ApplicationMaker.relativePath(from: application, to: named),
                changedUris: rewritten.map { FileURI.string($0.manifest) })
        }
        guard var workspace = try Workspace.nearest(from: folder) else {
            throw ToolingError(
                .projectNotFound, "No StateUI application or stateui-workspace.json stands in or above \(folder.path).")
        }
        let library: URL
        switch chosen {
        case .checkout(let named):
            guard Checkout(at: named) != nil else {
                throw ToolingError(.projectNotFound, "No StateUI checkout stands at \(named.path).")
            }
            library = named
        case .release(let release, let repository):
            library = try await Self.replaceClone(in: workspace.folder, with: release, of: repository)
        }
        let rewritten = try workspace.use(library)
        return LibraryChange(
            projectUri: FileURI.string(workspace.folder), library: workspace.file.library?.path ?? "",
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

    /// What this machine has of every component it needs - `toolchain/check` - or, where `query` names a guest, what
    /// that guest has of what a head of its host needs, for the application and checkout of its project.
    public func checkToolchain(_ query: ToolchainQuery = ToolchainQuery()) async -> ToolchainReport {
        guard let device = query.device, let host = query.host else { return await Doctor().check() }
        var folders: [URL] = []
        if let uri = query.projectUri, let folder = try? FileURI.url(uri), let project = try? await ProjectReader().describe(containing: folder) {
            for application in project.applications {
                let uris = [application.packageUri] + (application.libraryUri.map { [$0] } ?? [])
                folders.append(contentsOf: uris.compactMap { try? FileURI.url($0) })
            }
        }
        var seen: Set<String> = []
        return await GuestDoctor(guests: ParallelsGuests())
            .check(host: host, device: device, folders: folders.filter { seen.insert($0.standardizedFileURL.path).inserted })
    }

    /// Lays the stateui of the checkout `folder` builds with in `device`, a guest of this Mac; its program's path
    /// there.
    public func prepareGuest(_ device: String, in folder: URL, reporter: BuildReporter) async throws -> String {
        let guests = ParallelsGuests()
        guard let prlctl = guests.prlctl else {
            throw ToolingError(.missingToolchain, "Parallels Desktop's prlctl is not here: its Pro or Business edition has it.")
        }
        guard let guest = await guests.list().first(where: { $0.name == device || $0.id == device }) else {
            throw ToolingError(.invalidConfiguration, "No guest named \(device) stands here: `stateui devices` lists them.")
        }
        let project = try? await ProjectReader().describe(containing: folder)
        guard let library = project?.applications.compactMap(\.libraryUri).first.flatMap({ try? FileURI.url($0) })
            ?? Checkout.holding(folder)?.root
        else { throw ToolingError(.projectNotFound, "No StateUI checkout stands in or above \(folder.path).") }
        return try await GuestPreparation(commands: GuestCommands(prlctl: prlctl, guest: guest)).lay(checkout: library, reporter: reporter)
    }

    /// The suites the folder holding `folder` - a checkout, a workspace, an application - holds for `host`, in the
    /// order they are best run - `tests/discover`.
    public func discoverTests(for host: HostFamily?, in folder: URL) async throws -> TestSuiteList {
        let project = try await describeProject(containing: folder)
        let root = try project.workspaceUri.map(FileURI.url) ?? FileURI.url(project.rootUri)
        let applications = try project.applications.map { try FileURI.url($0.packageUri) }
        return TestSuiteList(host: host, suites: TestDiscovery.suites(in: root, host: host, applications: applications))
    }

    /// Runs suite `request.suite` of the folder holding `folder` - `tests/run`.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a suite the folder does not hold for the host.
    public func runTests(_ request: TestRunRequest, in folder: URL, reporter: BuildReporter) async throws -> SuiteResult {
        let listed = try await discoverTests(for: request.host, in: folder)
        guard let suite = listed.suites.first(where: { $0.id == request.suite }) else {
            throw ToolingError(.invalidConfiguration, "No suite \(request.suite) here for \(request.host?.rawValue ?? "plain Swift"): \(listed.suites.map(\.id).joined(separator: ", ")).")
        }
        if suite.onDevice, request.device == nil {
            throw ToolingError(.invalidConfiguration, "\(suite.id) runs on a device: name it.")
        }
        return try await TestRunner(tools: ToolResolver()).run(
            suite, device: request.device, checkout: Checkout.holding(folder)?.root, reporter: reporter)
    }

    /// What an editor's language server indexes `host`'s code with - `index/describe`: its scratch folder, and the
    /// triple and SDK a host whose heads run elsewhere compiles for.
    public func describeIndex(of host: HostFamily?) async -> IndexContext {
        await IndexContexts(tools: ToolResolver()).describe(host)
    }

    /// Holds the packages `rootUris` names as `host` for this connection - `index/acquire` - or names the package
    /// another connection indexes as another host.
    public func acquireIndex(_ host: HostFamily?, rootUris: [String]) async throws -> IndexLease {
        try await indexLeases.acquire(host, roots: try rootUris.map(FileURI.url))
    }

    /// Takes every index's scratch folder away from the folders `rootUris` name - `index/clean` - but for those
    /// another connection indexes, by whatever path they are named, answered as conflicts and left as they stand.
    public func cleanIndex(in rootUris: [String]) async throws -> IndexCleaning {
        let cleaned = try await indexLeases.cleaning(try rootUris.map(FileURI.url), IndexContexts.clean)
        return IndexCleaning(
            removedUris: cleaned.removed.map(FileURI.string), conflicts: cleaned.conflicts.isEmpty ? nil : cleaned.conflicts)
    }

    /// Where `host`'s heads can run from this machine - `devices/list`: UIKit's iPhones, iPads and simulators on a Mac,
    /// Android's devices and emulators, the Web's browsers, and on a Mac the virtual machines of GTK's and WinUI's
    /// systems.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a host whose heads run on this machine itself.
    public func listDestinations(of host: HostFamily) async throws -> DestinationList {
        switch host {
        case .uikit:
            #if os(macOS)
            return DestinationList(host: host, destinations: await AppleDestinations().list())
            #else
            return DestinationList(host: host, destinations: [])
            #endif
        case .android:
            return DestinationList(host: host, destinations: await AndroidDestinations().list())
        case .web:
            return DestinationList(host: host, destinations: await Browsers.list())
        case .gtk, .winui:
            #if os(macOS)
            let system = ParallelsGuests.system(for: host)
            return DestinationList(host: host, destinations: await ParallelsGuests().list()
                .filter { $0.system == system }.map(ParallelsGuests.destination))
            #else
            throw ToolingError(.invalidConfiguration, "Heads of \(host.rawValue) run on this machine itself.")
            #endif
        default:
            throw ToolingError(.invalidConfiguration, "Heads of \(host.rawValue) run on this machine itself; uikit's and android's run on devices, web's in browsers.")
        }
    }

    /// Builds `request`'s application and publishes it - `application/build`.
    public func build(_ request: BuildRequest, in folder: URL, operation: String, reporter: BuildReporter) async throws -> BuildResult {
        let chosen = try ApplicationBuilder.chosen(request, in: folder)
        if GuestWork.asks(chosen) { return try await GuestWork(guests: ParallelsGuests()).build(chosen, in: folder, reporter: reporter) }
        return try await ApplicationBuilder().build(request, in: folder, operation: operation, reporter: reporter)
    }

    /// Builds `request`'s application for release and lays it out to be shipped - `application/package`.
    public func package(_ request: BuildRequest, in folder: URL, operation: String, reporter: BuildReporter) async throws -> BuildResult {
        let chosen = try ApplicationBuilder.chosen(request, in: folder)
        if GuestWork.asks(chosen) { return try await GuestWork(guests: ParallelsGuests()).package(chosen, in: folder, reporter: reporter) }
        return try await ApplicationBuilder().package(request, in: folder, operation: operation, reporter: reporter)
    }

    /// gdb's commands for a GTK head run under it on `architecture`.
    public static func gdbCommands(for architecture: Architecture) -> String {
        GTKHead.gdbCommands(for: architecture)
    }

    /// Installs the artifact at `artifact` where its host shows it - `application/install`.
    public func install(_ artifact: URL) async throws -> InstallResult {
        try await ApplicationInstaller().install(artifact)
    }

    /// Builds `request`'s application, starts it and follows it until it ends - `application/run`.
    public func run(_ request: RunRequest, in folder: URL, operation: String, reporter: RunReporter) async throws -> RunResult {
        var chosen = request
        chosen.build = try ApplicationBuilder.chosen(request.build, in: folder)
        if GuestWork.asks(chosen.build) { return try await GuestWork(guests: ParallelsGuests()).run(chosen, in: folder, reporter: reporter) }
        return try await ApplicationRunner().run(request, in: folder, operation: operation, reporter: reporter)
    }

    /// Runs suite `suite` - `host:<host>` - of the StateUI checkout holding `folder`, `filter`ed where given, a UIKit
    /// or Android one on the device `device` names; an Android one built alone for `architecture`, or run from
    /// `artifact`, what such a build made.
    ///
    /// - Throws: ``ToolingError`` `PROJECT_NOT_FOUND` outside a checkout, `INVALID_CONFIGURATION` for a suite there is
    ///   none of.
    public func testSuite(
        _ suite: String, filter: String?, device: String? = nil, buildOnly: Bool = false, architecture: Architecture? = nil,
        artifact: URL? = nil, in folder: URL, reporter: BuildReporter
    ) async throws -> SuiteResult {
        guard let checkout = Checkout.holding(folder)?.root else {
            throw ToolingError(.projectNotFound, "No StateUI checkout holds \(folder.path).")
        }
        guard suite.hasPrefix("host:"), let host = HostFamily(rawValue: String(suite.dropFirst("host:".count))) else {
            throw ToolingError(.invalidConfiguration, "No suite \(suite): host:appkit, host:uikit, host:android, host:winui, host:gtk and host:web are.")
        }
        return try await HostSuite(checkout: checkout).run(
            host, filter: filter, device: device, buildOnly: buildOnly, architecture: architecture, artifact: artifact, reporter: reporter)
    }

    /// Where the conformance verdicts of `hosts` - every host where none is named - stand in the StateUI checkout
    /// holding `folder`, as the library's own reader of a revision says.
    ///
    /// - Throws: ``ToolingError`` `PROJECT_NOT_FOUND` outside a checkout, `TOOL_FAILED` where the reader does not answer.
    public func conformanceStatus(of hosts: [HostFamily], in folder: URL, reporter: BuildReporter) async throws -> [ConformanceStatus] {
        guard let checkout = Checkout.holding(folder)?.root else {
            throw ToolingError(.projectNotFound, "No StateUI checkout holds \(folder.path).")
        }
        let metadata = ConformanceMetadata(checkout: checkout, tools: ToolResolver())
        var statuses: [ConformanceStatus] = []
        for host in hosts.isEmpty ? HostFamily.allCases : hosts {
            statuses.append(try await metadata.status(of: host, reporter: reporter))
        }
        return statuses
    }

    /// Holds the API records of the StateUI checkout holding `folder` - the library's, or with `host` its facade's,
    /// backends' and testing module's, after the host's suite builds and runs them - or writes them where `record`.
    public func apiRecords(
        host: HostFamily?, record: Bool, device: String?, in folder: URL, reporter: BuildReporter
    ) async throws -> SuiteResult {
        guard let checkout = Checkout.holding(folder)?.root else {
            throw ToolingError(.projectNotFound, "No StateUI checkout holds \(folder.path).")
        }
        let suites = HostSuite(checkout: checkout)
        guard let host else { return try await suites.runLibraryAPI(recording: record, reporter: reporter) }
        return try await suites.run(host, device: device, recordingAPI: record, reporter: reporter)
    }

    /// Runs the `kind` plan of the StateUI checkout holding `folder` - its suite `only` where named - on the device
    /// `device` names for UIKit and Android.
    public func runPlan(
        _ kind: RepositoryPlan.Kind, only: String?, device: String?, in folder: URL, reporter: BuildReporter
    ) async throws -> SuiteResult {
        guard let checkout = Checkout.holding(folder)?.root else {
            throw ToolingError(.projectNotFound, "No StateUI checkout holds \(folder.path).")
        }
        return try await RepositoryPlan(checkout: checkout).run(kind, only: only, device: device, reporter: reporter)
    }

    /// Holds each application's release Web module of the StateUI checkout holding `folder` - `application`'s alone
    /// where named - within its size budget.
    public func checkWebSizes(application: String?, in folder: URL, reporter: BuildReporter) async throws -> SuiteResult {
        guard let checkout = Checkout.holding(folder)?.root else {
            throw ToolingError(.projectNotFound, "No StateUI checkout holds \(folder.path).")
        }
        return SuiteResult(suite: "web-size", phases: try await WebSizes(checkout: checkout).run(application: application, reporter: reporter))
    }

    /// Holds the handbook's own outputs of the StateUI checkout holding `folder` - the dictionary and the platform
    /// contract (`documents`), else the samples' listings and review - to what stands, or writes them where `update`.
    public func handbook(samples: Bool, update: Bool, in folder: URL, reporter: BuildReporter) async throws -> SuiteResult {
        guard let checkout = Checkout.holding(folder)?.root else {
            throw ToolingError(.projectNotFound, "No StateUI checkout holds \(folder.path).")
        }
        let handbook = Handbook(checkout: checkout, tools: ToolResolver())
        let phase = samples ? try await handbook.samples(update: update, reporter: reporter)
            : try await handbook.documents(update: update, reporter: reporter)
        return SuiteResult(suite: samples ? "samples" : "docs", phases: [phase])
    }

    /// Runs `host`'s conformance families `selection` takes in the StateUI checkout holding `folder`, recording their
    /// verdicts and rendering the documents where `record`.
    ///
    /// - Throws: ``ToolingError`` `PROJECT_NOT_FOUND` outside a checkout, `INVALID_CONFIGURATION` for an unknown family.
    public func runConformance(
        _ host: HostFamily, selection: ConformanceSelection, record: Bool, device: String?, in folder: URL, reporter: BuildReporter
    ) async throws -> SuiteResult {
        guard let checkout = Checkout.holding(folder)?.root else {
            throw ToolingError(.projectNotFound, "No StateUI checkout holds \(folder.path).")
        }
        return try await ConformanceRun(checkout: checkout).run(host, selection: selection, record: record, device: device, reporter: reporter)
    }

    /// Packages `editor`'s extension from the checkout holding `folder` - `repository/integrationPackage`.
    ///
    /// - Throws: ``ToolingError`` `PROJECT_NOT_FOUND` outside a checkout, `TOOL_FAILED` where npm failed.
    public func packageIntegration(_ editor: Editor, in folder: URL, reporter: BuildReporter) async throws -> EditorExtension {
        guard let checkout = Checkout.holding(folder)?.root else {
            throw ToolingError(.projectNotFound, "No StateUI checkout holds \(folder.path).")
        }
        return try await EditorIntegration(checkout: checkout).package(editor, reporter: reporter)
    }

    /// Installs a packaged extension with the editor's command line - `repository/integrationInstall`.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` where the editor refused it, or does not list it at its version.
    public func installIntegration(_ request: IntegrationInstallRequest, reporter: BuildReporter) async throws -> EditorExtension {
        try await EditorIntegration.install(request.editorExtension, with: try FileURI.url(request.editorExecutableUri), reporter: reporter)
    }

    /// Packages the tool's own distribution from the checkout holding `folder` into `output` - its
    /// `artifacts/stateui` where none is named - and reads the archive back, each a phase.
    ///
    /// - Throws: ``ToolingError`` `PROJECT_NOT_FOUND` outside a checkout.
    public func packageDistribution(into output: URL?, in folder: URL, reporter: BuildReporter) async throws -> SuiteResult {
        guard let checkout = Checkout.holding(folder)?.root else {
            throw ToolingError(.projectNotFound, "No StateUI checkout holds \(folder.path).")
        }
        let target = output ?? checkout.appendingPathComponent("artifacts/stateui")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return try await ToolDistribution(checkout: checkout, tools: ToolResolver()).package(into: target, reporter: reporter)
    }

    /// `work` given a reporter whose words reach `context` in the order they were said.
    private static func reporting<Result: Sendable>(
        _ context: OperationContext, _ work: (RunReporter) async throws -> Result
    ) async throws -> Result {
        let (said, saying) = AsyncStream<Reported>.makeStream()
        let telling = Task {
            for await each in said {
                switch each {
                case .progress(let words): await context.progress(OperationProgress(stage: words))
                case .output(let line): await context.output(Array((line.text + "\n").utf8), on: line.stream == .standardError ? .stderr : .stdout)
                case .started(let application): await context.started(application)
                }
            }
        }
        defer { saying.finish() }
        let reporter = RunReporter(
            build: BuildReporter(progress: { saying.yield(.progress($0)) }, output: { saying.yield(.output($0)) }),
            started: { saying.yield(.started($0)) }, output: { saying.yield(.output($0)) })
        let result = try await work(reporter)
        saying.finish()
        await telling.value
        return result
    }

    /// The workspace a connection opened, as a folder.
    private static func folder(of caller: RequestContext) throws -> URL {
        guard let uri = caller.workspaceUri else {
            throw ToolingError(.projectNotFound, "No project is named, and the connection opened no workspace.")
        }
        return try FileURI.url(uri)
    }

    /// The methods an editor calls, each answered by this service.
    public var methods: Methods {
        var methods = Methods()
        methods.query("server/info") { (_: NoParameters) in serverInfo() }
        methods.query("toolchain/check") { (query: ToolchainQuery) in await checkToolchain(query) }
        methods.query("devices/list") { (query: DestinationQuery) in try await listDestinations(of: query.host) }
        methods.query("index/describe") { (query: IndexQuery) in await describeIndex(of: query.host) }
        methods.query("tests/discover") { (query: TestDiscoveryQuery, caller: RequestContext) in
            try await discoverTests(for: query.host, in: try query.folderUri.map(FileURI.url) ?? Self.folder(of: caller))
        }
        methods.mutation("tests/run") { (request: TestRunRequest, context: OperationContext, caller: RequestContext) in
            try await Self.reporting(context) { reporter in
                try await runTests(request, in: try request.folderUri.map(FileURI.url) ?? Self.folder(of: caller), reporter: reporter.build)
            }
        }
        methods.query("index/clean") { (query: IndexQuery) in try await cleanIndex(in: query.rootUris ?? []) }
        methods.query("index/acquire") { (query: IndexQuery) in try await acquireIndex(query.host, rootUris: query.rootUris ?? []) }
        methods.mutation("repository/conformance") { (request: ConformanceRequest, context: OperationContext, caller: RequestContext) in
            try await Self.reporting(context) { reporter in
                try await runConformance(
                    request.host, selection: request.selection, record: request.record, device: request.device,
                    in: try Self.folder(of: caller), reporter: reporter.build)
            }
        }
        methods.mutation("repository/integrationPackage") { (request: IntegrationPackageRequest, context: OperationContext, caller: RequestContext) in
            try await Self.reporting(context) { reporter in
                try await packageIntegration(request.editor, in: try Self.folder(of: caller), reporter: reporter.build)
            }
        }
        methods.mutation("repository/integrationInstall") { (request: IntegrationInstallRequest, context: OperationContext) in
            try await Self.reporting(context) { reporter in try await installIntegration(request, reporter: reporter.build) }
        }
        methods.mutation("application/build") { (request: BuildRequest, context: OperationContext, caller: RequestContext) in
            try await Self.reporting(context) { reporter in
                try await build(request, in: try Self.folder(of: caller), operation: context.operationId, reporter: reporter.build)
            }
        }
        methods.mutation("application/package") { (request: BuildRequest, context: OperationContext, caller: RequestContext) in
            try await Self.reporting(context) { reporter in
                try await package(request, in: try Self.folder(of: caller), operation: context.operationId, reporter: reporter.build)
            }
        }
        methods.mutation("application/install") { (request: InstallRequest, _: OperationContext) in
            try await install(try FileURI.url(request.artifactUri))
        }
        methods.mutation("application/run") { (request: RunRequest, context: OperationContext, caller: RequestContext) in
            try await Self.reporting(context) { reporter in
                try await run(request, in: try Self.folder(of: caller), operation: context.operationId, reporter: reporter)
            }
        }
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
        methods.mutation("project/useLibrary") { (request: LibraryRequest, _: OperationContext, caller: RequestContext) in
            guard let uri = request.projectUri ?? caller.workspaceUri else {
                throw ToolingError(.projectNotFound, "No project is named, and the connection opened no workspace.")
            }
            return try await useLibrary(
                in: try FileURI.url(uri), checkout: try request.checkoutUri.map(FileURI.url), release: request.release,
                repository: request.repository)
        }
        methods.mutation("folder/mirror") { (request: FolderMirrorRequest, context: OperationContext) in
            try FolderMirror().mirror(request) { said in
                Task { await context.progress(OperationProgress(stage: "mirroring", message: said)) }
            }
        }
        methods.mutation("project/create") { (request: ApplicationRequest, _: OperationContext) in
            try await createApplication(
                request.name, identifier: request.identifier, platforms: request.platforms, in: try FileURI.url(request.parentUri),
                from: try request.checkoutUri.map(FileURI.url))
        }
        methods.query("settings/get") { (request: SettingsRequest, context: RequestContext) in
            guard let uri = request.projectUri ?? context.workspaceUri else {
                throw ToolingError(.projectNotFound, "No project is named, and the connection opened no workspace.")
            }
            return try settings(in: try FileURI.url(uri), application: request.application)
        }
        methods.mutation("settings/set") { (change: SettingsChange, _: OperationContext, caller: RequestContext) in
            guard let uri = change.projectUri ?? caller.workspaceUri else {
                throw ToolingError(.projectNotFound, "No project is named, and the connection opened no workspace.")
            }
            return try changeSettings(change, in: try FileURI.url(uri))
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

/// What a build said, kept in order on its way to an editor.
private enum Reported: Sendable {
    case progress(String)
    case output(ProcessOutput)
    case started(LaunchedApplication)
}
