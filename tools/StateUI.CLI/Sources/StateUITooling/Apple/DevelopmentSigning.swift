// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import CryptoKit
import Foundation
import StateUIToolingProtocol

/// What signs a bundle to run on a device: a development profile of this Mac's and the keychain's identity it names.
/// Design: docs/design/tooling/apple-bundles.md#signing-for-a-device
public struct DevelopmentSigning: Sendable {
    public var profile: ProvisioningProfile
    /// The identity's SHA-1, as `codesign --sign` takes it.
    public var identity: String

    /// The signing of `identifier` for device `udid`, chosen among this Mac's profiles and the keychain's identities.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` where no profile lets it run there.
    public static func find(identifier: String, device udid: String) async throws -> DevelopmentSigning {
        let listed = await ToolOutput.standardOutput(.name("security"), ["find-identity", "-v", "-p", "codesigning"]) ?? ""
        let identities = Set(listed.matches(of: /\b[0-9A-F]{40}\b/).map { String($0.output) })
        guard let (profile, identity) = ProvisioningProfile.choose(
            await installed(), identities: identities, identifier: identifier, device: udid, now: Date())
        else {
            throw ToolingError(.invalidConfiguration, "No development profile of this Mac lets \(identifier) run on \(udid):"
                + " run any application on the device from Xcode once, with a certificate in this keychain, and Xcode makes one.")
        }
        return DevelopmentSigning(profile: profile, identity: identity)
    }

    /// The profiles in the folders Xcode keeps them in, each decoded by `security cms`.
    static func installed() async -> [ProvisioningProfile] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folders = ["Library/Developer/Xcode/UserData/Provisioning Profiles", "Library/MobileDevice/Provisioning Profiles"]
        var profiles: [ProvisioningProfile] = []
        for folder in folders.map(home.appendingPathComponent) {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            for name in names.sorted() where name.hasSuffix(".mobileprovision") {
                let file = folder.appendingPathComponent(name)
                guard let decoded = await ToolOutput.standardOutput(.name("security"), ["cms", "-D", "-i", file.path]),
                      let profile = profile(decoded: Data(decoded.utf8), file: file)
                else { continue }
                profiles.append(profile)
            }
        }
        return profiles
    }

    /// The profile `file` whose decoded property list is `decoded`, or `nil` where it is none.
    public static func profile(decoded: Data, file: URL) -> ProvisioningProfile? {
        guard let read = try? PropertyListSerialization.propertyList(from: decoded, format: nil) as? [String: Any],
              let granted = read["Entitlements"] as? [String: Any],
              let team = (read["TeamIdentifier"] as? [String])?.first,
              let expiration = read["ExpirationDate"] as? Date,
              let entitlements = try? PropertyListSerialization.data(fromPropertyList: granted, format: .xml, options: 0)
        else { return nil }
        let certificates = (read["DeveloperCertificates"] as? [Data] ?? []).map { certificate in
            Insecure.SHA1.hash(data: certificate).map { String(format: "%02X", $0) }.joined()
        }
        return ProvisioningProfile(
            file: file, team: team, applicationIdentifier: granted["application-identifier"] as? String ?? "",
            expiration: expiration, debuggable: granted["get-task-allow"] as? Bool ?? false,
            devices: read["ProvisionedDevices"] as? [String] ?? [], everyDevice: read["ProvisionsAllDevices"] as? Bool ?? false,
            certificates: certificates, entitlements: entitlements)
    }
}
#endif
