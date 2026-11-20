// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/views/interaction.md#a-views-own-press-and-drag

import StateUIFoundation

extension Interaction {
    /// A view's own press: which numbers of its presentation it moves, what its effect answers, and the spring
    /// the view comes after the answer on - none for a view that is there at once.
    struct Press {
        let values: PresentationValues
        var spring: Spring?
        let effect: @MainActor (PressInput) -> PresentationOffset
    }

    /// A view's own drag: which ways the hand takes it, and when.
    struct Drag: Equatable {
        let axes: DragAxes
        let begins: DragStart
        var dismissal: HostDismissal?
    }

    /// The view drawn as `effect` says while a press stands on it, and where its layout puts it again once the
    /// press lifts or is taken away.
    ///
    ///     .interaction(.press(values: .scale) { press in
    ///         PresentationOffset(scaleX: 0.96, scaleY: 0.96)
    ///     })
    ///
    /// The press is watched, never taken: a tap, a scroll and a drag go on as they would. The effect is asked on a
    /// frame the press moved; it writes no state and calls nothing, and of what it answers only `values` is kept.
    ///
    /// - Parameters:
    ///   - values: the numbers of the view's presentation the press moves.
    ///   - effect: the offset for the press as it stands.
    /// - Returns: the interaction.
    public static func press(
        values: PresentationValues, _ effect: @escaping @MainActor (PressInput) -> PresentationOffset
    ) -> Interaction {
        Interaction(leaves: [], isSet: false, press: Press(values: values, effect: effect))
    }

    /// The view grown a little under a press and pulled toward it, as a band stretched: drawn `scale` times as
    /// large wherever the press stands, moved by where it stands about the view's middle - quickly at first, less
    /// and less toward an edge, `maximumOffset` there - and stretched the way it is pulled: wider as the press
    /// goes across, taller as it goes down, `maximumScale` at that edge.
    ///
    ///     Card().interaction(.elasticPress())
    ///
    /// The view comes after the press on a spring of its own, with no jump as the press goes down, and springs
    /// back when it lifts.
    ///
    /// - Parameters:
    ///   - maximumOffset: how far the view is moved at its edge, in points.
    ///   - scale: how many times as large it is drawn under a press at its middle.
    ///   - maximumScale: how many times as wide it is drawn under a press at its left or right edge, and as tall
    ///     under one at its top or bottom.
    /// - Returns: the interaction.
    public static func elasticPress(
        maximumOffset: Double = 6, scale: Double = 1.02, maximumScale: Double = 1.04
    ) -> Interaction {
        var pressed = press(values: [.translation, .scale]) { press in
            let (across, down) = (stretched(press.normalizedLocation.x), stretched(press.normalizedLocation.y))
            return PresentationOffset(
                translation: Point(x: across * maximumOffset, y: down * maximumOffset),
                scaleX: scale + (maximumScale - scale) * abs(across),
                scaleY: scale + (maximumScale - scale) * abs(down))
        }
        pressed.press?.spring = Spring(response: .milliseconds(220), damping: 0.8)
        return pressed
    }

    /// How much of its way an elastic press has pulled a view at `share` of the way from the middle to an edge,
    /// either side: all of it at the edge, and more than `share` before - the pull's own curve, an exponential
    /// coming to rest.
    static func stretched(_ share: Double) -> Double {
        let far = min(abs(share), 1)
        let pulled = (1 - exp(-elasticity * far)) / (1 - exp(-elasticity))
        return share < 0 ? -pulled : pulled
    }

    /// How quickly an elastic press's pull comes to rest toward the edge: the higher, the sooner.
    static let elasticity = 2.5

    /// The hand taking the view by itself: it stays under the hand along `axes`, over what stands beside it, and
    /// goes back where its layout puts it once let go. It moves no state.
    ///
    ///     Card().interaction(.drag(.vertical, begins: .directional))
    ///
    /// - Parameters:
    ///   - axes: which ways the hand takes the view.
    ///   - begins: when it takes it: `.immediately` unless said; `.longPress` after a press standing still;
    ///     `.directional` once the first move goes the drag's one axis.
    /// - Returns: the interaction.
    public static func drag(_ axes: DragAxes, begins: DragStart = .immediately) -> Interaction {
        Interaction(leaves: [], isSet: false, drag: Drag(axes: axes, begins: begins))
    }

    /// The drag letting its view go as a dismissal where the hand took it far enough one of `directions`, or threw
    /// it that far: the view flies on out of the room that holds it, and `onDismissed` is told once it has left.
    /// A view nobody removes then comes back to its place.
    ///
    ///     Card(card)
    ///         .interaction(.drag(.vertical, begins: .directional).dismissal(directions: .up, threshold: 120))
    ///         .onDismissed { _ in cards.removeAll { $0.id == card.id } }
    ///
    /// - Parameters:
    ///   - directions: which ways a throw dismisses the view; at least one.
    ///   - threshold: how far the view must go that way, or be thrown, in points; above nought.
    ///   - motion: the law a throw is carried by, and the pace of the view's way out; a spring unless said.
    /// - Returns: the interaction; one saying no drag, no direction or no such threshold refuses the dismissal.
    public func dismissal(directions: SwipeDirections, threshold: Double, motion: Motion = .spring()) -> Interaction {
        var copy = self
        guard copy.drag != nil, leaves.isEmpty, press == nil else {
            copy.refused.append("A dismissal is said of a drag - `.drag(...).dismissal(...)` - and was said of "
                + "something else. Its view is dismissed no way.")
            return copy
        }
        guard !directions.isEmpty, threshold.isFinite, threshold > 0 else {
            copy.refused.append("A dismissal names at least one direction and a threshold above nought: "
                + "\(directions) and \(threshold) were said. Its view is dismissed no way.")
            return copy
        }
        copy.drag?.dismissal = HostDismissal(directions: directions, threshold: threshold, motion: motion)
        return copy
    }

    /// Takes the press and the drag of `interactions`: one of each stands, and two of either are refused together -
    /// neither is the one the author meant.
    mutating func takeLocal(of interactions: [Interaction]) {
        let (presses, drags) = (interactions.compactMap(\.press), interactions.compactMap(\.drag))
        press = presses.count == 1 ? presses[0] : nil
        drag = drags.count == 1 ? drags[0] : nil
        if presses.count > 1 { refused.append("An interaction says a press twice. Its view answers no press.") }
        if drags.count > 1 { refused.append("An interaction says a drag twice. The hand takes its view no way.") }
    }

    /// The press and the drag that stand on a view, and what is wrong with the one that does not, as the author
    /// is told it.
    func standingLocal() -> (press: Press?, drag: Drag?, complaints: [String]) {
        guard let drag, drag.begins == .directional, drag.axes == .both else { return (press, drag, []) }

        return (press, nil, [
            "An interaction's directional drag was given both axes, and takes the view by the one its first move "
                + "goes: say `.horizontal` or `.vertical`. The hand takes the view no way.",
        ])
    }
}
