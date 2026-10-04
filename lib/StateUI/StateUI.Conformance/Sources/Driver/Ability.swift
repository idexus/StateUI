// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// An ability as a driver names it, taken apart: "tap on Text" is the act "tap" done on a Text; a read or a fact -
/// "read isOn of Switch" - has no element "on" it.
@_spi(Host) public struct Ability: Equatable, Sendable {
    /// The act, or the whole of a read.
    public let act: String

    /// The type of the element the act is done on; empty for a read.
    public let element: String

    /// `ability` taken apart.
    public init(_ ability: String) {
        var index = ability.startIndex
        while index < ability.endIndex {
            if ability[index...].hasPrefix(" on ") {
                act = String(ability[..<index])
                element = String(ability[ability.index(index, offsetBy: 4)...])
                return
            }
            index = ability.index(after: index)
        }
        act = ability
        element = ""
    }

    /// Whether it reads one of a view's transform's members: its translation, rotation, scale or pivot.
    public var readsATransform: Bool {
        Self.transforms.contains { act.hasPrefix("read \($0) of ") }
    }

    private static let transforms = [
        VisualElementContract.translationX, VisualElementContract.translationY, VisualElementContract.rotation,
        VisualElementContract.rotationX, VisualElementContract.rotationY, VisualElementContract.scale,
        VisualElementContract.scaleX, VisualElementContract.scaleY, VisualElementContract.pivotX,
        VisualElementContract.pivotY,
    ].map(\.name)
}
