// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class HostPlacesTests: XCTestCase {
    /// A Mac builds AppKit as its own program, UIKit and Android on devices, WinUI and GTK in its guests and the Web in
    /// browsers; Linux GTK and the Web; Windows WinUI - in the matrix's order.
    func testEachSystemSaysItsHostsAndWhereTheyRun() {
        let said = { (system: String) in HostPlaces.of(system: system).map { "\($0.host.rawValue):\($0.place.rawValue)" } }
        XCTAssertEqual(said("macos"), ["appkit:machine", "uikit:device", "android:device", "winui:guest", "gtk:guest", "web:browser"])
        XCTAssertEqual(said("linux"), ["gtk:machine", "web:browser"])
        XCTAssertEqual(said("windows"), ["winui:machine"])
        XCTAssertEqual(said("freebsd"), [])
    }

    /// A head that runs as this machine's own program has this machine as its destination, a debugger reaching it -
    /// an ARM64 Windows running x86_64 emulated, which a WinUI head is built for too.
    func testThisMachineIsTheDestinationOfItsOwnPrograms() {
        let windows = HostPlaces.machine(Machine(system: "windows", architecture: "arm64"))
        XCTAssertEqual(windows.kind, .machine)
        XCTAssertEqual(windows.architecture, .arm64)
        XCTAssertEqual(windows.emulated, [.x86_64])
        XCTAssertTrue(windows.debugger)
        XCTAssertEqual(HostPlaces.machine(Machine(system: "windows", architecture: "x86_64")).emulated, [])
        XCTAssertEqual(HostPlaces.machine(Machine(system: "macos", architecture: "arm64")).emulated, [])
    }

    /// The server tells a client the same list, and a host this machine builds in a guest is worked there alone.
    func testTheServerAndTheGuestWorkReadTheSameList() async throws {
        XCTAssertEqual(ToolingService().serverInfo().hosts, HostPlaces.here)
        for each in HostPlaces.here {
            XCTAssertEqual(GuestWork.inGuest(each.host), each.place == .guest, "\(each.host)")
        }
        let own = try XCTUnwrap(HostPlaces.here.first { $0.place == .machine })
        let listed = try await ToolingService().listDestinations(of: own.host)
        XCTAssertEqual(listed.destinations.map(\.kind), [.machine])
    }

    /// A debugger follows a page in Chromium's browsers alone.
    func testADebuggerFollowsChromiumsBrowsers() {
        for id in ["com.google.Chrome", "org.chromium.Chromium", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser",
                   "google-chrome.desktop", "microsoft-edge.desktop"] {
            XCTAssertTrue(Browsers.chromium(id), id)
        }
        for id in ["com.apple.Safari", "org.mozilla.firefox", "firefox.desktop", "org.gnome.Epiphany.desktop"] {
            XCTAssertFalse(Browsers.chromium(id), id)
        }
    }
}
