// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Properties a view takes together, listed once for every host that takes
/// them - what every element showing words takes, say. Made of properties
/// alone, so no event or act stands in one; joined with `+`.
///
///     static let look = PropertyList(FontElementContract.fontSize, TextColorElementContract.textColor)
///     registration.applies(TextualElementContract.text, look) { view, values in … }
@_spi(Host) public struct PropertyList: AppliedProperties, Sendable {
    /// The properties, in their order.
    let properties: [any RegisteredProperty]

    /// The properties given, in their order.
    ///
    /// - Parameter properties: each written with its contract.
    public init<each Owner: Contract, each Value: HostRepresentable>(
        _ properties: repeat ElementProperty<each Owner, each Value>
    ) {
        var listed: [any RegisteredProperty] = []
        for property in repeat each properties {
            listed.append(property)
        }
        self.properties = listed
    }

    private init(listing properties: [any RegisteredProperty]) {
        self.properties = properties
    }

    /// The list itself.
    public var applied: PropertyList { self }

    /// The properties of both, the left's first.
    public static func + (left: PropertyList, right: PropertyList) -> PropertyList {
        PropertyList(listing: left.properties + right.properties)
    }
}
