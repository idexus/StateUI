// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a host realizes: the elements it makes a view for, and the members it
/// realizes on each.
@_spi(Host) public struct HostRealization: Equatable, Sendable {
    /// The elements, by node type name.
    public var elements: Set<String>

    /// The members, each on its element.
    public var members: Set<HostRealizedMember>

    /// A realization - nothing, unless said.
    ///
    /// - Parameters:
    ///   - elements: the elements, by node type name.
    ///   - members: the members, each on its element.
    public init(elements: Set<String> = [], members: Set<HostRealizedMember> = []) {
        self.elements = elements
        self.members = members
    }
}

/// One member a host realizes on one element: the element's name, the name of
/// the contract declaring the member - the element's own or a tier it wears -
/// and the member's own name.
@_spi(Host) public struct HostRealizedMember: Hashable, Sendable {
    /// The element realizing it.
    public let element: String

    /// The contract declaring it.
    public let owner: String

    /// Its own name.
    public let member: String

    /// One member on one element.
    ///
    /// - Parameters:
    ///   - element: the element realizing it.
    ///   - owner: the contract declaring it.
    ///   - member: its own name.
    public init(element: String, owner: String, member: String) {
        self.element = element
        self.owner = owner
        self.member = member
    }
}
