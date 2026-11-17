// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ParallelsGuestsTests: XCTestCase {
    /// What `prlctl list --all --info --json` says of a Linux guest sharing named folders and a Windows guest sharing
    /// every disk, as Parallels Desktop 27 writes it, with what the tool does not read cut away.
    private let listed = #"""
        [{"ID": "71a243c0-79db-4b67-a771-61a9bb2fe6a0", "Name": "Ubuntu 26", "State": "running", "OS": "ubuntu",
          "Host Shared Folders": {"enabled": true,
            "stateui": {"enabled": true, "path": "/Users/me/Projects/StateUI", "mode": "rw"},
            "old": {"enabled": false, "path": "/Users/me/old", "mode": "rw"}},
          "Host defined sharing": "Unknown", "GuestTools": {"state": "installed", "version": "27.0.1-58670"},
          "Hardware": {"cpu": {"cpus": 2, "type": "arm"}}},
         {"ID": "0758bcb2-db54-42e8-a620-fa15105f9c40", "Name": "Windows 11", "State": "suspended", "OS": "win-11",
          "Host Shared Folders": {"enabled": true, "nuget": {"enabled": false, "path": "~/Projects/nuget", "mode": "rw"}},
          "Host defined sharing": "All host disks", "GuestTools": {"state": "installed"},
          "Hardware": {"cpu": {"cpus": 4, "type": "arm"}}},
         {"ID": "a1", "Name": "macOS", "State": "stopped", "OS": "macosx", "Hardware": {"cpu": {"type": "arm"}}}]
        """#

    /// Each guest is read with its system, state, architecture, the folders it shares - enabled ones alone - and
    /// whether it shares every disk; a guest of another system serves no host.
    func testAGuestIsReadWithItsSystemAndWhatItShares() {
        let guests = ParallelsGuests.guests(fromJSON: Data(listed.utf8))
        XCTAssertEqual(guests.map(\.name), ["Ubuntu 26", "Windows 11", "macOS"])
        XCTAssertEqual(guests.map(\.system), [.linux, .windows, .other])
        XCTAssertEqual(guests[0].shares, ["stateui": "/Users/me/Projects/StateUI"])
        XCTAssertEqual(guests[0].sharesAllDisks, false)
        XCTAssertEqual(guests[1].shares, [:])
        XCTAssertEqual(guests[1].sharesAllDisks, true)
        XCTAssertEqual(guests.map(\.state), ["running", "suspended", "stopped"])
        XCTAssertEqual(guests[0].architecture, .arm64)
        XCTAssertEqual(guests.map(\.hasTools), [true, true, false])
        XCTAssertEqual(ParallelsGuests.guests(fromJSON: Data("not a list".utf8)), [])
    }

    /// A GTK head is built in a Linux guest, a WinUI head in a Windows one; a guest is a destination by its name,
    /// its state said where a device says how it is reached.
    func testAGuestIsADestinationOfItsSystemsHost() {
        XCTAssertEqual(ParallelsGuests.system(for: .gtk), .linux)
        XCTAssertEqual(ParallelsGuests.system(for: .winui), .windows)
        XCTAssertNil(ParallelsGuests.system(for: .appkit))
        let guest = ParallelsGuests.guests(fromJSON: Data(listed.utf8))[1]
        XCTAssertEqual(
            ParallelsGuests.destination(of: guest),
            Destination(
                id: "Windows 11", udid: "0758bcb2-db54-42e8-a620-fa15105f9c40", name: "Windows 11", kind: .guest,
                version: "win-11", booted: false, connection: "suspended", architecture: .arm64))
    }
}
