// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A shared presentation drawn by both views, the same on every host: a view drawn from the presentation it shares,
/// and the view kept for its partner - its keyed views drawn from theirs, what else it holds fading where it stands.
/// Design: docs/design/host/motion.md#a-shared-presentation-drawn-by-both
extension MountedElement {
    /// The numbers a view kept for its partner is drawn with as it stops being the application's.
    static let travelingProperties: [Prop] = [.opacity, .translationX, .translationY, .scale, .scaleX, .scaleY]

    /// What the shared presentation the element is drawn from works out for `property` on this frame - its move and
    /// scale, its opacity as the two cross over, its corner; nil where it is drawn from none, and for anything else.
    func presentationValue(_ property: Prop) -> HostValue? {
        presentation?.value(property, of: self)
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

    /// Where views of one id share their presentation: the page the element stands on, else - on no page - the top
    /// of what holds it.
    var presentationScope: MountedElement? {
        var each = parent
        while let holder = each {
            if holder.type == .page || holder.parent == nil { return holder }
            each = holder.parent
        }
        return nil
    }

    /// How large the element is drawn in the scope of its shared presentation: by its own scales and those of what
    /// holds it, up to the scope.
    var scaleInScope: Double {
        let scope = presentationScope
        var (scale, each) = (1.0, Optional(self))
        while let element = each, element !== scope {
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
            if each.value(ViewContract.transitionID.token) != nil { each.holdStanding(in: tree) }
            under += each.held
        }
        deactivate(kept: true)
        parent.keptExits.append(self)
        tree.shared.awaits(self)
        return true
    }

    /// Notes where each number the element is drawn with stands as its last frame drew it, with its speed - a
    /// state's too - before it stops being the application's: what its toolkit shows is what the tree holds.
    private func holdStanding(in tree: MountedTree) {
        for property in Self.travelingProperties {
            if let binding = driven[property], binding.kind == .property,
               let drawn = tree.stateChannels.standing(binding.state), drawn.value.count == 1 {
                standsAt[property] = (drawn.value[0], drawn.velocity.first ?? 0)
            } else if let drawn = tree.presentedPropertyValue(mount: mount, property: property)?.number {
                standsAt[property] = (drawn, tree.standingProperty(mount: mount, property: property)?.velocity.first ?? 0)
            }
        }
    }

    /// The element kept for its partner lends its keyed view `keyed` to a shared presentation: it stands where it is
    /// drawn, its runs cut short, what else it holds fades out there under `law`, and it is released as the last
    /// presentation it lends a view to lands.
    func lends(_ keyed: MountedElement, to presentation: SharedPresentation, under law: Motion) {
        guard let tree, lifecycle == .exiting else { return }
        exitsRunning += 1
        presentation.keeps(self)
        guard keyed !== self else { return }
        standStill(in: tree)
        keyed.standUnfaded(in: tree)
        tree.mounted(keyed)
        fadeTheRest(under: law, in: tree)
    }

    /// Stands each number of the element's transform where its last frame drew it, its run cut short.
    private func standStill(in tree: MountedTree) {
        for property in Self.travelingProperties where property != .opacity {
            guard let value = tree.presentedPropertyValue(mount: mount, property: property)?.number else { continue }
            standsAt[property] = (value, 0)
            tree.receiveProperty(mount: mount, property: property, standing: nil, target: nil, motion: nil)
        }
    }

    /// What the element holds besides the keyed views drawn from a presentation fades out where it stands, under
    /// `law`; a view that came to hold one, or to be one, stands whole again.
    private func fadeTheRest(under law: Motion, in tree: MountedTree) {
        var holding: [MountedElement] = [self]
        while let each = holding.popLast() {
            for child in each.held where child.presentation == nil {
                if child.holdsAPresentation {
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

    /// Whether a view under the element is drawn from a shared presentation.
    private var holdsAPresentation: Bool {
        held.contains { $0.presentation != nil || $0.holdsAPresentation }
    }

    /// The element, faded as the rest of a view kept for its partner, stands whole again.
    private func standUnfaded(in tree: MountedTree) {
        guard exitEnds[.opacity] == 0 else { return }
        exitEnds[.opacity] = nil
        tree.receiveProperty(mount: mount, property: .opacity, standing: nil, target: nil, motion: nil)
        native.presentFrame([.opacity])
    }
}
