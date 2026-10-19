// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a host realizes: the elements it makes a view for, and the members it
/// realizes on each.
@_spi(Host) public struct HostRealization: Equatable, Sendable {
    /// The elements, by node type.
    public var elements: Set<NodeType>

    /// The members, each on its element.
    public var members: Set<HostRealizedMember>

    /// A realization - nothing, unless said.
    ///
    /// - Parameters:
    ///   - elements: the elements, by node type.
    ///   - members: the members, each on its element.
    public init(elements: Set<NodeType> = [], members: Set<HostRealizedMember> = []) {
        self.elements = elements
        self.members = members
    }
}

/// One member a host realizes on one element: the element, the contract
/// declaring the member - the element's own or a tier it wears - and the
/// member, each by its key.
@_spi(Host) public struct HostRealizedMember: Hashable, Sendable {
    /// The element realizing it.
    public let element: NodeType

    /// The contract declaring it.
    public let owner: KeyName

    /// The member itself.
    public let member: KeyName

    /// One member on one element, each named.
    ///
    /// - Parameters:
    ///   - element: the element realizing it.
    ///   - owner: the contract declaring it.
    ///   - member: its own name.
    public init(element: String, owner: String, member: String) {
        self.element = NodeType(element)
        self.owner = KeyName(owner)
        self.member = KeyName(member)
    }
}
