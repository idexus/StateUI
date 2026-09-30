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

        /// What the window lays over its pages and sheets now, where that changed: each layer, the first lowest.
        public var overlays: [MountedElement]?

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

    /// What is laid over the pages and sheets, each layer an overlay element, the first lowest.
    public private(set) var overlays: [MountedElement] = []
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

        // A modal stack standing as the window's page: its root is what the window shows, its other pages the sheets.
        // Design: docs/design/host/tree.md#a-window-shown
        let page = window.children.first { NodeType.pageTypes.contains($0.type) }
        let modalStack = page?.type == .modalStack ? page : nil
        let arrangement = modalStack?.children.first ?? page
        if arrangement !== self.arrangement {
            changes.arrangement = (self.arrangement, arrangement)
            self.arrangement = arrangement
        }
        let sheets = modalStack.map { Array($0.children.dropFirst()) } ?? []
        if !sheets.elementsEqual(self.sheets, by: ===) {
            changes.sheets = sheets
            self.sheets = sheets
        }
        let overlays = Self.overlays(of: window, over: [arrangement].compactMap { $0 } + sheets)
        if !overlays.elementsEqual(self.overlays, by: ===) {
            changes.overlays = overlays
            self.overlays = overlays
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

    /// The layers laid over `window`, the first lowest: those declared along the path of each page it shows - the
    /// arrangement's, then each sheet's - the outer under the inner, then the library's own, over every other.
    /// Design: docs/design/host/pages.md#the-overlays-of-a-window
    private static func overlays(of window: MountedElement, over shown: [MountedElement]) -> [MountedElement] {
        shown.flatMap { $0.visiblePage?.declared(.overlay).map(\.element) ?? [] }
            + window.children.filter { $0.type == .overlay }
    }
}
