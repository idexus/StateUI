// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A GTK or WinUI head of a Mac's application built, packaged or run in a guest of the Mac by the guest's own stateui,
/// and the host's own suite run there: the guest started where it does not run, its stateui laid where it stands not
/// or speaks another API, the project and its checkout copied into it, and the request asked of it there.
/// Design: docs/design/tooling/guests.md#a-head-worked-in-a-guest
public struct GuestWork: Sendable {
    /// A guest running, its stateui answering this tool's work, and where the tool lays its copies in it.
    struct Reached: Sendable {
        let guest: ParallelsGuests.Guest
        let commands: GuestCommands
        let places: GuestPlaces
        let served: ServedTool
    }

    /// What a request is asked of in the guest: the guest reached, and where the application stands there.
    struct Ready: Sendable {
        let reached: Reached
        /// The application's folder in the guest, as the guest's stateui names a project.
        let applicationUri: String
        let application: Application
        let project: Project
    }

    let guests: ParallelsGuests

    /// Whether this machine works `host`'s heads and suite in a guest of its own: GTK's and WinUI's, on a Mac.
    public static func inGuest(_ host: HostFamily?) -> Bool {
        #if os(macOS)
        [.gtk, .winui].contains(host)
        #else
        false
        #endif
    }

    /// Whether `request` is for a guest: a GTK or WinUI head with a device, on a Mac.
    public static func asks(_ request: BuildRequest) -> Bool {
        inGuest(request.host) && request.device != nil
    }

    /// Builds `request` in its guest; the guest's answer, its device said.
    func build(_ request: BuildRequest, in folder: URL, reporter: BuildReporter) async throws -> BuildResult {
        let ready = try await self.ready(request, in: folder, reporter: reporter)
        var asked = request
        (asked.projectUri, asked.device) = (ready.applicationUri, nil)
        var built = try await ready.reached.served.operation("application/build", try JSONValue(encoding: asked), reporter: reporter)
            .decode(BuildResult.self)
        built.destination = ParallelsGuests.destination(of: ready.reached.guest)
        return built
    }

    /// Packages `request` in its guest into the Mac's output folder - its `outputUri`, else the project's
    /// `artifacts/<Name>/<Host>` - which the guest writes through the folder it shares.
    func package(_ request: BuildRequest, in folder: URL, reporter: BuildReporter) async throws -> BuildResult {
        let ready = try await self.ready(request, in: folder, reporter: reporter)
        let guest = ready.reached.guest
        let host = request.host ?? .gtk
        let root = try ready.project.workspaceUri.map(FileURI.url) ?? FileURI.url(ready.application.packageUri)
        let output = try request.outputUri.map(FileURI.url)
            ?? root.appendingPathComponent("artifacts").appendingPathComponent(ready.application.name).appendingPathComponent(host.folder)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard let there = guest.path(of: output) else {
            throw ToolingError(.invalidConfiguration, "\(guest.name) reaches no \(output.path): share it with the guest.")
        }
        var asked = request
        (asked.projectUri, asked.device, asked.outputUri) = (ready.applicationUri, nil, Self.uri(of: there, in: guest))
        var laid = try await ready.reached.served.operation("application/package", try JSONValue(encoding: asked), reporter: reporter)
            .decode(BuildResult.self)
        laid.destination = ParallelsGuests.destination(of: guest)
        // What the guest laid in the folder it shares stands on the Mac at the same place inside the output.
        let inside = { (uri: String) in
            FileURI.string(output.appendingPathComponent(String(uri.dropFirst(min(uri.count, laid.folderUri.count))).removingPercentEncoding?
                .split(separator: "/").joined(separator: "/") ?? ""))
        }
        (laid.programUri, laid.bundleUri, laid.folderUri) = (inside(laid.programUri), laid.bundleUri.map(inside), FileURI.string(output))
        return laid
    }

    /// Runs `request` in its guest and follows it until it ends; cancelled, it stops there. What a run cannot start is
    /// refused before the guest is touched.
    func run(_ request: RunRequest, in folder: URL, reporter: RunReporter) async throws -> RunResult {
        try ApplicationRunner.refuse(request)
        let ready = try await self.ready(request.build, in: folder, reporter: reporter.build)
        var asked = request
        (asked.build.projectUri, asked.build.device) = (ready.applicationUri, nil)
        let output = BuildReporter(progress: reporter.build.progress, output: reporter.output)
        return try await ready.reached.served.operation(
            "application/run", try JSONValue(encoding: asked), reporter: output, started: reporter.started)
            .decode(RunResult.self)
    }

    /// Runs `host`'s own suite in the guest `device` names - the checkout at `checkout` copied there - `filter`ed where
    /// given, as the guest's stateui finds it; its phases as the guest says them.
    func test(_ host: HostFamily, filter: String?, device: String?, checkout: URL, reporter: BuildReporter) async throws -> SuiteResult {
        let reached = try await self.reached(device, host: host, checkout: checkout, reporter: reporter)
        let common = try await copied([checkout], into: reached, reporter: reporter)
        let there = Self.uri(of: reached.places.join([reached.places.root] + Self.relative(checkout, from: common)), in: reached.guest)
        let listed = try await reached.served.query("tests/discover", try JSONValue(encoding: TestDiscoveryQuery(host: host, folderUri: there)))
            .decode(TestSuiteList.self)
        guard let suite = listed.suites.first(where: { $0.kind == .host && $0.host == host }) else {
            throw ToolingError(.invalidConfiguration, "\(reached.guest.name) finds no suite of \(host.folder) in its copy of \(checkout.path).")
        }
        return try await reached.served.operation(
            "tests/run", try JSONValue(encoding: TestRunRequest(suite: suite.id, host: host, folderUri: there, filter: filter)),
            reporter: reporter).decode(SuiteResult.self)
    }

    /// The guest `request` names, reached, with the application's project and checkout copied into it.
    private func ready(_ request: BuildRequest, in folder: URL, reporter: BuildReporter) async throws -> Ready {
        let project = try await ProjectReader().describe(containing: folder)
        let meant = FileURI.string(try ProjectReader.applicationFolder(named: request.application, containing: folder))
        guard let application = project.applications.first(where: { $0.packageUri == meant }),
              let library = try application.libraryUri.map(FileURI.url) else {
            throw ToolingError(.projectNotFound, "\(meant) names no application with a StateUI checkout.")
        }
        let applicationFolder = try FileURI.url(application.packageUri)
        let projectRoot = try project.workspaceUri.map(FileURI.url) ?? applicationFolder
        let roots = Self.within(library, projectRoot) ? [projectRoot] : Self.within(projectRoot, library) ? [library] : [projectRoot, library]

        let reached = try await self.reached(request.device, host: request.host, checkout: library, reporter: reporter)
        let common = try await copied(roots, into: reached, reporter: reporter)
        let there = reached.places.join([reached.places.root] + Self.relative(applicationFolder, from: common))
        return Ready(reached: reached, applicationUri: Self.uri(of: there, in: reached.guest), application: application, project: project)
    }

    /// The guest `device` names, of `host`'s system, running, its stateui - of the StateUI checkout `checkout` -
    /// answering this tool's work.
    private func reached(_ device: String?, host: HostFamily?, checkout: URL, reporter: BuildReporter) async throws -> Reached {
        guard let prlctl = guests.prlctl else {
            throw ToolingError(.missingToolchain, "Parallels Desktop's prlctl is not here: its Pro or Business edition has it.")
        }
        guard let device, let host, let guest = await guests.list().first(where: { $0.name == device || $0.id == device }) else {
            throw ToolingError(.invalidConfiguration, "No guest named \(device ?? "") stands here: `stateui devices` lists them.")
        }
        guard guest.system == ParallelsGuests.system(for: host) else {
            throw ToolingError(.invalidConfiguration, "\(guest.name) runs \(guest.os): a \(host.folder) head is built in another system.")
        }
        let commands = GuestCommands(prlctl: prlctl, guest: guest)
        try await running(commands, reporter: reporter)
        guard let places = await commands.places() else {
            throw ToolingError(.invalidConfiguration, "\(guest.name) runs nothing as its user: log in to its desktop.")
        }
        var served = await commands.served(places.tool, workspaceUri: Self.uri(of: places.root, in: guest))
        let preparation = GuestPreparation(commands: commands)
        let answers = await Self.speaks(served)
        if preparation.laidSources() != GuestPreparation.sources(of: checkout) || !answers {
            _ = try await preparation.lay(checkout: checkout, reporter: reporter)
            served = await commands.served(places.tool, workspaceUri: Self.uri(of: places.root, in: guest))
        }
        return Reached(guest: guest, commands: commands, places: places, served: served)
    }

    /// Copies each of `roots` into the guest under `stateui-guest`, at its place from the folder they share; answers that
    /// folder.
    private func copied(_ roots: [URL], into reached: Reached, reporter: BuildReporter) async throws -> URL {
        let common = Self.commonFolder(of: roots)
        for root in roots {
            guard let source = reached.guest.path(of: root) else {
                throw ToolingError(.invalidConfiguration, "\(reached.guest.name) reaches no \(root.path): share it with the guest.")
            }
            let target = reached.places.join([reached.places.root] + Self.relative(root, from: common))
            reporter.progress("copying \(root.lastPathComponent) into \(reached.guest.name)")
            let files = await Self.gitFiles(in: root)
            _ = try await reached.served.operation(
                "folder/mirror", try JSONValue(encoding: FolderMirrorRequest(sourcePath: source, targetPath: target, files: files)),
                reporter: reporter)
        }
        return common
    }

    /// Starts or resumes the guest where it does not run, and waits for its user's desktop session.
    private func running(_ commands: GuestCommands, reporter: BuildReporter) async throws {
        let guest = commands.guest
        if guest.state != "running" {
            reporter.progress("\(guest.state == "suspended" || guest.state == "paused" ? "resuming" : "starting") \(guest.name)")
            let verb = guest.state == "suspended" || guest.state == "paused" ? "resume" : "start"
            _ = try await ProcessRunner().run(
                ProcessRequest(.path(commands.prlctl.path), arguments: [verb, guest.id], timeout: .seconds(180)), output: { _ in })
        }
        for _ in 0..<60 {
            if await commands.userSession() { return }
            try await Task.sleep(for: .seconds(3))
        }
        throw ToolingError(.invalidConfiguration, "\(guest.name) runs nothing as its user: log in to its desktop.")
    }

    /// The methods a guest's stateui answers for this tool's work there.
    static let needed = [
        "folder/mirror", "application/build", "application/package", "application/run", "tests/discover", "tests/run",
    ]

    /// Whether `served` opens a connection - at an API version this tool speaks - as this release, and answers every
    /// method `needed`.
    private static func speaks(_ served: ServedTool) async -> Bool {
        guard let opening = try? await served.opening() else { return false }
        return opening.server.version == Release.version && needed.allSatisfy(opening.capabilities.methods.contains)
    }

    /// The files git tracks and would track in `folder`, by their paths from it; nil where `folder` is no git work tree.
    static func gitFiles(in folder: URL) async -> [String]? {
        let said = Gathered()
        guard let outcome = try? await ProcessRunner().run(
            ProcessRequest(.name("git"), arguments: ["-C", folder.path, "ls-files", "--cached", "--others", "--exclude-standard"],
                           timeout: .seconds(120)),
            output: said.add), outcome.succeeded else { return nil }
        return said.lines(of: .standardOutput).filter { !$0.isEmpty }
    }

    /// `path`, a path of `guest`, as a file URI its stateui reads.
    static func uri(of path: String, in guest: ParallelsGuests.Guest) -> String {
        let slashed = guest.system == .windows ? "/" + path.replacingOccurrences(of: "\\", with: "/") : path
        return "file://" + (slashed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slashed)
    }

    static func within(_ folder: URL, _ holder: URL) -> Bool {
        let (inner, outer) = (folder.standardizedFileURL.pathComponents, holder.standardizedFileURL.pathComponents)
        return inner.starts(with: outer)
    }

    static func commonFolder(of folders: [URL]) -> URL {
        let paths = folders.map { $0.standardizedFileURL.pathComponents }
        var shared = paths.first ?? []
        for path in paths.dropFirst() { shared = Array(zip(shared, path).prefix { $0 == $1 }.map(\.0)) }
        return URL(fileURLWithPath: NSString.path(withComponents: shared))
    }

    /// `folder`'s path from `holder`, by its folders' names; the last name alone where it is `holder` itself.
    static func relative(_ folder: URL, from holder: URL) -> [String] {
        let (inner, outer) = (folder.standardizedFileURL.pathComponents, holder.standardizedFileURL.pathComponents)
        let rest = Array(inner.dropFirst(outer.count))
        return rest.isEmpty ? [folder.lastPathComponent] : [holder.lastPathComponent] + rest
    }
}
