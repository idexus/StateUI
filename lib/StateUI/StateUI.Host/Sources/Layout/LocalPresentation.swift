// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import StateUIFoundation

/// What the user's hand does to an element's own presentation, beside what its layout says: the offset its press
/// answers, how far a drag has taken it from where the hand took it - nil while no hand holds it - and, let go, how
/// fast the hand went.
/// Design: docs/design/host/interaction.md#a-views-own-press-and-drag
struct LocalPresentation: Equatable, Sendable {
    var pressed = PresentationOffset.identity
    var held: Point?
    var letGo = Point.zero

    /// Whether the hand does nothing to the element.
    var isIdle: Bool { pressed == .identity && held == nil }

    /// Where `point` of a view `size` large as it is drawn stands in the view as its layout places it: scaled and
    /// turned about the view's middle by its press's offset, moved by it and by the hand that holds it. A toolkit
    /// tells a press in the view it draws; an effect is handed it here, so what it answers moves nothing it is
    /// handed.
    func placed(_ point: Point, in size: LayoutSize) -> Point {
        guard !isIdle else { return point }

        let (across, down) = ((point.x - size.width / 2) * pressed.scaleX, (point.y - size.height / 2) * pressed.scaleY)
        let angle = pressed.rotation * .pi / 180
        let held = held ?? .zero
        return Point(
            x: size.width / 2 + across * cos(angle) - down * sin(angle) + pressed.translation.x + held.x,
            y: size.height / 2 + across * sin(angle) + down * cos(angle) + pressed.translation.y + held.y)
    }
}

extension PresentationOffset {
    /// `place` drawn by this offset: moved and turned by it, scaled by it, its rectangle and its order its own.
    func applied(to place: HostPlacement) -> HostPlacement {
        guard self != .identity else { return place }

        return HostPlacement(
            bounds: place.bounds, translationX: place.translationX + translation.x,
            translationY: place.translationY + translation.y, rotation: place.rotation + rotation,
            scaleX: place.scaleX * scaleX, scaleY: place.scaleY * scaleY, opacity: place.opacity,
            zIndex: place.zIndex, shade: place.shade)
    }
}

extension HostPlacement {
    /// The placement with its middle `moved` from the middle of `taken`, its look its own: a view the hand holds,
    /// pinned to the hand in its layout's room.
    func pinned(to taken: HostPlacement, moved: Point) -> HostPlacement {
        let across = taken.bounds.x + taken.bounds.width / 2 + moved.x - bounds.width / 2
        let down = taken.bounds.y + taken.bounds.height / 2 + moved.y - bounds.height / 2
        return HostPlacement(
            bounds: Rect(x: across, y: down, width: bounds.width, height: bounds.height), translationX: translationX,
            translationY: translationY, rotation: rotation, scaleX: scaleX, scaleY: scaleY, opacity: opacity,
            zIndex: zIndex, shade: shade)
    }

    /// The placement ranked `rank` among its siblings.
    func ranked(_ rank: Int) -> HostPlacement {
        HostPlacement(
            bounds: bounds, translationX: translationX, translationY: translationY, rotation: rotation, scaleX: scaleX,
            scaleY: scaleY, opacity: opacity, zIndex: rank, shade: shade)
    }
}
