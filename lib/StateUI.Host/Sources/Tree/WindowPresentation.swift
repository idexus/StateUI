// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a window element asks its host to show, as it changes, the same on every host: the arrangement of pages
/// among its children, its sheets, what it lays over them, its frame, its bounds, its traits, the window it belongs
/// to and whether its scene hides it - each said where it changed - while the page the user sees hears it is shown,
/// and the window that it was made.
/// Design: docs/design/host/tree.md#a-window-shown
@_spi(Host) @MainActor public final class WindowPresentation {
    /// What changed of a window since it was last shown.
    public struct Changes {
        /// The arrangement shown before, and the one shown now; nil where it is the same.
        public var arrangement: (previous: MountedElement?, shown: MountedElement?)?

        /// The pages its modal stack presents as sheets, the last on top, where they changed.
        public var sheets: [MountedElement]?

        /// What the window lays over its pages now, where that changed: the element, or nil for nothing.
        public var overlay: MountedElement??

        /// The place and size the tree changed, each alone; nil where it changed none.
        public var frame: WindowFrame?

        /// The least and greatest size, where they changed - the first time whatever they are.
        public var bounds: WindowBounds?

        /// What the window is - its buttons, its backdrop, whether it floats - where that changed, the first time
        /// whatever it is.
        public var traits: WindowTraits?

        /// Whether its scene hides it, where that changed - the first time whatever it is.
        public var hidden: Bool?

        /// The window it belongs to, where that changed - the first time whatever it is: its scene's main window for
        /// a window of a kind of its own, nil for a main one.
        public var owner: MountedElement??
    }

    /// The arrangement of pages shown.
    public private(set) var arrangement: MountedElement?

    /// The pages shown as sheets over it, the last on top.
    public private(set) var sheets: [MountedElement] = []

    /// What is laid over the pages.
    public private(set) var overlay: MountedElement?
    private weak var created: MountedElement?
    private var requested = WindowFrame()
    private var bounds: WindowBounds?
    private var traits: WindowTraits?
    private var hidden: Bool?
    private weak var owner: MountedElement?
    private var ownerSaid = false

    /// Nothing shown yet.
    public init() {}

    /// What `window` asks to show that changed since it was last shown, standing in `lifecycle`. The page the user
    /// sees - the top sheet, else the arrangement - hears it is shown, the one before it that it is not, and then a
    /// window new here hears it was made: all in their turn, told before the host shows the window, and so before it
    /// comes to the front.
    public func show(_ window: MountedElement, in lifecycle: ApplicationLifecycle) -> Changes {
        var changes = Changes()
        let previousVisible = sheets.last ?? arrangement
        let hadSheets = !sheets.isEmpty

        let arrangement = window.children.first { NodeType.pageTypes.contains($0.type) }
        if arrangement !== self.arrangement {
            changes.arrangement = (self.arrangement, arrangement)
            self.arrangement = arrangement
        }
        let sheets = window.children.first { $0.type == .modalStack }?.children
            .filter { NodeType.pageTypes.contains($0.type) } ?? []
        if !sheets.elementsEqual(self.sheets, by: ===) {
            changes.sheets = sheets
            self.sheets = sheets
        }
        let overlay = window.children.first { $0.type == .overlay }
        if overlay !== self.overlay {
            changes.overlay = .some(overlay)
            self.overlay = overlay
        }
        let requested = WindowFrame(of: window)
        let frame = requested.changes(since: self.requested)
        self.requested = requested
        if !frame.isEmpty { changes.frame = frame }
        let bounds = WindowBounds(of: window)
        if bounds != self.bounds {
            changes.bounds = bounds
            self.bounds = bounds
        }
        let traits = WindowTraits(of: window, in: lifecycle)
        if traits != self.traits {
            changes.traits = traits
            self.traits = traits
        }
        let hidden = lifecycle.isHiddenByScene(window)
        if hidden != self.hidden {
            changes.hidden = hidden
            self.hidden = hidden
        }
        let owner = window.ownerWindow
        if !ownerSaid || owner !== self.owner {
            changes.owner = .some(owner)
            self.owner = owner
            ownerSaid = true
        }

        let visible = sheets.last ?? arrangement
        if visible !== previousVisible {
            let reason: PagePresentationReason = hadSheets || !sheets.isEmpty ? .navigation : .window
            previousVisible?.setPagePresented(false, reason: reason)
            visible?.setPagePresented(true, reason: reason)
        }
        if window !== created {
            created = window
            window.tellPhase(.created)
        }
        return changes
    }

    /// The way back the window offers: the top sheet's own stack, else the top sheet going, else the stack of the
    /// arrangement; nil where there is none.
    /// Design: docs/design/host/pages.md#the-way-back
    public var wayBack: WayBack? {
        if let top = sheets.last {
            return top.visibleBackStack.map(WayBack.pop) ?? .dismissSheet(remaining: sheets.count - 1)
        }
        return arrangement?.visibleBackStack.map(WayBack.pop)
    }
}
