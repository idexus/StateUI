// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a window element asks its host to show, as it changes, the same on every host: the arrangement of pages
/// among its children, what it lays over them, and that it was made - said once.
/// Design: docs/design/host/tree.md#a-window-shown
@_spi(Host) @MainActor public final class WindowPresentation {
    /// What changed of a window since it was last shown.
    public struct Changes {
        /// The arrangement shown before, and the one shown now; nil where it is the same.
        public var arrangement: (previous: MountedElement?, shown: MountedElement?)?

        /// What the window lays over its pages now, where that changed: the element, or nil for nothing.
        public var overlay: MountedElement??

        /// The window's handler of being made, where it is to be told now.
        public var created: Int32?
    }

    /// The arrangement of pages shown.
    public private(set) var arrangement: MountedElement?

    /// What is laid over the pages.
    public private(set) var overlay: MountedElement?
    private weak var created: MountedElement?

    /// Nothing shown yet.
    public init() {}

    /// What `window` asks to show that changed since it was last shown.
    public func show(_ window: MountedElement) -> Changes {
        var changes = Changes()
        let arrangement = window.children.first { NodeType.pageTypes.contains($0.type) }
        if arrangement !== self.arrangement {
            changes.arrangement = (self.arrangement, arrangement)
            self.arrangement = arrangement
        }
        let overlay = window.children.first { $0.type == .overlay }
        if overlay !== self.overlay {
            changes.overlay = .some(overlay)
            self.overlay = overlay
        }
        if window !== created {
            created = window
            changes.created = window.handler(.created)
        }
        return changes
    }
}
