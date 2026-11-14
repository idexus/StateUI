// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import XCTest

final class ProvisioningProfileTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func profile(
        _ name: String, identifier: String = "TEAM.*", days: Double = 30, debuggable: Bool = true,
        devices: [String] = ["PAD"], every: Bool = false, certificates: [String] = ["CERT"]
    ) -> ProvisioningProfile {
        let granted: [String: Any] = ["application-identifier": identifier, "get-task-allow": debuggable, "keychain-access-groups": ["TEAM.*"]]
        return ProvisioningProfile(
            file: URL(fileURLWithPath: "/\(name).mobileprovision"), team: "TEAM", applicationIdentifier: identifier,
            expiration: now.addingTimeInterval(days * 86_400), debuggable: debuggable, devices: devices, everyDevice: every,
            certificates: certificates,
            entitlements: try! PropertyListSerialization.data(fromPropertyList: granted, format: .xml, options: 0))
    }

    /// The profile chosen is a development one, still valid, provisioning the device, granting the identifier and
    /// signed by a certificate the keychain holds - the exact identifier before a wildcard, then the latest to expire.
    func testTheProfileChosenLetsTheBundleRunOnTheDevice() {
        let choose = { (profiles: [ProvisioningProfile]) in
            ProvisioningProfile.choose(profiles, identities: ["CERT"], identifier: "com.stateui.notes", device: "PAD", now: self.now)?
                .profile.file.lastPathComponent
        }
        XCTAssertEqual(choose([profile("wild"), profile("exact", identifier: "TEAM.com.stateui.notes")]), "exact.mobileprovision")
        XCTAssertEqual(choose([profile("soon", days: 1), profile("later", days: 300)]), "later.mobileprovision")
        XCTAssertEqual(choose([profile("all", devices: [], every: true)]), "all.mobileprovision")
        XCTAssertEqual(choose([profile("prefix", identifier: "TEAM.com.stateui.*")]), "prefix.mobileprovision")
        for refused in [
            profile("expired", days: -1), profile("release", debuggable: false), profile("other", devices: ["PHONE"]),
            profile("unsigned", certificates: ["ELSE"]), profile("another", identifier: "TEAM.com.example.*"),
        ] {
            XCTAssertNil(choose([refused]), refused.file.lastPathComponent)
        }
        XCTAssertEqual(
            ProvisioningProfile.choose([profile("wild")], identities: ["CERT"], identifier: "x", device: "PAD", now: now)?.identity,
            "CERT")
    }

    /// The entitlements signed are the profile's, the application identifier the team's and the bundle's.
    func testTheEntitlementsNameTheBundlesIdentifier() throws {
        let data = try profile("wild").entitlements(for: "com.stateui.notes")
        let signed = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(signed["application-identifier"] as? String, "TEAM.com.stateui.notes")
        XCTAssertEqual(signed["get-task-allow"] as? Bool, true)
        XCTAssertEqual(signed["keychain-access-groups"] as? [String], ["TEAM.*"])
    }

    #if os(macOS)
    /// A decoded profile gives its team, identifier, devices, expiration and its certificates' SHA-1 digests.
    func testADecodedProfileIsRead() throws {
        let certificate = Data("certificate".utf8)
        let decoded: [String: Any] = [
            "TeamIdentifier": ["TEAM"], "ExpirationDate": now, "ProvisionedDevices": ["PAD"],
            "DeveloperCertificates": [certificate],
            "Entitlements": ["application-identifier": "TEAM.*", "get-task-allow": true],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: decoded, format: .xml, options: 0)
        let read = try XCTUnwrap(DevelopmentSigning.profile(decoded: data, file: URL(fileURLWithPath: "/p.mobileprovision")))
        XCTAssertEqual(read.team, "TEAM")
        XCTAssertEqual(read.applicationIdentifier, "TEAM.*")
        XCTAssertEqual(read.devices, ["PAD"])
        XCTAssertTrue(read.debuggable)
        XCTAssertEqual(read.certificates, ["735AD571C189D7BA84464BF4A9F1D2280175B128"])
        XCTAssertNil(DevelopmentSigning.profile(decoded: Data("no".utf8), file: URL(fileURLWithPath: "/p")))
    }
    #endif
}
