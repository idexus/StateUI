// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One member of a contract - a property, an event or an act - as a list of
/// members holds it.
public protocol ContractMember: Sendable {
    /// The member's name: what crosses the boundary.
    var name: String { get }
}
