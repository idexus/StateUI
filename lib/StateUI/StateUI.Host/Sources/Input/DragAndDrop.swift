// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a view offers and takes of a drag: the words a drag of it carries, whether it takes words dropped on it, and
/// the kinds of file it takes dropped from the system - the same on every host.
/// Design: docs/design/host/runtime.md#a-drag-between-views
@_spi(Host) public struct DragAndDrop: Equatable, Sendable {
    /// The words a drag of the view carries; nil where it cannot be dragged.
    public let words: String?

    /// Whether the view takes words dropped on it.
    public let takesWords: Bool

    /// The kinds of file the view takes dropped from the system - any file where none is listed; nil where it takes
    /// no files.
    public let fileTypes: [FileType]?

    /// A view whose drag carries `words`, nil for none, which takes words where `takesWords` and files of
    /// `fileTypes` where they are given.
    public init(words: String?, takesWords: Bool, fileTypes: [FileType]? = nil) {
        self.words = words
        self.takesWords = takesWords
        self.fileTypes = fileTypes
    }

    /// Neither dragged nor taking drops.
    public static let none = DragAndDrop(words: nil, takesWords: false)

    /// Whether the view takes files dropped on it.
    public var takesFiles: Bool { fileTypes != nil }

    /// Of `files` dropped on the view, those of the kinds it takes, in order: a file of a kind by its name's
    /// extension, any file where it lists no kind.
    /// Design: docs/design/host/runtime.md#files-dropped-on-a-view
    public func taken(_ files: [ChosenFile]) -> [ChosenFile] {
        guard let fileTypes else { return [] }
        guard !fileTypes.isEmpty else { return files }
        let extensions = Set(fileTypes.flatMap(\.extensions))
        return files.filter { file in
            guard let dot = file.name.lastIndex(of: ".") else { return false }
            return extensions.contains(String(file.name[file.name.index(after: dot)...]).lowercased())
        }
    }
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
    /// What the element's view offers and takes of a drag, as its properties say.
    public var dragAndDrop: DragAndDrop {
        DragAndDrop(
            words: value(.canDrag)?.bool == true ? value(.dragText)?.string ?? "" : nil,
            takesWords: value(.allowsDrop)?.bool == true,
            fileTypes: value(.droppedFileTypes).flatMap([FileType].init(propValue:)))
    }

    /// Every element in this subtree whose view takes words or files dropped on it, in the tree's order: what a toolkit asks for under a
    /// drag where a window, not each view, takes it.
    public var takingDrops: [MountedElement] {
        let taking = dragAndDrop.takesWords || dragAndDrop.takesFiles
        return (taking ? [self] : []) + children.flatMap(\.takingDrops)
    }
}
