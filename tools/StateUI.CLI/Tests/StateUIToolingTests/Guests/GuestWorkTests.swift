// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class GuestWorkTests: XCTestCase {
    private func guest(_ os: String) -> ParallelsGuests.Guest {
        ParallelsGuests.Guest(
            id: "id", name: "Guest", os: os, system: ParallelsGuests.system(of: os), state: "running", architecture: .arm64,
            shares: [:], sharesAllDisks: true, hasTools: true)
    }

    /// A guest's path is named to its stateui as a file URI of its own system.
    func testAGuestsPathIsAFileURIOfItsSystem() {
        XCTAssertEqual(GuestWork.uri(of: "/home/me/stateui-guest/My Apps", in: guest("ubuntu")), "file:///home/me/stateui-guest/My%20Apps")
        XCTAssertEqual(GuestWork.uri(of: #"C:\Users\me\stateui-guest\Demo"#, in: guest("win-11")), "file:///C:/Users/me/stateui-guest/Demo")
    }

    /// A project and its checkout keep their places beside each other in the guest: each copied under the folder they
    /// share, so the manifests' paths between them hold; a project inside its checkout is copied with it.
    func testAProjectAndItsCheckoutKeepTheirPlaces() {
        let (project, checkout) = (URL(fileURLWithPath: "/Users/me/repos/Shop"), URL(fileURLWithPath: "/Users/me/repos/StateUI"))
        let common = GuestWork.commonFolder(of: [project, checkout])
        XCTAssertEqual(common.path, "/Users/me/repos")
        XCTAssertEqual(GuestWork.relative(project.appendingPathComponent("apps/Reader"), from: common), ["repos", "Shop", "apps", "Reader"])
        XCTAssertEqual(GuestWork.relative(checkout, from: common), ["repos", "StateUI"])
        XCTAssertTrue(GuestWork.within(checkout.appendingPathComponent("apps/Gallery"), checkout))
        XCTAssertEqual(GuestWork.relative(checkout, from: checkout), ["StateUI"])
        XCTAssertEqual(GuestWork.relative(checkout.appendingPathComponent("apps/Gallery"), from: checkout), ["StateUI", "apps", "Gallery"])
    }

    /// A run in a guest held for a debugger is refused on the Mac, before the guest is started or anything copied.
    func testAGuestRunHeldForADebuggerIsRefusedFirst() async throws {
        let nowhere = FileManager.default.temporaryDirectory.appendingPathComponent("run-\(UUID().uuidString)")
        for host in [HostFamily.gtk, .winui] {
            let request = RunRequest(build: BuildRequest(host: host, device: "No Such Guest"), debugger: true)
            do {
                _ = try await GuestWork(guests: ParallelsGuests()).run(request, in: nowhere, reporter: RunReporter())
                XCTFail("\(host) ran")
            } catch let error as ToolingError {
                XCTAssertEqual(error.code, .invalidConfiguration)
                XCTAssertTrue(error.message.contains("head is debugged from the program"), error.message)
            }
        }
    }

    /// What is copied is what git tracks and would track - an ignored file left out - and nothing where no git work
    /// tree stands.
    func testTheFilesCopiedAreWhatGitTracksAndWouldTrack() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let outside = await GuestWork.gitFiles(in: folder)
        XCTAssertNil(outside)
        _ = try await ProcessRunner().run(ProcessRequest(.name("git"), arguments: ["-C", folder.path, "init", "-q"]), output: { _ in })
        for (name, text) in [("A.swift", "a"), (".gitignore", "key.js\n"), ("key.js", "secret")] {
            try text.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let tracked = await GuestWork.gitFiles(in: folder)
        XCTAssertEqual(tracked.map { Set($0) }, [".gitignore", "A.swift"])
    }
}
