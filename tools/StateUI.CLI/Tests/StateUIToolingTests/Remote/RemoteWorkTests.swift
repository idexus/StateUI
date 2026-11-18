// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class RemoteWorkTests: XCTestCase {
    private func guest(_ os: String) -> ParallelsGuests.Guest {
        ParallelsGuests.Guest(
            id: "id", name: "Guest", os: os, system: ParallelsGuests.system(of: os), state: "running", architecture: .arm64,
            shares: [:], sharesAllDisks: true, hasTools: true)
    }

    /// A machine's path is named to its stateui as a file URI of its own system, and its work folder - as a guest's
    /// home gives it, or as a service says it - holds its user's home.
    func testAMachinesPathIsAFileURIOfItsSystem() {
        let (linux, windows) = (WorkPlaces(home: "/home/me", windows: false), WorkPlaces(root: #"C:\Users\me\stateui-guest"#, windows: true))
        XCTAssertEqual(linux.uri(of: "/home/me/stateui-guest/My Apps"), "file:///home/me/stateui-guest/My%20Apps")
        XCTAssertEqual(windows.uri(of: #"C:\Users\me\stateui-guest\Demo"#), "file:///C:/Users/me/stateui-guest/Demo")
        XCTAssertEqual(linux.root, "/home/me/stateui-guest")
        XCTAssertEqual(linux.home, "/home/me")
        XCTAssertEqual(windows.home, #"C:\Users\me"#)
        XCTAssertEqual(WorkPlaces(home: windows.home, windows: true), windows)
    }

    /// Each machine's work stands in a folder of its own on another - named by its identity, made once and kept - so
    /// two machines working one project there never share a copy or a package.
    func testEachMachinesWorkStandsApart() throws {
        let state = FileManager.default.temporaryDirectory.appendingPathComponent("identity-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: state) }
        let made = try MachineIdentity.current(in: state)
        XCTAssertEqual(made.id.count, 64)
        XCTAssertEqual(try MachineIdentity.current(in: state), made, "kept")
        XCTAssertNotEqual(try MachineIdentity.current(in: state.appendingPathComponent("other")), made)
        XCTAssertEqual(made.short, String(made.id.prefix(12)))

        let (linux, windows) = (WorkPlaces(home: "/home/me", windows: false), WorkPlaces(home: #"C:\Users\me"#, windows: true))
        XCTAssertEqual(linux.of(made.short).root, "/home/me/stateui-guest/" + made.short)
        XCTAssertEqual(RemoteWork.packagePlace(of: "Demo", host: .winui, in: windows.of("a1b2c3")), #"C:\Users\me\stateui-guest\a1b2c3\artifacts\Demo\WinUI"#)

        try #"{"schemaVersion": 1, "id": "short"}"#.write(to: state.appendingPathComponent("identity.json"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try MachineIdentity.current(in: state))
    }

    /// A project and its checkout keep their places beside each other in the guest: each copied under the folder they
    /// share, so the manifests' paths between them hold; a project inside its checkout is copied with it.
    func testAProjectAndItsCheckoutKeepTheirPlaces() {
        let (project, checkout) = (URL(fileURLWithPath: "/Users/me/repos/Shop"), URL(fileURLWithPath: "/Users/me/repos/StateUI"))
        let common = RemoteWork.commonFolder(of: [project, checkout])
        XCTAssertEqual(common.path, "/Users/me/repos")
        XCTAssertEqual(RemoteWork.relative(project.appendingPathComponent("apps/Reader"), from: common), ["repos", "Shop", "apps", "Reader"])
        XCTAssertEqual(RemoteWork.relative(checkout, from: common), ["repos", "StateUI"])
        XCTAssertTrue(RemoteWork.within(checkout.appendingPathComponent("apps/Gallery"), checkout))
        XCTAssertEqual(RemoteWork.relative(checkout, from: checkout), ["StateUI"])
        XCTAssertEqual(RemoteWork.relative(checkout.appendingPathComponent("apps/Gallery"), from: checkout), ["StateUI", "apps", "Gallery"])
    }

    /// A guest lays a package on its own disk, under `stateui-guest`, and what it laid stands in the Mac's output at
    /// the same place: a path of the Mac named as a URI is no path a Windows guest reads.
    func testAGuestsPackageIsLaidOnItsOwnDiskThenOnTheMacs() {
        let windows = WorkPlaces(home: #"C:\Users\me"#, windows: true)
        let linux = WorkPlaces(home: "/home/me", windows: false)
        XCTAssertEqual(RemoteWork.packagePlace(of: "Demo", host: .winui, in: windows), #"C:\Users\me\stateui-guest\artifacts\Demo\WinUI"#)
        XCTAssertEqual(RemoteWork.packagePlace(of: "Demo", host: .gtk, in: linux), "/home/me/stateui-guest/artifacts/Demo/GTK")
        let output = URL(fileURLWithPath: "/Users/me/Shop/artifacts/Demo/WinUI")
        let made = windows.uri(of: RemoteWork.packagePlace(of: "Demo", host: .winui, in: windows))
        XCTAssertEqual(made, "file:///C:/Users/me/stateui-guest/artifacts/Demo/WinUI")
        XCTAssertEqual(RemoteWork.moved(made + "/DemoWinUI.exe", from: made, to: output), FileURI.string(output.appendingPathComponent("DemoWinUI.exe")))
        XCTAssertEqual(
            RemoteWork.moved("file:///home/me/stateui-guest/artifacts/My%20Demo/GTK/lib/My%20Demo", from: "file:///home/me/stateui-guest/artifacts/My%20Demo/GTK", to: output),
            FileURI.string(output.appendingPathComponent("lib").appendingPathComponent("My Demo")))
    }

    private func paired(_ name: String, runs hosts: [HostFamily]) -> RemoteMachine {
        RemoteMachine(
            name: name, address: "192.168.1.20", port: 7979, client: "c", token: "t", service: name.uppercased(),
            hosts: hosts.map { HostPlace(host: $0, place: .machine) })
    }

    /// A head goes to another machine where its device is a machine paired that runs its host as its own program, or
    /// for any device where this machine works its host in a guest; a host no machine paired runs, nor a guest, stays.
    func testAHeadGoesWhereItsDeviceRunsItsHost() {
        let office = paired("office", runs: [.winui])
        for host in HostFamily.allCases {
            let inGuest = HostPlaces.place(of: host) == .guest
            XCTAssertEqual(RemoteWork.asks(host, device: "office", remotes: [office]), inGuest || host == .winui, "\(host)")
            XCTAssertEqual(RemoteWork.asks(host, device: "elsewhere", remotes: [office]), inGuest, "\(host)")
            XCTAssertFalse(RemoteWork.asks(host, device: nil, remotes: [office]), "\(host) with no device")
            let builtHere = HostPlaces.place(of: host) != nil
            XCTAssertEqual(RemoteWork.elsewhere(host, remotes: [office]), inGuest || (!builtHere && host == .winui), "\(host)")
        }
    }

    /// A path git quotes - a tab, a quote, a backslash, a line feed, a byte it writes in octal - is the path itself;
    /// one it writes as it is stays so.
    func testAPathGitQuotesIsReadAsTheFileItNames() {
        XCTAssertEqual(RemoteWork.unquoted("Źródła.swift"), "Źródła.swift")
        XCTAssertEqual(RemoteWork.unquoted(#""a\tb.swift""#), "a\tb.swift")
        XCTAssertEqual(RemoteWork.unquoted(#""say \"hi\".swift""#), "say \"hi\".swift")
        XCTAssertEqual(RemoteWork.unquoted(#""back\\slash\nline.swift""#), "back\\slash\nline.swift")
        XCTAssertEqual(RemoteWork.unquoted(#""\305\271r\303\263d\305\202a.swift""#), "Źródła.swift")
    }

    /// Every file git tracks and would track is sent by the name it has, whatever git quotes.
    func testGitsFilesAreListedByTheirNames() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("gitfiles-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let names = ["Źródła.swift", "a\tb.swift", "say \"hi\".swift", "plain.swift"]
        for name in names { try Data(name.utf8).write(to: folder.appendingPathComponent(name)) }
        _ = try await ProcessRunner().run(ProcessRequest(.name("git"), arguments: ["-C", folder.path, "init", "-q"]), output: { _ in })
        let listed = await RemoteWork.gitFiles(in: folder)
        XCTAssertEqual(listed?.sorted(), names.sorted())
    }

    /// A request naming a machine paired goes there for a host that machine runs on its devices, its device the
    /// machine's own; a result names that machine beside the device its tool said.
    func testAMachinesDeviceIsNamedByTheMachine() throws {
        var mac = paired("studio", runs: [.appkit])
        mac.hosts += [HostPlace(host: .uikit, place: .device), HostPlace(host: .web, place: .browser)]
        XCTAssertEqual(mac.deviceHosts, [.uikit, .web])
        XCTAssertTrue(try RemoteWork.asks(BuildRequest(host: .uikit, device: "iPhone 18 Pro", machine: "studio"), remotes: [mac]))
        XCTAssertFalse(try RemoteWork.asks(BuildRequest(host: .uikit, device: "iPhone 18 Pro"), remotes: [mac]), "no machine named")
        // A machine named is where the work goes: one that is not there, or runs not the host on its devices, is refused
        // before anything is built - never worked here instead.
        XCTAssertThrowsError(try RemoteWork.asks(BuildRequest(host: .android, device: "Pixel", machine: "studio"), remotes: [mac]))
        XCTAssertThrowsError(try RemoteWork.asks(BuildRequest(host: .uikit, device: "iPhone 18 Pro", machine: "nowhere"), remotes: [mac]))
        XCTAssertTrue(HostPlaces.available(remotes: [mac]).contains { $0.host == .uikit })

        XCTAssertEqual(RemoteWork.theirDevice(of: BuildRequest(device: "iPhone 18 Pro", machine: "studio")), "iPhone 18 Pro")
        XCTAssertNil(RemoteWork.theirDevice(of: BuildRequest(device: "studio")), "the machine itself")
        let reached = RemoteWork.Reached(
            name: "studio", destination: HostPlaces.remote(mac), places: WorkPlaces(home: "/Users/me", windows: false),
            served: ServedTool(address: "127.0.0.1", port: 1, workspaceUri: "file:///"))
        let phone = Destination(id: "A1", udid: "A1", name: "iPhone 18 Pro", kind: .simulator, version: "27.0")
        XCTAssertEqual(RemoteWork.destination(phone, of: BuildRequest(device: "iPhone 18 Pro", machine: "studio"), on: reached)?.machine, "studio")
        XCTAssertEqual(RemoteWork.destination(phone, of: BuildRequest(device: "studio"), on: reached)?.kind, .remote)
    }

    /// A machine paired that runs a host on its devices or in its browsers lists them through its service, each named
    /// by the machine; one that answers not lists none.
    func testAPairedMachinesDevicesAreListedThroughIt() async throws {
        guard HostPlaces.here.contains(where: { $0.host == .web }) else { throw XCTSkip("this machine runs no browsers' heads") }
        let state = FileManager.default.temporaryDirectory.appendingPathComponent("devices-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: state) }
        let pairing = try ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office")
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0, pairing: pairing)
        let serving = Task { await listener.serve() }
        defer { serving.cancel() }
        let office = try await RemoteMachines(file: state.appendingPathComponent("remotes.json"))
            .pair(name: "office", address: "127.0.0.1", port: listener.port, code: pairing.code)
        XCTAssertTrue(office.deviceHosts.contains(.web))

        let own = try await ToolingService().listDestinations(of: .web)
        let theirs = await RemoteWork.devices(of: .web, on: [office])
        XCTAssertEqual(theirs.map(\.name), own.destinations.map(\.name))
        XCTAssertTrue(theirs.allSatisfy { $0.machine == "office" })
        var gone = office
        gone.port = 1
        let none = await RemoteWork.devices(of: .web, on: [gone])
        XCTAssertEqual(none, [])
    }

    /// A machine paired is reached through its service: its work kept where its service says, told as the machine
    /// it is, its stateui of this release answering every method the work asks; a name of no machine is refused.
    func testAMachinePairedIsReachedThroughItsService() async throws {
        let state = FileManager.default.temporaryDirectory.appendingPathComponent("remote-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: state) }
        let pairing = try ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office")
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0, pairing: pairing)
        let serving = Task { await listener.serve() }
        defer { serving.cancel() }
        let own = try XCTUnwrap(HostPlaces.here.first { $0.place == .machine }?.host)
        var office = try await RemoteMachines(file: state.appendingPathComponent("remotes.json"))
            .pair(name: "office", address: "127.0.0.1", port: listener.port, code: pairing.code)
        XCTAssertEqual(office.machineHosts, [own], "its hosts kept as its service said them")
        office.hosts = [HostPlace(host: own, place: .machine)]

        let work = RemoteWork(guests: ParallelsGuests(), remotes: [office])
        let reached = try await work.reached("office", host: own, checkout: state, reporter: BuildReporter())
        XCTAssertEqual(reached.name, "office")
        XCTAssertEqual(reached.destination.kind, .remote)
        XCTAssertEqual(reached.destination.version, Machine.current.system)
        let workFolder = WorkPlaces(root: HostPlaces.workFolder, windows: Machine.current.system == "windows")
        XCTAssertEqual(reached.places.root, workFolder.of(try RemoteWork.client()).root, "this machine's own folder there")
        let opening = try await reached.served.opening()
        XCTAssertEqual(opening.server.version, Release.version)

        do {
            _ = try await work.reached("nowhere", host: own, checkout: state, reporter: BuildReporter())
            XCTFail("a machine of no name was reached")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .invalidConfiguration)
            XCTAssertTrue(error.message.contains("nowhere"), error.message)
        }
    }

    /// The doctor of a machine paired says whether its service answers and admits this machine, its stateui's
    /// release, then what that stateui finds there - each finding of that machine; a service none answers for says so.
    func testTheDoctorOfAMachinePairedAsksItsService() async throws {
        let state = FileManager.default.temporaryDirectory.appendingPathComponent("doctor-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: state) }
        let pairing = try ServicePairing(file: state.appendingPathComponent("clients.json"), name: "Office")
        let listener = try ServiceListener.open(on: "127.0.0.1", port: 0, pairing: pairing)
        let serving = Task { await listener.serve() }
        defer { serving.cancel() }
        let own = try XCTUnwrap(HostPlaces.here.first { $0.place == .machine }?.host)
        let office = try await RemoteMachines(file: state.appendingPathComponent("remotes.json"))
            .pair(name: "office", address: "127.0.0.1", port: listener.port, code: pairing.code)

        let report = await RemoteDoctor().check(host: own, machine: office)
        XCTAssertEqual(report.findings.first?.component, "the service of office")
        XCTAssertNotNil(report.findings.first?.found)
        XCTAssertEqual(report.findings.first { $0.component == "stateui on office" }?.found, Release.version)
        XCTAssertGreaterThan(report.findings.count, 2, "what its stateui finds there")
        XCTAssertTrue(report.findings.allSatisfy { $0.machine == "office" })

        var gone = office
        gone.port = 1
        let unreached = await RemoteDoctor().check(host: own, machine: gone)
        XCTAssertEqual(unreached.findings.count, 1)
        XCTAssertNil(unreached.findings[0].found)
        XCTAssertTrue(unreached.findings[0].advice.contains("stateui service install"), unreached.findings[0].advice)
    }

    /// The application worked elsewhere is the one the request's project names, wherever the command stands: an
    /// application named by its folder from a workspace's root, not the workspace's application to start.
    func testTheApplicationWorkedIsTheOneTheRequestNames() async throws {
        let checkout = ProjectReaderTests.repository
        let gallery = checkout.appendingPathComponent("apps/Gallery")
        guard FileManager.default.fileExists(atPath: gallery.appendingPathComponent(ApplicationFile.name).path) else {
            throw XCTSkip("no checkout's Gallery beside the tool")
        }
        let (_, application, library) = try await RemoteWork.meant(BuildRequest(projectUri: FileURI.string(gallery)), in: checkout)
        XCTAssertEqual(application.name, "Gallery")
        XCTAssertEqual(library.standardizedFileURL.path, RealPath.of(checkout).standardizedFileURL.path)
    }

    /// A WinUI run under gdb on another machine is refused here, before the machine is reached or anything copied; a
    /// GTK one goes on - to run under gdb there - and fails only on what it reaches.
    func testARunUnderGDBElsewhereIsRefusedFirst() async throws {
        let nowhere = FileManager.default.temporaryDirectory.appendingPathComponent("run-\(UUID().uuidString)")
        for (host, refused) in [(HostFamily.winui, true), (.gtk, false)] {
            let request = RunRequest(build: BuildRequest(host: host, device: "No Such Guest"), gdb: true)
            do {
                _ = try await RemoteWork(guests: ParallelsGuests(), remotes: []).run(request, in: nowhere, reporter: RunReporter())
                XCTFail("\(host) ran")
            } catch let error as ToolingError {
                XCTAssertEqual(error.message.contains("alone runs under gdb"), refused, "\(host): \(error.message)")
            }
        }
    }

    /// A guest's stateui is laid again whenever the tool's sources differ from those it was laid from: the fingerprint
    /// follows every file's bytes and path, and not what a build makes.
    func testTheToolsSourcesAreFingerprinted() throws {
        let checkout = FileManager.default.temporaryDirectory.appendingPathComponent("tool-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: checkout) }
        let tool = checkout.appendingPathComponent("tools/StateUI.CLI")
        func write(_ text: String, _ path: String) throws {
            let file = tool.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        }
        try write("let a = 1", "Sources/A.swift")
        let first = GuestPreparation.sources(of: checkout)
        try write("made", ".build/release/stateui")
        XCTAssertEqual(GuestPreparation.sources(of: checkout), first, "a build's own files")
        try write("let a = 2", "Sources/A.swift")
        let edited = GuestPreparation.sources(of: checkout)
        XCTAssertNotEqual(edited, first)
        try FileManager.default.moveItem(at: tool.appendingPathComponent("Sources/A.swift"), to: tool.appendingPathComponent("Sources/B.swift"))
        XCTAssertNotEqual(GuestPreparation.sources(of: checkout), edited, "a file renamed")

        let stamps = checkout.appendingPathComponent("stamps")
        let preparation = GuestPreparation(commands: GuestCommands(prlctl: URL(fileURLWithPath: "/nowhere"), guest: guest("ubuntu")), stamps: stamps)
        XCTAssertNil(preparation.laidSources())
        try FileManager.default.createDirectory(at: stamps, withIntermediateDirectories: true)
        try "abc".write(to: stamps.appendingPathComponent("id.tool"), atomically: true, encoding: .utf8)
        XCTAssertEqual(preparation.laidSources(), "abc")
    }

    /// What is copied is what git tracks and would track - an ignored file left out - and nothing where no git work
    /// tree stands.
    func testTheFilesCopiedAreWhatGitTracksAndWouldTrack() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let outside = await RemoteWork.gitFiles(in: folder)
        XCTAssertNil(outside)
        _ = try await ProcessRunner().run(ProcessRequest(.name("git"), arguments: ["-C", folder.path, "init", "-q"]), output: { _ in })
        for (name, text) in [("A.swift", "a"), (".gitignore", "key.js\n"), ("key.js", "secret")] {
            try text.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let tracked = await RemoteWork.gitFiles(in: folder)
        XCTAssertEqual(tracked.map { Set($0) }, [".gitignore", "A.swift"])
    }
}
