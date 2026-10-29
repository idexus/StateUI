// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's bottom bar in its room - a window's, a sheet's, a split view's pane: the bar's view at the room's foot over
/// the page, as tall as it lays out across the safe area (`BottomBarPlace`); on the page while nothing stands under
/// it, on a blur fading softly toward the content, down to the room's edge, while the page's rows pass under it.
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
final class AppKitBottomBarView: AppKitSingleChildView {
    /// What the bar stands on while anything stands under it: what its page stands on (`bottomBarGround`), blurring
    /// what passes under it where that is a blur - whole under the bar, fading out above it toward the content, past
    /// the bar's own bounds, so a click there reaches the rows.
    private let ground: NSView = {
        let ground = NSView()
        ground.wantsLayer = true
        ground.isHidden = true
        return ground
    }()

    /// The blur the ground is made of where the page stands on one; nil where it stands on a color.
    private var blur: AppKitMaterialView?

    /// The material the ground shows.
    private var material: HostMaterial?

    /// The ground's fade: clear at its top, whole from the bar's top down (`BottomBarPlace.fade`).
    private let fade: CAGradientLayer = {
        let fade = CAGradientLayer()
        fade.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor]
        return fade
    }()

    /// Where the bar's view stands on its ground.
    private var barRoom = Rect(x: 0, y: 0, width: 0, height: 0)

    /// Shows `bar` - the visible page's bottom bar - in place of what it showed; nil for none.
    func show(_ bar: MountedElement?) {
        setItem(bar?.appKit.layoutItem)
    }

    override func setItem(_ item: AppKitLayoutItem?) {
        super.setItem(item)
        if ground.superview !== self { addSubview(ground, positioned: .below, relativeTo: nil) }
    }

    /// Makes the ground of `material` - a blur and its tint, a color, or the window's own where it says nothing.
    private func showGround(_ material: HostMaterial) {
        guard material != self.material else { return }
        self.material = material
        let thickness = material.blur ?? (material.isEmpty ? .ultraThick : nil)
        if let thickness {
            let shown = blur ?? AppKitMaterialView(thickness, behindWindow: false)
            shown.material = AppKitMaterialView.role(thickness)
            shown.wash.layer?.backgroundColor = paintedColor(material.paint)?.cgColor
            shown.wash.isHidden = material.paint == nil
            if shown.superview !== ground { ground.addSubview(shown) }
            blur = shown
            ground.layer?.backgroundColor = nil
        } else {
            blur?.removeFromSuperview()
            blur = nil
            ground.layer?.backgroundColor = paintedColor(material.painted)?.cgColor
        }
        needsLayout = true
    }

    /// Where the bar stands at the foot of `safe` in `whole`, as tall as it lays out across it; nil where it shows
    /// nothing.
    func place(safe: Rect, whole: Rect) -> BottomBarPlace? {
        guard let item, item.isShown else { return nil }
        return BottomBarPlace(height: Double(fittingContentSize(width: safe.width).height), safe: safe, whole: whole)
    }

    /// Stands the bar at `place` - its ground across the room's foot, its view in the bar's place on it - and
    /// follows what of `page` stands under it: its content, `scroller`'s rows as they move. Nowhere for no place.
    func stand(at place: BottomBarPlace?, over page: MountedElement?, scroller: AppKitScrollView?) {
        guard let place else { return frame = .zero }
        if let page { showGround(page.bottomBarGround) }
        frame = NSRect(placed: place.ground)
        barRoom = Rect(x: place.bar.x - place.ground.x, y: 0, width: place.bar.width, height: place.bar.height)
        needsLayout = true
        let runsUnder = page.map {
            SafeAreaArithmetic.under($0.contentIgnoresSafeArea, direction: $0.layoutDirection).bottom
        } ?? false
        let follow: () -> Void = { [weak self, weak scroller] in
            self?.standsOnGround(BottomBarPlace.covers(contentRunsUnder: runsUnder, scroller: scroller?.standing))
        }
        scroller?.standingChanged = follow
        follow()
    }

    /// Shows the ground while anything stands under the bar.
    private func standsOnGround(_ covers: Bool) {
        ground.isHidden = !covers
    }

    override var childRoom: Rect { barRoom }

    override func layout() {
        let reach = CGFloat(BottomBarPlace.fade)
        ground.frame = NSRect(x: 0, y: -reach, width: bounds.width, height: bounds.height + reach)
        // The layer's own geometry, whichever way the view counts: the fade's clear end at the ground's top.
        let flipped = ground.layer?.contentsAreFlipped() ?? false
        (fade.startPoint, fade.endPoint) = flipped ? (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1))
            : (CGPoint(x: 0.5, y: 1), CGPoint(x: 0.5, y: 0))
        fade.locations = [0, NSNumber(value: Double(reach / max(ground.frame.height, 1))), 1]
        fade.frame = ground.bounds
        if ground.layer?.mask !== fade { ground.layer?.mask = fade }
        blur?.frame = ground.bounds
        super.layout()
    }
}

#endif
