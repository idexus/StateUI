// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How fast a view is drawn moving, the same on every host: the runs of its own numbers and of every view above it,
/// carried through each transform up to a scope - and the speed of its own numbers that draws it so.
/// Design: docs/design/host/motion.md#a-shared-presentation
extension MountedElement {
    /// How fast `property` runs now: a state's lane while the element is the application's, else the tree's own
    /// animation; nought where nothing runs.
    func speed(of property: Prop) -> Double {
        guard let tree else { return 0 }
        if lifecycle == .active, let binding = driven[property], binding.kind == .property {
            return tree.stateChannels.standing(of: binding.state, now: tree.time)?.velocity ?? 0
        }
        return tree.standingProperty(mount: mount, property: property)?.velocity.first ?? 0
    }

    /// How fast the rectangle the element is drawn in moves in its window, as every view up to the scope `scope`
    /// draws it.
    func drawnSpeed(to scope: UInt64) -> RectSpeed {
        guard let numbers = native.frameNumbers(), numbers.count >= 8 else { return .still }
        let frame = Rect(x: numbers[4], y: numbers[5], width: numbers[2], height: numbers[3])
        var (rect, speed) = Self.carried(frame, .still, by: drawingTransform, within: frame, running: self)
        if let placing = placingTransform {
            (rect, speed) = Self.carried(rect, speed, by: placing, within: frame, running: nil)
        }
        var holder = parent
        while let each = holder, each.mount != scope {
            if let numbers = each.native.frameNumbers(), numbers.count >= 8 {
                let place = Rect(x: numbers[4], y: numbers[5], width: numbers[2], height: numbers[3])
                (rect, speed) = Self.carried(rect, speed, by: each.drawingTransform, within: place, running: each)
                if let placing = each.placingTransform {
                    (rect, speed) = Self.carried(rect, speed, by: placing, within: place, running: nil)
                }
            }
            holder = each.parent
        }
        return speed
    }

    /// The speed of each of the element's own numbers - its move and its scale - that draws it at `speed` in the
    /// scope `scope` from its place `place`, all above it standing still.
    func ownSpeed(drawnAt speed: RectSpeed, place: Rect, in scope: UInt64) -> [Prop: Double] {
        var above = (x: placingTransform?.scaleX ?? 1, y: placingTransform?.scaleY ?? 1)
        var holder = parent
        while let each = holder, each.mount != scope {
            (above.x, above.y) = (above.x * each.drawnTransform.scaleX, above.y * each.drawnTransform.scaleY)
            holder = each.parent
        }
        guard above.x != 0, above.y != 0, place.width > 0, place.height > 0 else { return [:] }

        let own = drawingTransform
        let uniform = number(.scale) ?? 1
        let pivot = Point(x: place.x + place.width * own.pivotX, y: place.y + place.height * own.pivotY)
        let scaling = (x: speed.width / (above.x * place.width), y: speed.height / (above.y * place.height))
        return [
            .translationX: speed.x / above.x - scaling.x * (place.x + place.width / 2 - pivot.x),
            .translationY: speed.y / above.y - scaling.y * (place.y + place.height / 2 - pivot.y),
            .scaleX: scaling.x / uniform, .scaleY: scaling.y / uniform,
        ]
    }

    /// `rect`, moving at `speed`, as `transform` draws it within `frame` - and its speed then, the numbers of
    /// `running` moving the transform as fast as they run.
    private static func carried(
        _ rect: Rect, _ speed: RectSpeed, by transform: HostDrawingTransform, within frame: Rect,
        running: MountedElement?
    ) -> (Rect, RectSpeed) {
        let pivot = Point(x: frame.x + frame.width * transform.pivotX, y: frame.y + frame.height * transform.pivotY)
        let scaling = running.map { view in
            (x: view.speed(of: .scale) * (view.number(.scaleX) ?? 1) + (view.number(.scale) ?? 1) * view.speed(of: .scaleX),
             y: view.speed(of: .scale) * (view.number(.scaleY) ?? 1) + (view.number(.scale) ?? 1) * view.speed(of: .scaleY))
        } ?? (x: 0, y: 0)
        let moving = (x: running?.speed(of: .translationX) ?? 0, y: running?.speed(of: .translationY) ?? 0)
        let carried = RectSpeed(
            x: transform.scaleX * speed.x + moving.x + scaling.x * (rect.x + rect.width / 2 - pivot.x),
            y: transform.scaleY * speed.y + moving.y + scaling.y * (rect.y + rect.height / 2 - pivot.y),
            width: transform.scaleX * speed.width + scaling.x * rect.width,
            height: transform.scaleY * speed.height + scaling.y * rect.height)
        return (transform.bounds(of: rect, within: frame), carried)
    }
}
