// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A shared transition drawn by both views, the same on every host: the view leaving kept for its partner, its
/// keyed view taken along onto where the partner lands, and what each frame works out of how far either has got.
/// Design: docs/design/host/motion.md#a-shared-transition-drawn-by-both
extension MountedElement {
    /// The numbers a view kept for its partner is drawn with as it stops being the application's.
    static let travelingProperties: [Prop] = [.opacity, .translationX, .translationY, .scale, .scaleX, .scaleY]

    /// How far this element's way has got; nil where it travels none.
    var wayProgress: Double? {
        guard let way else { return nil }
        return way.progress { tree?.presentedPropertyValue(mount: mount, property: $0)?.number }
    }

    /// What a way works out for `property` on this frame: the opacity and the corner of the view traveling it -
    /// drawn as far as the way has got, the corner over the scale it is drawn at; nil for anything else.
    func wayValue(_ property: Prop) -> HostValue? {
        if property == .opacity, let way, way.comes != nil, let progress = wayProgress {
            return .number((plainValue(.opacity)?.number ?? 1) * way.opacity(at: progress))
        }
        guard property == .cornerRadius || property == .shape, let way, property == roundingProperty,
              let progress = wayProgress, let drawn = way.drawnCorner(at: progress)
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
        // A view under it ends a way it was entering by: only a keyed view this one sends along travels one now.
        var under = held
        while let each = under.popLast() {
            if each.value(ViewContract.sharedTransition.token) != nil { each.holdStanding(in: tree) }
            each.endWay()
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

    /// The element kept for its partner sends its keyed view `keyed` along: drawn at `source` in the scope `scope`
    /// and moving at `speed` there, it is taken onto `destination` under `law`, its corner carried by `corner`,
    /// crossing over its partner in `crossing` where it is drawn in front. Each keyed view goes its own way; this
    /// element stands where it is drawn, what else it holds fades out there, and it is released as the last lands.
    func goAlong(
        keyed: MountedElement, from source: Rect, onto destination: Rect, in scope: UInt64, under law: Motion?,
        speed: RectSpeed, corner: (from: Double, to: Double)?, crossing: ClosedRange<Double>?
    ) {
        guard let tree, let law, lifecycle == .exiting, keyed.lifecycle == .exiting,
              let frame = keyed.native.frameNumbers(), frame.count >= 8, source.width > 0, source.height > 0
        else { return }

        // The keyed view's own place, and where it lands as its own transform draws it there: what holds it - this
        // element standing as drawn - undone, and the place its layout's program gives it.
        let place = Rect(x: frame[4], y: frame[5], width: frame[2], height: frame[3])
        let placing = keyed.placingTransform
        let above = SharedTransitions.undrawn(destination, above: keyed, to: scope)
        let lands = placing?.place(drawnAs: above, within: place) ?? above
        guard place.width > 0, place.height > 0 else { return }
        if keyed !== self { standStill(in: tree) }
        keyed.standUnfaded(in: tree)

        let own = keyed.drawingTransform
        let pivot = Point(x: place.x + place.width * own.pivotX, y: place.y + place.height * own.pivotY)
        let (wide, tall) = (lands.width / place.width, lands.height / place.height)
        let uniform = keyed.number(.scale) ?? 1
        let speeds = keyed.ownSpeed(drawnAt: speed, place: place, in: scope)
        let targets: [(Prop, Double, Double)] = [
            (.translationX, lands.x + lands.width / 2 - pivot.x - wide * (place.x + place.width / 2 - pivot.x), 0),
            (.translationY, lands.y + lands.height / 2 - pivot.y - tall * (place.y + place.height / 2 - pivot.y), 0),
            (.scaleX, wide / uniform, 1), (.scaleY, tall / uniform, 1),
        ]
        var spans: [Prop: (from: Double, to: Double)] = [:]
        var started = 0
        for (property, target, unsaid) in targets {
            let standing = keyed.standsAt[property]?.value ?? keyed.number(property) ?? unsaid
            spans[property] = (standing, target)
            keyed.exitEnds[property] = target
            if tree.receiveProperty(
                mount: keyed.mount, property: property, standing: .number(standing), target: .number(target),
                motion: law, landed: { [weak self] in self?.exitLanded() }, velocity: [speeds[property] ?? 0]
            ) { started += 1 }
        }
        guard started > 0 else { return }

        exitsRunning += started
        keyed.way = SharedWay(spans: spans, corner: corner, comes: crossing.map { _ in false }, crossing: crossing ?? 0...1)
        if keyed !== self { tree.mounted(keyed) }
        var drawnNow = Set(SharedWay.moved)
        if crossing != nil { drawnNow.insert(.opacity) }
        if corner != nil, let rounding = keyed.roundingProperty { drawnNow.insert(rounding) }
        keyed.native.presentFrame(drawnNow)
        if keyed !== self { fadeTheRest(under: law, in: tree) }
    }

    /// The keyed view going along is drawn no more, the view it went along with having left; it goes as its runs
    /// land, so nothing is let go - and nothing arranged - while the patch dropping that view is applied.
    func stopsGoingAlong() {
        guard way != nil, lifecycle == .exiting else { return }
        way = nil
        exitEnds[.opacity] = 0
        native.presentFrame([.opacity])
    }

    /// Stands each number of the element's transform where it is drawn, its run cut short.
    private func standStill(in tree: MountedTree) {
        for property in Self.travelingProperties where property != .opacity {
            guard let standing = tree.standingProperty(mount: mount, property: property),
                  let value = standing.value.number
            else { continue }
            standsAt[property] = (value, 0)
            tree.receiveProperty(mount: mount, property: property, standing: nil, target: nil, motion: nil)
        }
    }

    /// What the element holds besides the keyed views going along fades out where it stands, under `law`; a view
    /// that came to hold one, or to be one, stands whole again.
    private func fadeTheRest(under law: Motion, in tree: MountedTree) {
        var holding: [MountedElement] = [self]
        while let each = holding.popLast() {
            for child in each.held where child.way == nil {
                if child.holdsAWay {
                    child.standUnfaded(in: tree)
                    holding.append(child)
                } else if child.exitEnds[.opacity] == nil {
                    let standing = child.number(.opacity) ?? 1
                    child.exitEnds[.opacity] = 0
                    tree.mounted(child)
                    tree.receiveProperty(
                        mount: child.mount, property: .opacity, standing: .number(standing), target: .number(0),
                        motion: law)
                    child.native.presentFrame([.opacity])
                }
            }
        }
    }

    /// Whether a view under the element travels a shared transition's way.
    private var holdsAWay: Bool {
        held.contains { $0.way != nil || $0.holdsAWay }
    }

    /// The element, faded as the rest of a view kept for its partner, stands whole again.
    private func standUnfaded(in tree: MountedTree) {
        guard exitEnds[.opacity] == 0 else { return }
        exitEnds[.opacity] = nil
        tree.receiveProperty(mount: mount, property: .opacity, standing: nil, target: nil, motion: nil)
        native.presentFrame([.opacity])
    }
}
