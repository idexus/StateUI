// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class AppleDestinationsTests: XCTestCase {
    private func device(
        _ id: String, _ name: String, reality: String = "physical", platform: String = "iOS", version: String = "27.0",
        pairing: String = "paired", transport: String = "wired"
    ) -> String {
        """
        {"identifier": "\(id)", "hardwareProperties": {"reality": "\(reality)", "platform": "\(platform)", "udid": "U-\(id)"},
         "deviceProperties": {"name": "\(name)", "osVersionNumber": "\(version)"},
         "connectionProperties": {"pairingState": "\(pairing)", "transportType": "\(transport)"}}
        """
    }

    private let simctl = Data("""
        {"devices": {
          "com.apple.CoreSimulator.SimRuntime.iOS-26-4": [{"udid": "OLD-PHONE", "name": "iPhone 17 Pro", "state": "Shutdown"}],
          "com.apple.CoreSimulator.SimRuntime.iOS-26-2": [{"udid": "TOO-OLD", "name": "iPhone 17 Pro", "state": "Booted"}],
          "com.apple.CoreSimulator.SimRuntime.watchOS-27-0": [{"udid": "WATCH", "name": "Apple Watch", "state": "Booted"}],
          "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
            {"udid": "PAD", "name": "iPad Air 13-inch (M4)", "state": "Shutdown"},
            {"udid": "PHONE", "name": "iPhone 18 Pro", "state": "Shutdown"},
            {"udid": "NEW-PRO", "name": "iPhone 17 Pro", "state": "Shutdown"}
          ]
        }}
        """.utf8)

    /// The devices kept are the real iPhones and iPads paired with this Mac, of Apple's floor or newer - a watch, a
    /// simulator devicectl lists, an unpaired device and an older system are not - each with how it is reached.
    func testTheDevicesKeptArePairedIPhonesAndIPadsOfTheFloor() {
        let json = Data("""
            {"result": {"devices": [
              \(device("PHONE", "Phone", version: "26.6.2")),
              \(device("WATCH", "Watch", platform: "watchOS")),
              \(device("SIM", "Simulator", reality: "simulated", transport: "sameMachine")),
              \(device("LONELY", "Unpaired", pairing: "unpaired")),
              \(device("OLD", "Old", version: "26.3")),
              \(device("PAD", "Pad", transport: "localNetwork"))
            ]}}
            """.utf8)
        XCTAssertEqual(AppleDestinations.devices(fromDevicectl: json), [
            Destination(id: "PHONE", udid: "U-PHONE", name: "Phone", kind: .device, version: "26.6.2", connection: "USB"),
            Destination(id: "PAD", udid: "U-PAD", name: "Pad", kind: .device, version: "27.0", connection: "Wi-Fi"),
        ])
        XCTAssertEqual(AppleDestinations.devices(fromDevicectl: Data("not json".utf8)), [])
    }

    /// The simulators are the iOS runtimes' of the floor or newer, the newest runtime first, each in the order listed.
    func testTheSimulatorsAreTheNewestRuntimesFirst() {
        XCTAssertEqual(AppleDestinations.simulators(fromSimctl: simctl).map(\.id), ["PAD", "PHONE", "NEW-PRO", "OLD-PHONE"])
        XCTAssertEqual(AppleDestinations.simulators(fromSimctl: simctl).first?.version, "27.0")
    }

    /// A named destination is a device first, then a simulator of the newest runtime having it; none named, the booted
    /// simulator, else an iPhone; a name nothing has is refused.
    func testTheDestinationChosenIsTheOneNamedElseTheBootedSimulator() throws {
        let simulators = AppleDestinations.simulators(fromSimctl: simctl)
        let phone = Destination(id: "DEVICE", udid: "U-DEVICE", name: "iPhone 17 Pro", kind: .device, version: "27.0")
        XCTAssertEqual(try AppleDestinations.choose("iPhone 17 Pro", from: simulators).id, "NEW-PRO")
        XCTAssertEqual(try AppleDestinations.choose("iPhone 17 Pro", from: [phone] + simulators).id, "DEVICE")
        XCTAssertEqual(try AppleDestinations.choose("U-DEVICE", from: [phone] + simulators).id, "DEVICE")
        XCTAssertEqual(try AppleDestinations.choose("OLD-PHONE", from: simulators).id, "OLD-PHONE")
        XCTAssertEqual(try AppleDestinations.choose(nil, from: simulators).id, "PHONE")
        var booted = simulators
        booted[0].booted = true
        XCTAssertEqual(try AppleDestinations.choose(nil, from: booted).id, "PAD")
        XCTAssertThrowsError(try AppleDestinations.choose("Nothing", from: simulators)) { error in
            XCTAssertEqual((error as? ToolingError)?.code, .invalidConfiguration)
        }
        XCTAssertThrowsError(try AppleDestinations.choose(nil, from: [phone]))
    }
}
