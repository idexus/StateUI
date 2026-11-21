// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A shared transition drawn by both views, the same on every host: the view leaving kept for its partner and
/// taken along onto where the partner lands, and what each frame works out of how far either has got.
/// Design: docs/design/host/motion.md#a-shared-transition-drawn-by-both
extension MountedElement {
    /// The numbers a view kept for its partner is drawn with as it stops being the application's.
    static let travelingProperties: [Prop] = [.opacity, .translationX, .translationY, .scale, .scaleX, .scaleY]

    /// How far this element's way has got; nil where it travels none.
    var wayProgress: Double? {
        guard let way else { return nil }
        return way.progress { tree?.presentedPropertyValue(mount: mount, property: $0)?.number }
    }

    /// What a way works out for `property` on this frame: the opacity of the view traveling it, the corner of the
    /// view rounded on it - drawn as far as the way has got, over the scale it is drawn at; nil for anything else.
    func wayValue(_ property: Prop) -> HostValue? {
        if property == .opacity, let way, way.comes != nil, let progress = wayProgress {
            return .number((plainValue(.opacity)?.number ?? 1) * way.opacity(at: progress))
        }
        let traveler = roundedBy ?? self
        guard property == .cornerRadius || property == .shape, let way = traveler.way, way.rounded === self,
              property == roundingProperty, let progress = traveler.wayProgress, let drawn = way.drawnCorner(at: progress)
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
        for property in Self.travelingProperties {
            if let binding = driven[property], binding.kind == .property,
               let standing = tree.stateChannels.standing(of: binding.state, now: tree.time) {
                standsAt[property] = standing
            } else if let standing = tree.standingProperty(mount: mount, property: property),
                      let value = standing.value.number {
                standsAt[property] = (value, standing.velocity.first ?? 0)
            }
        }
        deactivate(kept: true)
        parent.keptExits.append(self)
        tree.shared.awaits(self)
        return true
    }

    /// The element kept for its partner goes along: its view `keyed`, drawn at `source` in the scope `scope`, is
    /// taken from where it is drawn, at the speed it had, onto `destination` there under `law`, its corner carried
    /// by `corner` and fading out as the two cross over in `crossing`; released as it lands.
    func goAlong(
        keyed: MountedElement, from source: Rect, onto destination: Rect, in scope: UInt64, under law: Motion?,
        corner: (from: Double, to: Double)?, crossing: ClosedRange<Double>
    ) {
        guard let tree, let law, lifecycle == .exiting, let frame = native.frameNumbers(), frame.count >= 8,
              source.width > 0, source.height > 0
        else { return endExit(.finished, arranging: true) }

        // Both as this element's own place stands, what holds it undone, and the keyed view with none of this
        // element's transform: its drawn one undone about the pivot.
        let place = Rect(x: frame[4], y: frame[5], width: frame[2], height: frame[3])
        let drawn = drawingTransform
        let pivot = Point(x: place.x + place.width * drawn.pivotX, y: place.y + place.height * drawn.pivotY)
        let bare = drawn.place(drawnAs: SharedTransitions.undrawn(source, above: self, to: scope), within: place)
        let destination = SharedTransitions.undrawn(destination, above: self, to: scope)
        guard bare.width > 0, bare.height > 0 else { return endExit(.finished, arranging: true) }
        let (wide, tall) = (destination.width / bare.width, destination.height / bare.height)
        let uniform = number(.scale) ?? 1
        let targets: [(Prop, Double, Double)] = [
            (.translationX, destination.x + destination.width / 2 - pivot.x - wide * (bare.x + bare.width / 2 - pivot.x), 0),
            (.translationY, destination.y + destination.height / 2 - pivot.y - tall * (bare.y + bare.height / 2 - pivot.y), 0),
            (.scaleX, wide / uniform, 1), (.scaleY, tall / uniform, 1),
        ]
        var spans: [Prop: (from: Double, to: Double)] = [:]
        exitsRunning = 0
        for (property, target, unsaid) in targets {
            let standing = standsAt[property] ?? (number(property) ?? unsaid, 0)
            spans[property] = (standing.value, target)
            exitEnds[property] = target
            if tree.receiveProperty(
                mount: mount, property: property, standing: .number(standing.value), target: .number(target),
                motion: law, landed: { [weak self] in self?.exitLanded() }, velocity: [standing.velocity]
            ) { exitsRunning += 1 }
        }
        way = SharedWay(spans: spans, rounded: keyed, corner: corner, comes: false, crossing: crossing)
        keyed.roundedBy = keyed === self ? nil : self
        guard exitsRunning > 0 else { return endExit(.finished, arranging: true) }

        native.presentFrame(Set(SharedWay.moved).union([.opacity]))
        if let rounding = keyed.roundingProperty, corner != nil { keyed.native.presentFrame([rounding]) }
    }
}
