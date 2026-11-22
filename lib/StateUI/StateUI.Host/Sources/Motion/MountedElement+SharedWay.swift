// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A shared transition drawn by both views, the same on every host: the view leaving kept for its partner, its
/// keyed view taken along onto where the partner lands, and what each frame works out of how far either has got.
/// Design: docs/design/host/motion.md#a-shared-transition-drawn-by-both
extension MountedElement {
    /// The numbers a view kept for its partner is drawn with as it stops being the application's.
    static let travelingProperties: [Prop] = [.opacity, .translationX, .translationY, .scale, .scaleX, .scaleY]

    /// How far this element's way has got, read off the view traveling it; nil where it has none.
    var wayProgress: Double? {
        guard let way else { return nil }
        let traveler = way.traveler ?? self
        return way.progress { tree?.presentedPropertyValue(mount: traveler.mount, property: $0)?.number }
    }

    /// What a way works out for `property` on this frame: the opacity of the view whose way it is, the corner of
    /// the view traveling it - drawn as far as the way has got, over the scale it is drawn at; nil for anything else.
    func wayValue(_ property: Prop) -> HostValue? {
        if property == .opacity, let way, way.comes != nil, let progress = wayProgress {
            return .number((plainValue(.opacity)?.number ?? 1) * way.opacity(at: progress))
        }
        let holder = travelsFor ?? self
        guard property == .cornerRadius || property == .shape, let way = holder.way, way.traveler === self,
              property == roundingProperty, let progress = holder.wayProgress, let drawn = way.drawnCorner(at: progress)
        else { return nil }

        let radius = drawn / max(scaleInScope, 0.01)
        return property == .cornerRadius ? .number(radius) : ContainerShape.roundedRectangle(radius).propValue
    }

    /// The property the element's corner is rounded by: a rectangle's corner, else a rounded outline; nil for none.
    var roundingProperty: Prop? {
        if type == .rectangle { return .cornerRadius }
        if case .roundedRectangle? = plainValue(.shape).flatMap(ContainerShape.init(propValue:)) { return .shape }
        return nil
    }

    /// The one corner the element declares, in its own points; nil where it rounds by none, or by four.
    var ownCorner: Double? {
        switch roundingProperty {
        case .cornerRadius?: return plainValue(.cornerRadius)?.number
        case .shape?:
            guard case .roundedRectangle(let radius)? = plainValue(.shape).flatMap(ContainerShape.init(propValue:))
            else { return nil }
            return radius
        default: return nil
        }
    }

    /// How large the element is drawn in the scope of its shared transitions: by its own scales and those of
    /// what holds it, up to the scope.
    var scaleInScope: Double {
        var (scale, each) = (1.0, Optional(self))
        while let element = each, element.value(LayoutContract.transitionScope.token) == nil {
            let drawn = element.drawnTransform
            scale *= abs(drawn.scaleX * drawn.scaleY).squareRoot()
            each = element.parent
        }
        return scale
    }

    /// Keeps the element as it leaves `parent` for the partner its patch may make - a view under it wears a key,
    /// `parent`'s view keeps one that left, no engine runs under it and the window's budget holds - standing as
    /// drawn, its numbers held where they stood, a state's too, with their speed. False where it is to go at once.
    func awaitsPartner(in parent: MountedElement, holdingAKey: Bool) -> Bool {
        guard holdingAKey, lifecycle == .active, let tree, !tree.remakes, parent.native.keepsExits, !holdsAnEngine,
              tree.exits.admit(self, at: tree.time)
        else { return false }

        exitPlace = tree.layoutMotion.placed(mount)?.place
        holdStanding(in: tree)
        var under = held
        while let each = under.popLast() {
            if each.value(ViewContract.sharedTransition.token) != nil { each.holdStanding(in: tree) }
            under += each.held
        }
        deactivate(kept: true)
        parent.keptExits.append(self)
        tree.shared.awaits(self)
        return true
    }

    /// Notes where each number the element is drawn with stands, with its speed - a state's too - before it stops
    /// being the application's.
    private func holdStanding(in tree: MountedTree) {
        for property in Self.travelingProperties {
            if let binding = driven[property], binding.kind == .property,
               let standing = tree.stateChannels.standing(of: binding.state, now: tree.time) {
                standsAt[property] = standing
            } else if let standing = tree.standingProperty(mount: mount, property: property),
                      let value = standing.value.number {
                standsAt[property] = (value, standing.velocity.first ?? 0)
            }
        }
    }

    /// The element kept for its partner goes along: its keyed view `keyed`, drawn at `source` in the scope `scope`,
    /// is taken from where it is drawn, at the speed it had - this element's own included - onto `destination`
    /// there under `law`, its corner carried by `corner`; what else the element holds stands where it is drawn, and
    /// it fades out as the two cross over in `crossing`; released as the keyed view lands.
    func goAlong(
        keyed: MountedElement, from source: Rect, onto destination: Rect, in scope: UInt64, under law: Motion?,
        corner: (from: Double, to: Double)?, crossing: ClosedRange<Double>
    ) {
        guard let tree, let law, lifecycle == .exiting, keyed.lifecycle == .exiting,
              let frame = keyed.native.frameNumbers(), frame.count >= 8, source.width > 0, source.height > 0
        else { return endExit(.finished, arranging: true) }

        // The keyed view's own place, and where it lands as its own transform draws it there: what holds it, this
        // element standing as drawn, undone, and the place its layout's program gives it.
        let place = Rect(x: frame[4], y: frame[5], width: frame[2], height: frame[3])
        let placing = keyed.placingTransform
        let above = SharedTransitions.undrawn(destination, above: keyed, to: scope)
        let lands = placing?.place(drawnAs: above, within: place) ?? above
        guard place.width > 0, place.height > 0 else { return endExit(.finished, arranging: true) }
        let carried = keyed === self ? [:] : standStill(carrying: keyed, drawnAt: source, in: scope, placing: placing)

        let own = keyed.drawingTransform
        let pivot = Point(x: place.x + place.width * own.pivotX, y: place.y + place.height * own.pivotY)
        let (wide, tall) = (lands.width / place.width, lands.height / place.height)
        let uniform = keyed.number(.scale) ?? 1
        let targets: [(Prop, Double, Double)] = [
            (.translationX, lands.x + lands.width / 2 - pivot.x - wide * (place.x + place.width / 2 - pivot.x), 0),
            (.translationY, lands.y + lands.height / 2 - pivot.y - tall * (place.y + place.height / 2 - pivot.y), 0),
            (.scaleX, wide / uniform, 1), (.scaleY, tall / uniform, 1),
        ]
        var spans: [Prop: (from: Double, to: Double)] = [:]
        exitsRunning = 0
        for (property, target, unsaid) in targets {
            let standing = keyed.standsAt[property] ?? (keyed.number(property) ?? unsaid, 0)
            spans[property] = (standing.value, target)
            keyed.exitEnds[property] = target
            if tree.receiveProperty(
                mount: keyed.mount, property: property, standing: .number(standing.value), target: .number(target),
                motion: law, landed: { [weak self] in self?.exitLanded() },
                velocity: [standing.velocity + (carried[property] ?? 0)]
            ) { exitsRunning += 1 }
        }
        way = SharedWay(spans: spans, traveler: keyed, corner: corner, comes: false, crossing: crossing)
        if keyed !== self {
            keyed.travelsFor = self
            tree.mounted(keyed)
        }
        guard exitsRunning > 0 else { return endExit(.finished, arranging: true) }

        var drawnNow = Set(SharedWay.moved)
        if corner != nil, let rounding = keyed.roundingProperty { drawnNow.insert(rounding) }
        if keyed === self { drawnNow.insert(.opacity) } else { native.presentFrame([.opacity]) }
        keyed.native.presentFrame(drawnNow)
    }

    /// Stands each number of the element's transform where it is drawn, its motion cut short, and says the speed
    /// it drew `keyed` - drawn at `source` in the scope `scope`, its layout's program placing it by `placing` - in
    /// `keyed`'s own numbers: a throw goes on in the keyed view.
    private func standStill(
        carrying keyed: MountedElement, drawnAt source: Rect, in scope: UInt64, placing: HostDrawingTransform?
    ) -> [Prop: Double] {
        guard let tree, let frame = native.frameNumbers(), frame.count >= 8 else { return [:] }

        for property in Self.travelingProperties where property != .opacity {
            guard let standing = tree.standingProperty(mount: mount, property: property),
                  let value = standing.value.number
            else { continue }
            standsAt[property] = (value, standing.velocity.first ?? 0)
            tree.receiveProperty(mount: mount, property: property, standing: nil, target: nil, motion: nil)
        }
        let place = Rect(x: frame[4], y: frame[5], width: frame[2], height: frame[3])
        let drawn = drawingTransform
        let pivot = Point(x: place.x + place.width * drawn.pivotX, y: place.y + place.height * drawn.pivotY)
        let bare = drawn.place(drawnAs: SharedTransitions.undrawn(source, above: self, to: scope), within: place)
        let speed = { (property: Prop) in self.standsAt[property]?.velocity ?? 0 }
        let uniform = number(.scale) ?? 1
        let scaling = (x: speed(.scale) * (number(.scaleX) ?? 1) + uniform * speed(.scaleX),
                       y: speed(.scale) * (number(.scaleY) ?? 1) + uniform * speed(.scaleY))
        // How large a move of the keyed view's own is drawn here: by its place's scale and every one above it.
        var between = (x: (placing?.scaleX ?? 1) * drawn.scaleX, y: (placing?.scaleY ?? 1) * drawn.scaleY)
        var holder = keyed.parent
        while let each = holder, each !== self {
            (between.x, between.y) = (between.x * each.drawnTransform.scaleX, between.y * each.drawnTransform.scaleY)
            holder = each.parent
        }
        guard between.x != 0, between.y != 0, drawn.scaleX != 0, drawn.scaleY != 0 else { return [:] }
        return [
            .translationX: (speed(.translationX) + scaling.x * (bare.x + bare.width / 2 - pivot.x)) / between.x,
            .translationY: (speed(.translationY) + scaling.y * (bare.y + bare.height / 2 - pivot.y)) / between.y,
            .scaleX: scaling.x * (keyed.number(.scaleX) ?? 1) / drawn.scaleX,
            .scaleY: scaling.y * (keyed.number(.scaleY) ?? 1) / drawn.scaleY,
        ]
    }
}
