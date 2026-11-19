// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which suites of a checkout a plan runs: `portable`, the owner packages every machine runs; `native`, the machine's
/// own host suites.
public enum PlanKind: String, Codable, Sendable, CaseIterable {
    case portable, native
}

/// A plan of a checkout's suites run in order - `repository/plan`'s parameters.
public struct PlanRequest: Codable, Equatable, Sendable {
    public var kind: PlanKind
    /// One suite of the plan alone, by its id.
    public var only: String?
    /// The native plan's UIKit simulator or Android device, or the machine the plan runs on - a guest, a machine
    /// paired - by name or id.
    public var device: String?
    /// A folder of the checkout whose plan runs; the connection's workspace where none is named.
    public var folderUri: String?

    /// The `kind` plan - its suite `only` where named - on `device`, of the checkout holding `folderUri`.
    public init(kind: PlanKind, only: String? = nil, device: String? = nil, folderUri: String? = nil) {
        self.kind = kind
        self.only = only
        self.device = device
        self.folderUri = folderUri
    }
}
