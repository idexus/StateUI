// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the machine has of one component it needs: found, too old, or missing, and how to get it.
public struct ToolFinding: Codable, Equatable, Sendable {
    /// The component, with the least of it that serves: `Swift 6.4 or newer`.
    public var component: String
    /// Who needs it, in words: `every host`, `GTK`, `Debug`.
    public var neededBy: String
    /// The hosts that cannot be built without it; none for what only serves a part of the work.
    public var hosts: [HostFamily]
    /// What was found: its version, where it stands.
    public var found: String?
    /// A version found that does not serve, older than the least the component names.
    public var tooOld: String?
    /// How to get it, where it is not found.
    public var advice: String

    /// A finding of `component`.
    public init(
        component: String, neededBy: String, hosts: [HostFamily], found: String?, tooOld: String?, advice: String
    ) {
        self.component = component
        self.neededBy = neededBy
        self.hosts = hosts
        self.found = found
        self.tooOld = tooOld
        self.advice = advice
    }
}
