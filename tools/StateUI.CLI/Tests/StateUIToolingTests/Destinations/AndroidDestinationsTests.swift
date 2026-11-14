// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class AndroidDestinationsTests: XCTestCase {
    /// The devices kept are those `adb devices -l` says ready - each with its serial, model and whether it is on USB;
    /// one offline or unauthorized is not.
    func testTheDevicesKeptAreTheReadyOnes() {
        let text = """
            List of devices attached
            190a991d               device usb:32-1.3 product:CPH2363EEA model:CPH2363 device:OP533FL1 transport_id:29
            emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:27
            R5CT1                  unauthorized usb:1-1 transport_id:3
            192.168.1.20:5555      offline

            """
        let attached = AndroidDestinations.attached(fromADB: text)
        XCTAssertEqual(attached.map(\.serial), ["190a991d", "emulator-5554"])
        XCTAssertEqual(attached.map(\.model), ["CPH2363", "sdk_gphone64_arm64"])
        XCTAssertEqual(attached.map(\.usb), [true, false])
        XCTAssertTrue(AndroidDestinations.attached(fromADB: "List of devices attached\n").isEmpty)
    }

    /// An ABI is an architecture by StateUI's names, and back.
    func testAnABIIsAnArchitecture() {
        XCTAssertEqual(AndroidDestinations.architecture(ofABI: "arm64-v8a"), .arm64)
        XCTAssertEqual(AndroidDestinations.architecture(ofABI: "x86_64"), .x86_64)
        XCTAssertNil(AndroidDestinations.architecture(ofABI: "mips"))
        for architecture in [Architecture.arm64, .x86_64, .armv7, .x86] {
            XCTAssertEqual(AndroidDestinations.abi(of: architecture).flatMap(AndroidDestinations.architecture(ofABI:)), architecture)
        }
    }

    /// The destination meant is the one named - a running one before a virtual device of the same name - else the
    /// one `ANDROID_SERIAL` names, else the only one running; none running, or several, is refused.
    func testTheDestinationMeantIsNamedElseTheOnlyOneRunning() throws {
        let phone = Destination(id: "190a991d", udid: "190a991d", name: "CPH2363", kind: .device, version: "13", connection: "USB", architecture: .arm64)
        let running = Destination(id: "emulator-5554", udid: "emulator-5554", name: "Pixel_3a", kind: .emulator, version: "14", booted: true, architecture: .arm64)
        let idle = Destination(id: "Pixel_3a", udid: "Pixel_3a", name: "Pixel_3a", kind: .emulator, version: "")
        let other = Destination(id: "Pixel_5", udid: "Pixel_5", name: "Pixel_5", kind: .emulator, version: "")

        XCTAssertEqual(try AndroidDestinations.choose("Pixel_3a", from: [running, idle]).id, "emulator-5554")
        XCTAssertEqual(try AndroidDestinations.choose("Pixel_5", from: [running, other]).id, "Pixel_5")
        XCTAssertEqual(try AndroidDestinations.choose("CPH2363", from: [phone, running]).id, "190a991d")
        XCTAssertEqual(try AndroidDestinations.choose(nil, from: [phone, running], environment: ["ANDROID_SERIAL": "emulator-5554"]).id, "emulator-5554")
        XCTAssertEqual(try AndroidDestinations.choose(nil, from: [running, other]).id, "emulator-5554")
        for (wanted, listed) in [("Nothing", [running]), (nil, [phone, running]), (nil, [other])] as [(String?, [Destination])] {
            XCTAssertThrowsError(try AndroidDestinations.choose(wanted, from: listed)) { error in
                XCTAssertEqual((error as? ToolingError)?.code, .invalidConfiguration)
            }
        }
    }
}
