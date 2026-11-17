// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A GTK or WinUI head of a Mac's application built, packaged or run in a guest of the Mac by the guest's own stateui:
/// the guest started where it does not run, its stateui laid where it stands not or speaks another API, the project
/// and its checkout copied into it, and the request asked of it there.
/// Design: docs/design/tooling/guests.md#a-head-worked-in-a-guest
public struct GuestWork: Sendable {
    /// What a request is asked of in the guest: the guest's stateui, served, and where the application stands there.
    struct Ready: Sendable {
        let guest: ParallelsGuests.Guest
        let commands: GuestCommands
        let served: ServedTool
        /// The application's folder in the guest, as the guest's stateui names a project.
        let applicationUri: String
        let application: Application
        let project: Project
    }

    let guests: ParallelsGuests

    /// Whether `request` is for a guest: a GTK or WinUI head with a device, on a Mac.
    public static func asks(_ request: BuildRequest) -> Bool {
        #if os(macOS)
        [.gtk, .winui].contains(request.host) && request.device != nil
        #else
        false
        #endif
    }

    /// Builds `request` in its guest; the guest's answer, its device said.
    func build(_ request: BuildRequest, in folder: URL, reporter: BuildReporter) async throws -> BuildResult {
        let ready = try await self.ready(request, in: folder, reporter: reporter)
        var asked = request
        (asked.projectUri, asked.device) = (ready.applicationUri, nil)
        var built = try await ready.served.operation("application/build", try JSONValue(encoding: asked), reporter: reporter)
            .decode(BuildResult.self)
        built.destination = ParallelsGuests.destination(of: ready.guest)
        return built
    }

    /// Packages `request` in its guest into the Mac's output folder - its `outputUri`, else the project's
    /// `artifacts/<Name>/<Host>` - which the guest writes through the folder it shares.
    func package(_ request: BuildRequest, in folder: URL, reporter: BuildReporter) async throws -> BuildResult {
        let ready = try await self.ready(request, in: folder, reporter: reporter)
        let host = request.host ?? .gtk
        let root = try ready.project.workspaceUri.map(FileURI.url) ?? FileURI.url(ready.application.packageUri)
        let output = try request.outputUri.map(FileURI.url)
            ?? root.appendingPathComponent("artifacts").appendingPathComponent(ready.application.name).appendingPathComponent(host.folder)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard let there = ready.guest.path(of: output) else {
            throw ToolingError(.invalidConfiguration, "\(ready.guest.name) reaches no \(output.path): share it with the guest.")
        }
        var asked = request
        (asked.projectUri, asked.device, asked.outputUri) = (ready.applicationUri, nil, Self.uri(of: there, in: ready.guest))
        var laid = try await ready.served.operation("application/package", try JSONValue(encoding: asked), reporter: reporter)
            .decode(BuildResult.self)
        laid.destination = ParallelsGuests.destination(of: ready.guest)
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
        return try await ready.served.operation(
            "application/run", try JSONValue(encoding: asked), reporter: output, started: reporter.started)
            .decode(RunResult.self)
    }

    /// The guest `request` names, running, with its stateui laid and the project copied into it.
    private func ready(_ request: BuildRequest, in folder: URL, reporter: BuildReporter) async throws -> Ready {
        guard let prlctl = guests.prlctl else {
            throw ToolingError(.missingToolchain, "Parallels Desktop's prlctl is not here: its Pro or Business edition has it.")
        }
        guard let device = request.device, let host = request.host,
              let guest = await guests.list().first(where: { $0.name == device || $0.id == device }) else {
            throw ToolingError(.invalidConfiguration, "No guest named \(request.device ?? "") stands here: `stateui devices` lists them.")
        }
        guard guest.system == ParallelsGuests.system(for: host) else {
            throw ToolingError(.invalidConfiguration, "\(guest.name) runs \(guest.os): a \(host.folder) head is built in another system.")
        }
        let commands = GuestCommands(prlctl: prlctl, guest: guest)
        try await running(commands, reporter: reporter)
        guard let places = await commands.places() else {
            throw ToolingError(.invalidConfiguration, "\(guest.name) runs nothing as its user: log in to its desktop.")
        }

        let project = try await ProjectReader().describe(containing: folder)
        let meant = FileURI.string(try ProjectReader.applicationFolder(named: request.application, containing: folder))
        guard let application = project.applications.first(where: { $0.packageUri == meant }),
              let library = try application.libraryUri.map(FileURI.url) else {
            throw ToolingError(.projectNotFound, "\(meant) names no application with a StateUI checkout.")
        }
        let applicationFolder = try FileURI.url(application.packageUri)
        let projectRoot = try project.workspaceUri.map(FileURI.url) ?? applicationFolder
        let roots = Self.within(library, projectRoot) ? [projectRoot] : Self.within(projectRoot, library) ? [library] : [projectRoot, library]
        let common = Self.commonFolder(of: roots)

        var served = await commands.served(places.tool, workspaceUri: Self.uri(of: places.root, in: guest))
        if !(await Self.speaks(served)) {
            _ = try await GuestPreparation(commands: commands).lay(checkout: library, reporter: reporter)
            served = await commands.served(places.tool, workspaceUri: Self.uri(of: places.root, in: guest))
        }
        for root in roots {
            guard let source = guest.path(of: root) else {
                throw ToolingError(.invalidConfiguration, "\(guest.name) reaches no \(root.path): share it with the guest.")
            }
            let target = places.join([places.root] + Self.relative(root, from: common))
            reporter.progress("copying \(root.lastPathComponent) into \(guest.name)")
            let files = await Self.gitFiles(in: root)
            _ = try await served.operation(
                "folder/mirror", try JSONValue(encoding: FolderMirrorRequest(sourcePath: source, targetPath: target, files: files)),
                reporter: reporter)
        }
        let there = places.join([places.root] + Self.relative(applicationFolder, from: common))
        return Ready(
            guest: guest, commands: commands, served: served, applicationUri: Self.uri(of: there, in: guest),
            application: application, project: project)
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
    static let needed = ["folder/mirror", "application/build", "application/package", "application/run"]

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
