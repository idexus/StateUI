// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A head of this machine's application built, packaged or run on another machine by that machine's own stateui, and
/// a host's own suite run there: in a guest of this Mac - started where it does not run, its stateui laid where it
/// stands not or speaks another API - or on a machine paired with the project, through its service; the project and
/// its checkout copied there, and the request asked of it.
/// Design: docs/design/tooling/service.md#work-on-another-machine
public struct RemoteWork: Sendable {
    /// A machine reached: its name, the destination it is told as, where the tool lays this machine's copies there -
    /// a folder of this machine's own - and its stateui answering this tool's work.
    struct Reached: Sendable {
        let name: String
        let destination: Destination
        let places: WorkPlaces
        let served: ServedTool
        /// The machine paired whose service answers - nil for a guest reached through `prlctl exec` - which a
        /// debugger's relay goes through.
        var remote: RemoteMachine?
    }

    /// A guest of this Mac readied by `prlctl exec`: running, its stateui laid from this checkout and answering.
    struct Readied: Sendable {
        let commands: GuestCommands
        let places: WorkPlaces
        let served: ServedTool
    }

    /// What a request is asked of on the machine: the machine reached, and where the application stands there.
    struct Ready: Sendable {
        let reached: Reached
        /// The application's folder there, as the machine's stateui names a project.
        let applicationUri: String
        let application: Application
        let project: Project
        /// The folder the copies were made from here, and where it stands there: what a debugger maps sources by.
        let common: URL
        let commonThere: String
    }

    let guests: ParallelsGuests
    /// The machines paired with the project.
    let remotes: [RemoteMachine]

    /// Whether `host`'s heads and suite are worked on another machine: in a guest of this Mac - GTK's and WinUI's -
    /// or, where this machine builds none, on a machine of `remotes` that runs them as its own programs.
    public static func elsewhere(_ host: HostFamily?, remotes: [RemoteMachine]) -> Bool {
        switch HostPlaces.place(of: host) {
        case .guest: true
        case nil: remotes.contains { machine in host.map(machine.machineHosts.contains) ?? false }
        default: false
        }
    }

    /// Whether a head of `host` on `device` is worked on another machine: a guest of this Mac where the host is worked
    /// in one, or a machine of `remotes` running the host as its own program.
    public static func asks(_ host: HostFamily?, device: String?, remotes: [RemoteMachine]) -> Bool {
        guard let host, let device else { return false }
        return HostPlaces.place(of: host) == .guest || remotes.contains { $0.name == device && $0.machineHosts.contains(host) }
    }

    /// Whether `request` is worked on another machine: on a machine of `remotes` its `machine` names, a device of that
    /// one's, or as `asks(_:device:remotes:)` says.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` where `machine` names none of `remotes` running the host on its
    ///   devices: a machine named is where the work goes, never this one instead.
    public static func asks(_ request: BuildRequest, remotes: [RemoteMachine]) throws -> Bool {
        guard let machine = request.machine else { return asks(request.host, device: request.device, remotes: remotes) }
        guard remotes.contains(where: { $0.name == machine && request.host.map($0.deviceHosts.contains) ?? false }) else {
            let host = request.host?.rawValue ?? "no host"
            throw ToolingError(.invalidConfiguration, "No machine paired with the project is \(machine) running \(host) on its devices - `stateui remote list` says which are.")
        }
        return true
    }

    /// Refuses what a run cannot start, as here, and a debugger for a head another machine starts on a device, a
    /// simulator or a browser: only a desktop head there - held by its `lldb-dap` - is reached from here, through the
    /// service's relay.
    /// Design: docs/design/tooling/service.md#a-debugger-relayed
    static func refuse(_ request: RunRequest) throws {
        try ApplicationRunner.refuse(request)
        if request.debugger, let host = request.build.host, !HostFamily.desktop.contains(host) {
            throw ToolingError(.invalidConfiguration, "A debugger reaches a desktop head on another machine alone - AppKit's, GTK's, WinUI's; run the \(host.rawValue) head there without one.")
        }
    }

    /// The destinations of `host` on the devices of `machines`, each asked within a few seconds - one that answers not
    /// lists none - each named by its machine.
    static func devices(of host: HostFamily, on machines: [RemoteMachine]) async -> [Destination] {
        await withTaskGroup(of: (Int, [Destination]).self) { group in
            for (index, machine) in machines.enumerated() {
                group.addTask {
                    let listed = try? await ServiceProbe.within(.seconds(15)) {
                        try await ServedTool(remote: machine, workspaceUri: "file:///")
                            .query("devices/list", try JSONValue(encoding: DestinationQuery(host: host))).decode(DestinationList.self)
                    }
                    return (index, (listed?.destinations ?? []).filter { $0.machine == nil }.map { each in
                        var theirs = each
                        theirs.machine = machine.name
                        return theirs
                    })
                }
            }
            return await group.reduce(into: [:]) { $0[$1.0] = $1.1 }.sorted { $0.key < $1.key }.flatMap(\.value)
        }
    }

    /// Builds `request` on its machine; the machine's answer, its destination said.
    func build(_ request: BuildRequest, in folder: URL, reporter: BuildReporter) async throws -> BuildResult {
        let ready = try await self.ready(request, in: folder, reporter: reporter)
        var asked = request
        (asked.projectUri, asked.device, asked.machine) = (ready.applicationUri, Self.theirDevice(of: request), nil)
        var built = try await ready.reached.served.operation("application/build", try JSONValue(encoding: asked), reporter: reporter)
            .decode(BuildResult.self)
        built.destination = Self.destination(built.destination, of: request, on: ready.reached)
        return built
    }

    /// Packages `request` on its machine into this one's output folder - its `outputUri`, else the project's
    /// `artifacts/<Name>/<Host>`, judged as a package's folder before the machine builds: it lays the package on its own
    /// disk, and this machine fetches it from there through the connection.
    func package(_ request: BuildRequest, in folder: URL, reporter: BuildReporter) async throws -> BuildResult {
        let ready = try await self.ready(request, in: folder, reporter: reporter)
        let places = ready.reached.places
        let host = request.host ?? .gtk
        let applicationFolder = try FileURI.url(ready.application.packageUri)
        let root = try ready.project.workspaceUri.map(FileURI.url) ?? applicationFolder
        let output = try request.outputUri.map(FileURI.url)
            ?? root.appendingPathComponent("artifacts").appendingPathComponent(ready.application.name).appendingPathComponent(host.folder)
        let keeping = [applicationFolder, root] + (try ready.application.libraryUri.map { [try FileURI.url($0)] } ?? [])
        try PackageOutput.check(output, keeping: keeping)
        let made = Self.packagePlace(of: ready.application.name, host: host, in: places)
        var asked = request
        (asked.projectUri, asked.device, asked.machine, asked.outputUri) = (
            ready.applicationUri, Self.theirDevice(of: request), nil, places.uri(of: made))
        var laid = try await ready.reached.served.operation("application/package", try JSONValue(encoding: asked), reporter: reporter)
            .decode(BuildResult.self)
        try PackageOutput.check(output, keeping: keeping)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        _ = try await ready.reached.served.session { session in
            try await FolderTransfer.fetch(made, into: output, over: session, progress: reporter.progress)
        }
        laid.destination = Self.destination(laid.destination, of: request, on: ready.reached)
        (laid.programUri, laid.bundleUri, laid.folderUri) = (
            Self.moved(laid.programUri, from: laid.folderUri, to: output), laid.bundleUri.map { Self.moved($0, from: laid.folderUri, to: output) },
            FileURI.string(output))
        return laid
    }

    /// Where a machine lays a package of `application` for `host` on its own disk, among this machine's `places` there:
    /// `stateui-guest/<client>/artifacts/<Name>/<Host>`.
    static func packagePlace(of application: String, host: HostFamily, in places: WorkPlaces) -> String {
        places.join(places.root, "artifacts", application, host.folder)
    }

    /// `uri`, a file inside the other machine's folder `folder`, as the same file inside this one's `output`.
    static func moved(_ uri: String, from folder: String, to output: URL) -> String {
        let inside = String(uri.dropFirst(min(uri.count, folder.count))).removingPercentEncoding ?? ""
        return FileURI.string(inside.split(separator: "/").reduce(output) { $0.appendingPathComponent(String($1)) })
    }

    /// Runs `request` on its machine and follows it until it ends; cancelled, it stops there. What a run cannot start is
    /// refused before the machine is touched.
    func run(_ request: RunRequest, in folder: URL, reporter: RunReporter) async throws -> RunResult {
        try Self.refuse(request)
        let ready = try await self.ready(request.build, in: folder, reporter: reporter.build)
        if request.debugger, ready.reached.remote == nil {
            throw ToolingError(
                .invalidConfiguration,
                "A debugger reaches \(ready.reached.name) through its service alone: pair it - `stateui guest pair --device \"\(ready.reached.name)\"`.")
        }
        var asked = request
        (asked.build.projectUri, asked.build.device, asked.build.machine) = (ready.applicationUri, Self.theirDevice(of: request.build), nil)
        let output = BuildReporter(progress: reporter.build.progress, output: reporter.output)
        let relays = Relays()
        defer { relays.end() }
        return try await ready.reached.served.operation(
            "application/run", try JSONValue(encoding: asked), reporter: output,
            started: { launched in self.started(launched, ready: ready, relays: relays, reporter: reporter) })
            .decode(RunResult.self)
    }

    /// Runs `host`'s own suite on the machine `device` names - the checkout at `checkout` copied there - `filter`ed where
    /// given, as that machine's stateui finds it; its phases as it says them.
    func test(_ host: HostFamily, filter: String?, device: String?, checkout: URL, reporter: BuildReporter) async throws -> SuiteResult {
        let reached = try await self.reached(device, host: host, checkout: checkout, reporter: reporter)
        let common = try await copied([checkout], into: reached, reporter: reporter)
        let there = reached.places.uri(of: reached.places.join([reached.places.root] + Self.relative(checkout, from: common)))
        let listed = try await reached.served.query("tests/discover", try JSONValue(encoding: TestDiscoveryQuery(host: host, folderUri: there)))
            .decode(TestSuiteList.self)
        guard let suite = listed.suites.first(where: { $0.kind == .host && $0.host == host }) else {
            throw ToolingError(.invalidConfiguration, "\(reached.name) finds no suite of \(host.folder) in its copy of \(checkout.path).")
        }
        return try await reached.served.operation(
            "tests/run", try JSONValue(encoding: TestRunRequest(suite: suite.id, host: host, folderUri: there, filter: filter)),
            reporter: reporter).decode(SuiteResult.self)
    }

    /// Runs `host`'s conformance families `selection` takes on the machine `device` names - the checkout at `checkout`
    /// copied there - held to the marks there, or recorded: the host's marks and what it declares then fetched into
    /// `checkout`, and its documents rendered here from them, a phase of its own.
    func conformance(
        _ host: HostFamily, selection: ConformanceSelection, record: Bool, device: String?, checkout: URL, reporter: BuildReporter
    ) async throws -> SuiteResult {
        let reached = try await self.reached(device, host: host, checkout: checkout, reporter: reporter)
        let common = try await copied([checkout], into: reached, reporter: reporter)
        let there = reached.places.join([reached.places.root] + Self.relative(checkout, from: common))
        var ran = try await reached.served.operation(
            "repository/conformance",
            try JSONValue(encoding: ConformanceRequest(host: host, selection: selection, record: record, folderUri: reached.places.uri(of: there))),
            reporter: reporter).decode(SuiteResult.self)
        guard record else { return ran }
        let exports = ["lib", "StateUI", "exports"]
        let marks = exports + ["marks", host.rawValue]
        let home = exports.reduce(checkout) { $0.appendingPathComponent($1) }
        let marksHome = marks.reduce(checkout) { $0.appendingPathComponent($1) }
        try FileManager.default.createDirectory(at: marksHome, withIntermediateDirectories: true)
        try await reached.served.session { session in
            _ = try await FolderTransfer.fetch(reached.places.join([there] + marks), into: marksHome, over: session, progress: reporter.progress)
            // The run wrote what the host declares beside its marks: left there, the next copy would write over it.
            _ = try await FolderTransfer.fetch(
                reached.places.join([there] + exports), files: ["\(host.rawValue).txt"], into: home, over: session,
                progress: reporter.progress)
        }
        var rendered = try await Handbook(checkout: checkout, tools: ToolResolver()).documents(update: true, reporter: reporter)
        rendered.name += " here from the marks fetched"
        ran.phases.append(rendered)
        return ran
    }

    /// Runs the `kind` plan of the checkout at `checkout` - its suite `only` where named - on the machine `device` names,
    /// the checkout copied there; its phases as that machine says them.
    func plan(_ kind: PlanKind, only: String?, device: String, checkout: URL, reporter: BuildReporter) async throws -> SuiteResult {
        let reached = try await self.reached(device, host: nil, checkout: checkout, reporter: reporter)
        let common = try await copied([checkout], into: reached, reporter: reporter)
        let there = reached.places.uri(of: reached.places.join([reached.places.root] + Self.relative(checkout, from: common)))
        return try await reached.served.operation(
            "repository/plan", try JSONValue(encoding: PlanRequest(kind: kind, only: only, folderUri: there)), reporter: reporter)
            .decode(SuiteResult.self)
    }

    /// The device `request` names on the machine that works it: one of that machine's where `machine` is named, else
    /// none - the machine itself is the destination.
    static func theirDevice(of request: BuildRequest) -> String? {
        request.machine == nil ? nil : request.device
    }

    /// The destination of a result `request` asked of `reached`: the device of that machine its own tool said, named
    /// by the machine, where one was asked for; else the machine itself.
    static func destination(_ theirs: Destination?, of request: BuildRequest, on reached: Reached) -> Destination? {
        guard request.machine != nil, var device = theirs else { return reached.destination }
        device.machine = reached.name
        return device
    }

    /// Whether `device` names a machine this one works on: a machine paired, or a guest of this Mac.
    func names(_ device: String) async -> Bool {
        if remotes.contains(where: { $0.name == device }) { return true }
        guard guests.prlctl != nil else { return false }
        return await guests.list().contains { $0.name == device || $0.id == device }
    }

    /// The machine `request` names, reached, with the application's project - its `projectUri`, else `folder`'s - and
    /// checkout copied into it.
    private func ready(_ request: BuildRequest, in folder: URL, reporter: BuildReporter) async throws -> Ready {
        let (project, application, library) = try await Self.meant(request, in: folder)
        let applicationFolder = try FileURI.url(application.packageUri)
        let projectRoot = try project.workspaceUri.map(FileURI.url) ?? applicationFolder
        let roots = Self.within(library, projectRoot) ? [projectRoot] : Self.within(projectRoot, library) ? [library] : [projectRoot, library]

        let reached = try await self.reached(
            request.machine ?? request.device, host: request.host, onItsDevice: request.machine != nil, checkout: library, reporter: reporter)
        let common = try await copied(roots, into: reached, reporter: reporter)
        let there = reached.places.join([reached.places.root] + Self.relative(applicationFolder, from: common))
        return Ready(
            reached: reached, applicationUri: reached.places.uri(of: there), application: application, project: project, common: common,
            commonThere: reached.places.join([reached.places.root] + Self.relative(common, from: common)))
    }

    /// The project `request` names - its `projectUri`, else `folder` - the application it means, and its checkout.
    static func meant(_ request: BuildRequest, in folder: URL) async throws -> (Project, Application, URL) {
        let folder = try request.projectUri.map(FileURI.url) ?? folder
        let project = try await ProjectReader().describe(containing: folder)
        let meant = FileURI.string(try ProjectReader.applicationFolder(named: request.application, containing: folder))
        guard let application = project.applications.first(where: { $0.packageUri == meant }),
              let library = try application.libraryUri.map(FileURI.url) else {
            throw ToolingError(.projectNotFound, "\(meant) names no application with a StateUI checkout.")
        }
        return (project, application, library)
    }

    /// The machine `device` names - for `host`'s work, or any work of the checkout where none is given - its stateui
    /// of the StateUI checkout `checkout` where this Mac lays it in its guest, answering this tool's work: a guest of
    /// this Mac, through its service where it is paired and answers, else `prlctl exec`; a machine paired, through its
    /// service.
    func reached(
        _ device: String?, host: HostFamily?, onItsDevice: Bool = false, checkout: URL, reporter: BuildReporter
    ) async throws -> Reached {
        guard let device else {
            throw ToolingError(.invalidConfiguration, "No machine is named for \(host?.folder ?? "the") work: `stateui devices` lists them.")
        }
        let paired = remotes.first { machine in
            machine.name == device && (host.map { onItsDevice ? machine.deviceHosts.contains($0) : machine.machineHosts.contains($0) } ?? true)
        }
        if !onItsDevice, host.map({ HostPlaces.place(of: $0) == .guest }) ?? true, guests.prlctl != nil || paired == nil {
            if let guest = try await guest(device, host: host, needed: paired == nil) {
                let readied = try await self.readied(guest, checkout: checkout, reporter: reporter)
                var (served, road, through) = (readied.served, "prlctl exec", RemoteMachine?.none)
                if let paired {
                    let network = ServedTool(remote: paired, workspaceUri: readied.places.uri(of: readied.places.root))
                    if await Self.speaks(network) { (served, road, through) = (network, "its service at \(paired.address):\(paired.port)", paired) }
                }
                reporter.progress("working in \(guest.name) through \(road)")
                return Reached(
                    name: guest.name, destination: ParallelsGuests.destination(of: guest), places: readied.places.of(try Self.client()),
                    served: served, remote: through)
            }
        }
        guard let paired else {
            let listed = host.map { "`stateui devices --host \($0.rawValue)`" } ?? "`stateui remote list`"
            throw ToolingError(.invalidConfiguration, "No guest or machine paired named \(device) works \(host.map { "\($0.folder) heads" } ?? "this checkout") here: \(listed) lists them.")
        }
        reporter.progress("working on \(paired.name) through its service at \(paired.address):\(paired.port)")
        return try await self.paired(paired)
    }

    /// The guest of this Mac `device` names, of `host`'s system where one is given; nil where none is and it is not
    /// `needed`.
    private func guest(_ device: String, host: HostFamily?, needed: Bool) async throws -> ParallelsGuests.Guest? {
        guard guests.prlctl != nil else {
            throw ToolingError(.missingToolchain, "Parallels Desktop's prlctl is not here: its Pro or Business edition has it.")
        }
        guard let guest = await guests.list().first(where: { $0.name == device || $0.id == device }) else {
            if needed { throw ToolingError(.invalidConfiguration, "No guest named \(device) stands here: `stateui devices` lists them.") }
            return nil
        }
        if let host, guest.system != ParallelsGuests.system(for: host) {
            throw ToolingError(.invalidConfiguration, "\(guest.name) runs \(guest.os): a \(host.folder) head is built in another system.")
        }
        return guest
    }

    /// `guest` running, its stateui - of the StateUI checkout `checkout` - laid where it stands not, was laid from other
    /// sources or speaks not this tool's work, and answering over `prlctl exec`.
    func readied(_ guest: ParallelsGuests.Guest, checkout: URL, reporter: BuildReporter) async throws -> Readied {
        guard let prlctl = guests.prlctl else {
            throw ToolingError(.missingToolchain, "Parallels Desktop's prlctl is not here: its Pro or Business edition has it.")
        }
        let commands = GuestCommands(prlctl: prlctl, guest: guest)
        try await running(commands, reporter: reporter)
        guard let places = await commands.places() else {
            throw ToolingError(.invalidConfiguration, "\(guest.name) runs nothing as its user: log in to its desktop.")
        }
        var served = await commands.served(places.tool, workspaceUri: places.uri(of: places.root))
        let preparation = GuestPreparation(commands: commands)
        let answers = await Self.speaks(served)
        if preparation.laidSources() != GuestPreparation.sources(of: checkout) || !answers {
            _ = try await preparation.lay(checkout: checkout, reporter: reporter)
            served = await commands.served(places.tool, workspaceUri: places.uri(of: places.root))
        }
        return Readied(commands: commands, places: places, served: served)
    }

    /// The machine `remote`, reached through its service: where it keeps another machine's work, as its service says,
    /// and its stateui of this release answering every method this work asks.
    private func paired(_ remote: RemoteMachine) async throws -> Reached {
        let info = try await ServedTool(remote: remote, workspaceUri: "file:///").query("server/info", .object([:])).decode(ServerInfo.self)
        let places = WorkPlaces(root: info.workFolder, windows: info.machine.system == "windows")
        let served = ServedTool(remote: remote, workspaceUri: places.uri(of: places.root))
        guard await Self.speaks(served) else {
            throw ToolingError(
                .invalidConfiguration,
                "\(remote.name)'s stateui is \(info.server.version), not \(Release.version), or answers not every method this work asks: lay this release there and start its service again (`stateui service restart`).")
        }
        var destination = HostPlaces.remote(remote)
        (destination.version, destination.architecture) = (info.machine.system, Architecture(rawValue: info.machine.architecture))
        return Reached(name: remote.name, destination: destination, places: places.of(try Self.client()), served: served, remote: remote)
    }

    /// The name this machine's work goes by on another: its identity's short form.
    static func client() throws(ToolingError) -> String {
        try MachineIdentity.current().short
    }

    /// Sends each of `roots` to the machine under `stateui-guest`, at its place from the folder they share, through the
    /// connection - what git tracks and would track; answers that folder.
    private func copied(_ roots: [URL], into reached: Reached, reporter: BuildReporter) async throws -> URL {
        let common = Self.commonFolder(of: roots)
        for root in roots {
            let target = reached.places.join([reached.places.root] + Self.relative(root, from: common))
            reporter.progress("copying \(root.lastPathComponent) to \(reached.name)")
            let files = await Self.gitFiles(in: root)
            _ = try await reached.served.session { session in
                try await FolderTransfer.send(root, files: files, to: target, over: session, progress: reporter.progress)
            }
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

    /// The methods another machine's stateui answers for this tool's work there.
    static let needed = [
        "folder/survey", "files/write", "file/read", "files/remove", "application/build", "application/package", "application/run",
        "tests/discover", "tests/run", "repository/conformance", "repository/plan",
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
            ProcessRequest(.name("git"), arguments: ["-C", folder.path, "-c", "core.quotePath=false", "ls-files", "--cached", "--others", "--exclude-standard"],
                           timeout: .seconds(120)),
            output: said.add), outcome.succeeded else { return nil }
        return said.lines(of: .standardOutput).filter { !$0.isEmpty }.map(unquoted)
    }

    /// The path git wrote as `line`: as it is, or within quotes with C's escapes - `\t`, `\n`, `\"`, `\\`, a byte in
    /// octal - for a name with such characters.
    static func unquoted(_ line: String) -> String {
        guard line.count >= 2, line.hasPrefix("\""), line.hasSuffix("\"") else { return line }
        let escapes: [UInt8: UInt8] = [
            UInt8(ascii: "a"): 0x07, UInt8(ascii: "b"): 0x08, UInt8(ascii: "t"): 0x09, UInt8(ascii: "n"): 0x0A,
            UInt8(ascii: "v"): 0x0B, UInt8(ascii: "f"): 0x0C, UInt8(ascii: "r"): 0x0D,
        ]
        var bytes = Array(line.utf8.dropFirst().dropLast())[...]
        var path: [UInt8] = []
        while let byte = bytes.popFirst() {
            guard byte == UInt8(ascii: "\\"), let next = bytes.popFirst() else { path.append(byte); continue }
            if (UInt8(ascii: "0")...UInt8(ascii: "7")).contains(next), bytes.count >= 2 {
                let digits = [next, bytes.removeFirst(), bytes.removeFirst()].map { $0 - UInt8(ascii: "0") }
                path.append(digits[0] << 6 | digits[1] << 3 | digits[2])
            } else {
                path.append(escapes[next] ?? next)
            }
        }
        return String(decoding: path, as: UTF8.self)
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
