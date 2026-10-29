// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's bottom bar over the page's foot: its view as tall as it lays out across the safe area, on the keyboard
/// while one shows (`BottomBarPlace`), reaching `BottomBarPlace.fade` above its view; a scroller under it fades
/// softly under it - by UIKit's own scroll edge effect on iOS 26, and on the ground the host draws on iOS 27, which
/// draws no soft edge at all: what the page stands on, while anything passes under the bar.
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
final class UIKitBottomBarView: UIKitLayoutView {
    /// The ground iOS 27 gets: what the page stands on, fading out above the bar's view - no touch of its own.
    private let ground: UIView = {
        let ground = UIView()
        ground.isUserInteractionEnabled = false
        ground.isHidden = true
        return ground
    }()

    /// The ground's blur where the page stands on one; nil where it stands on a color.
    private var blur: UIKitBackdropView?

    /// The material the ground shows.
    private var material: HostMaterial?

    /// The ground's fade: clear at its top, whole from the bar's view down (`BottomBarPlace.fade`).
    private let fade: CAGradientLayer = {
        let fade = CAGradientLayer()
        fade.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        fade.startPoint = CGPoint(x: 0.5, y: 0)
        fade.endPoint = CGPoint(x: 0.5, y: 1)
        return fade
    }()

    /// Where the bar's view stands within the bar.
    private var barRoom = Rect(x: 0, y: 0, width: 0, height: 0)

    /// Whether this iOS draws the soft edge itself.
    private var drawsSoftEdge: Bool {
        if #available(iOS 27.0, *) { false } else { true }
    }

    /// Shows `bar` - the visible page's bottom bar - in place of what it showed; nil for none.
    func show(_ bar: MountedElement?) {
        setItems(bar?.uiKit.layoutItem.map { [$0] } ?? [])
        if ground.superview !== self { insertSubview(ground, at: 0) }
    }

    /// Where the bar stands at the foot of `safe` in `whole`, measured again - what it shows may have changed its
    /// size; nil where it shows nothing.
    func place(safe: Rect, whole: Rect) -> BottomBarPlace? {
        forgetMeasurements()
        guard let item = items.first, item.isShown else { return nil }
        return BottomBarPlace(height: measuredSize(width: safe.width).height, safe: safe, whole: whole)
    }

    /// Stands the bar at `place` - across the room's foot from the fade above its view down to the room's edge - and
    /// follows what of `page` stands under it: its content, `scroller`'s rows as they move. Nowhere for no place.
    func stand(at place: BottomBarPlace?, over page: MountedElement?, scroller: UIKitScrollView?) {
        guard let place else { return frame = .zero }
        let fade = BottomBarPlace.fade
        let top = place.bar.y - fade
        frame = CGRect(
            x: place.ground.x, y: top, width: place.ground.width, height: place.ground.y + place.ground.height - top)
        barRoom = Rect(x: place.bar.x - place.ground.x, y: fade, width: place.bar.width, height: place.bar.height)
        setNeedsLayout()
        if drawsSoftEdge {
            standOver(scroller?.scroller)
            return
        }
        if let page { showGround(page.bottomBarGround) }
        let runsUnder = page.map {
            SafeAreaArithmetic.under($0.contentIgnoresSafeArea, direction: $0.layoutDirection).bottom
        } ?? false
        let follow: () -> Void = { [weak self, weak scroller] in
            self?.ground.isHidden = !BottomBarPlace.covers(contentRunsUnder: runsUnder, scroller: scroller?.standing)
        }
        scroller?.standingChanged = follow
        follow()
    }

    /// UIKit's own soft edge under the bar, for `scroller`.
    private func standOver(_ scroller: UIScrollView?) {
        let edge = interactions.compactMap { $0 as? UIScrollEdgeElementContainerInteraction }.first ?? {
            let made = UIScrollEdgeElementContainerInteraction()
            made.edge = .bottom
            addInteraction(made)
            return made
        }()
        if edge.scrollView !== scroller { edge.scrollView = scroller }
        if let scroller, scroller.bottomEdgeEffect.style != .soft { scroller.bottomEdgeEffect.style = .soft }
    }

    /// Makes the ground of `material` - a blur and its tint, a color, or the page's own where it says nothing.
    private func showGround(_ material: HostMaterial) {
        guard material != self.material else { return }
        self.material = material
        if material.blur != nil {
            let shown = blur ?? UIKitBackdropView()
            if shown.superview !== ground { ground.addSubview(shown) }
            blur = shown
            ground.backgroundColor = nil
        } else {
            blur?.removeFromSuperview()
            blur = nil
            ground.backgroundColor = material.painted.flatMap { HostBrush($0).firstColor }.flatMap(UIColor.init(stateUI:))
                ?? superview?.backgroundColor ?? .systemBackground
        }
        setNeedsLayout()
    }

    /// A touch above the bar's view goes on to the rows under it.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        point.y >= barRoom.y && super.point(inside: point, with: event)
    }

    override func contentSize(width: Double?) -> LayoutSize {
        SingleChildArithmetic.size(of: items.first, width: width)
    }

    override func arrange(in bounds: Rect) {
        ground.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        fade.frame = ground.bounds
        fade.locations = [0, NSNumber(value: BottomBarPlace.fade / max(bounds.height, 1)), 1]
        if ground.layer.mask !== fade { ground.layer.mask = fade }
        if let blur, let material {
            blur.frame = ground.bounds
            blur.show(material, as: .rounded([0, 0, 0, 0]))
            let wash = blur.showsGlass ? UIKitBrush() : UIKitBrush(material.paint)
            blur.lay(wash, stroke: UIKitBrush(), width: 0, over: ground.bounds, along: .rectangle)
        }
        guard let item = items.first else { return }
        place(item, at: SingleChildArithmetic.place(of: item, in: barRoom, direction: direction))
    }
}
#endif
