// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The band under a room's toolbar, where the page runs under it: its hard edge (`barScrollEdge`) while the page's rows
/// pass under the toolbar - a blur in the page's hue, a line along its foot - which AppKit's toolbar offers no style
/// for. The automatic edge and none are macOS's own.
/// Design: docs/design/host/layout.md#a-bar-at-the-top
@MainActor
final class AppKitTopEdgeView: NSView {
    private let ground = AppKitMaterialView(BottomBarPlace.blur, behindWindow: false)
    private let line: NSBox = {
        let line = NSBox()
        line.boxType = .separator
        return line
    }()

    /// The edge the toolbar shows while rows pass under it.
    private(set) var edge = ScrollEdge.automatic

    /// Whether the page's content runs under the toolbar, and the scroller whose rows the band follows.
    private var runsUnder = false
    private weak var scroller: AppKitPageScroller?

    override var isFlipped: Bool { true }

    /// A click on the band goes on to the page under it.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Stands the band over `band` and shows what of `page` stands under it - its content, `scroller`'s rows, which
    /// its room has it `follow` as they move.
    func stand(in band: Rect, over page: MountedElement?, scroller: AppKitPageScroller?) {
        if ground.superview !== self { addSubview(ground) }
        if line.superview !== self { addSubview(line) }
        edge = page?.barScrollEdge ?? .automatic
        let color = page?.bottomBarTint.flatMap(paintedColor) ?? window?.backgroundColor
        ground.wash.wantsLayer = true
        ground.wash.layer?.backgroundColor = color.map { $0.withAlphaComponent($0.alphaComponent * BottomBarPlace.tint) }?
            .cgColor
        ground.wash.isHidden = color == nil
        frame = NSRect(placed: band)
        runsUnder = page.map { SafeAreaArithmetic.under($0.contentIgnoresSafeArea, direction: $0.layoutDirection).top }
            ?? false
        self.scroller = scroller
        needsLayout = true
        follow()
    }

    /// Shows the hard edge while anything of the page stands under the toolbar (`TopBarEdge.covers`).
    func follow() {
        let covered = TopBarEdge.covers(contentRunsUnder: runsUnder, scrollerOffset: scroller?.standing.offset)
        isHidden = !covered || edge != .hard
    }

    override func layout() {
        super.layout()
        ground.frame = bounds
        line.frame = NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
    }
}

#endif
