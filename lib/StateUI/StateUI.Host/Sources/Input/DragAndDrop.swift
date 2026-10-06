// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a view offers and takes of a drag between views: the words a drag of it carries, and whether it takes what
/// is dropped on it - the same on every host.
/// Design: docs/design/host/runtime.md#a-drag-between-views
@_spi(Host) public struct DragAndDrop: Equatable, Sendable {
    /// The words a drag of the view carries; nil where it cannot be dragged.
    public let words: String?

    /// Whether the view takes what is dropped on it.
    public let takesDrops: Bool

    /// A view whose drag carries `words`, nil for none, and which takes drops where `takesDrops`.
    public init(words: String?, takesDrops: Bool) {
        self.words = words
        self.takesDrops = takesDrops
    }

    /// Neither dragged nor taking drops.
    public static let none = DragAndDrop(words: nil, takesDrops: false)
}

/// A view that takes drops, as the contract tells what a drag does over it whatever its toolkit repeats or leaves
/// out: over once as a drag comes, however often the toolkit says it is still there; left as it goes without being
/// let go - never after a drop; dropped as it is let go there.
/// Design: docs/design/host/runtime.md#a-drag-between-views
@_spi(Host) public struct DropTarget: Sendable {
    private var isOver = false

    /// No drag over the view.
    public init() {}

    /// A drag is over the view: whether the view hears it - only as it comes.
    public mutating func over() -> Bool {
        defer { isOver = true }
        return !isOver
    }

    /// The drag went away without being let go: whether the view hears it - only once it heard it come.
    public mutating func left() -> Bool {
        defer { isOver = false }
        return isOver
    }

    /// The drag was let go over the view: it is over it no more, and no leaving follows.
    public mutating func dropped() {
        isOver = false
    }
}

extension MountedElement {
    /// What the element's view offers and takes of a drag between views, as its properties say.
    public var dragAndDrop: DragAndDrop {
        DragAndDrop(
            words: value(.canDrag)?.bool == true ? value(.dragText)?.string ?? "" : nil,
            takesDrops: value(.allowsDrop)?.bool == true)
    }
}
