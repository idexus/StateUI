// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

/// An element whose view stands in no window yet - a cell made but not shown: no place to read now, though one comes.
@_spi(Host) public struct NotPlaced: Error, CustomStringConvertible {
    /// The element's node type, as a failure names it.
    public let type: String

    /// `element`, whose view stands in no window yet.
    @MainActor public init(_ element: MountedElement) {
        type = element.type.name
    }

    public var description: String { "\(type) stands in no window yet" }
}
