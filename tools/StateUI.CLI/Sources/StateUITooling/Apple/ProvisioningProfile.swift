// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A provisioning profile of this Mac: the team, the application identifiers and the devices it lets an application
/// run on, until when, signed by which certificates, and the entitlements it grants.
/// Design: docs/design/tooling/apple-bundles.md#signing-for-a-device
public struct ProvisioningProfile: Equatable, Sendable {
    /// The profile's file.
    public var file: URL
    /// The team's identifier: `A59FM7PQ5K`.
    public var team: String
    /// The application identifier it grants, maybe ending in `*`: `A59FM7PQ5K.*`.
    public var applicationIdentifier: String
    public var expiration: Date
    /// Whether a debugger may attach: a development profile's `get-task-allow`.
    public var debuggable: Bool
    /// The UDIDs of the devices it lets an application run on.
    public var devices: [String]
    /// Whether it lets an application run on every device.
    public var everyDevice: Bool
    /// Its certificates' SHA-1 digests in upper-case hex, as `security find-identity` names an identity.
    public var certificates: [String]
    /// The entitlements it grants, as a property list.
    public var entitlements: Data

    /// The profile `file`, as its fields say.
    public init(
        file: URL, team: String, applicationIdentifier: String, expiration: Date, debuggable: Bool, devices: [String],
        everyDevice: Bool, certificates: [String], entitlements: Data
    ) {
        self.file = file
        self.team = team
        self.applicationIdentifier = applicationIdentifier
        self.expiration = expiration
        self.debuggable = debuggable
        self.devices = devices
        self.everyDevice = everyDevice
        self.certificates = certificates
        self.entitlements = entitlements
    }

    /// Whether it grants `identifier` of its team: exactly, or by a wildcard.
    public func grants(_ identifier: String) -> Bool {
        let full = "\(team).\(identifier)"
        return applicationIdentifier == full
            || applicationIdentifier.hasSuffix("*") && full.hasPrefix(applicationIdentifier.dropLast())
    }

    /// Its entitlements for `identifier`: its own, the application identifier the team's and `identifier`.
    public func entitlements(for identifier: String) throws -> Data {
        let read = try PropertyListSerialization.propertyList(from: entitlements, format: nil)
        guard var granted = read as? [String: Any] else { throw CocoaError(.propertyListReadCorrupt) }
        granted["application-identifier"] = "\(team).\(identifier)"
        return try PropertyListSerialization.data(fromPropertyList: granted, format: .xml, options: 0)
    }

    /// The profile and identity that sign `identifier` to run on device `udid` at `now`: of the development profiles
    /// still valid, provisioning it and granting `identifier`, signed by a certificate among `identities` - the one
    /// granting it exactly before a wildcard, then the latest to expire - or `nil` where none does.
    public static func choose(
        _ profiles: [ProvisioningProfile], identities: Set<String>, identifier: String, device udid: String, now: Date
    ) -> (profile: ProvisioningProfile, identity: String)? {
        let usable = profiles.compactMap { profile -> (ProvisioningProfile, String)? in
            guard profile.debuggable, profile.expiration > now, profile.grants(identifier),
                  profile.everyDevice || profile.devices.contains(udid),
                  let identity = profile.certificates.first(where: identities.contains)
            else { return nil }
            return (profile, identity)
        }
        let exact = { (profile: ProvisioningProfile) in profile.applicationIdentifier.hasSuffix("*") ? 0 : 1 }
        return usable.max { a, b in (exact(a.0), a.0.expiration) < (exact(b.0), b.0.expiration) }
    }
}
