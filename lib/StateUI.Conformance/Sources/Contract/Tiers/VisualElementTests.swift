// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `VisualElementContract` on a host: what every view is as the tree says, the tree changing it - shown or not, how
/// opaque, taking input or not, its size and the bounds it is held to, what assistive technology meets of it, its
/// background, its direction, how it is moved, turned and scaled, where it stands in depth, a press let through it,
/// the frame it reports into a state, the keyboard's coming and going, and the style it names - each case made for
/// every element wearing the tier.
@_spi(Host) public enum VisualElementTests: ConformanceFamily {
    public static let name = "VisualElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(VisualElementContract.self).flatMap { element in
            [
                shown(element), opacity(element), enabled(element), sized(element), bounded(element),
                reachable(element), framed(element), focused(element), styled(element),
                Aspects.holds(VisualElementContract.accessibilityLabel, on: element, "Confirm", then: "Save"),
                Aspects.holds(VisualElementContract.accessibilityHint, on: element, "Saves the form", then: "Saves it all"),
                Aspects.holds(VisualElementContract.accessibilityHeadingLevel, on: element, .level2, then: .level3),
                Aspects.holds(VisualElementContract.isAccessibilityHidden, on: element, false, then: true, with: named),
                Aspects.holds(
                    VisualElementContract.automationExcludedWithChildren, on: element, false, then: true, with: named),
                Aspects.holds(VisualElementContract.background, on: element, .color(.red), then: .color(.blue)),
                Aspects.holds(VisualElementContract.layoutDirection, on: element, .leftToRight, then: .rightToLeft),
                Aspects.holds(VisualElementContract.pivotX, on: element, 0.5, then: 0, with: turned),
                Aspects.holds(VisualElementContract.pivotY, on: element, 0.5, then: 1, with: turned),
                Aspects.holds(VisualElementContract.rotation, on: element, 0, then: 30),
                Aspects.holds(VisualElementContract.rotationX, on: element, 0, then: 20),
                Aspects.holds(VisualElementContract.rotationY, on: element, 0, then: 20),
                Aspects.holds(VisualElementContract.scale, on: element, 1, then: 2),
                Aspects.holds(VisualElementContract.scaleX, on: element, 1, then: 1.5),
                Aspects.holds(VisualElementContract.scaleY, on: element, 1, then: 0.5),
                Aspects.holds(VisualElementContract.translationX, on: element, 0, then: 10),
                Aspects.holds(VisualElementContract.translationY, on: element, 0, then: -10),
                Aspects.holds(VisualElementContract.zIndex, on: element, 0, then: 3),
            ]
        }
    }

    /// A view is shown or not as the tree says, and hides when the tree says so.
    static func shown(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isShownAsTheTreeSays", covers: [
            Covered(VisualElementContract.isVisible, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let shown = State(wrappedValue: true)
            s.start(reducesMotion: true) {
                Specimens.page(element, [Write(VisualElementContract.isVisible, shown.wrappedValue)], beside: [
                    Button("Hide").onClicked { shown.wrappedValue = false }.id("change"),
                ])
            }
            let view = try s.specimen(element)
            s.expect(try s.held(VisualElementContract.isVisible, on: view), true)

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(VisualElementContract.isVisible, on: view) == false }
            s.expect(try s.held(VisualElementContract.isVisible, on: view), false)
        }
    }

    /// A view is as opaque as the tree says, and changes as the tree does.
    static func opacity(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isAsOpaqueAsTheTreeSays", covers: [
            Covered(VisualElementContract.opacity, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let opacity = State(wrappedValue: 0.5)
            s.start(reducesMotion: true) {
                Specimens.page(element, [Write(VisualElementContract.opacity, opacity.wrappedValue)], beside: [
                    Button("Fade").onClicked { opacity.wrappedValue = 0.25 }.id("change"),
                ])
            }
            let view = try s.specimen(element)
            s.expect(try s.held(VisualElementContract.opacity, on: view), 0.5, within: 0.01)

            try s.perform(.activate, on: s.element("change"))
            try s.settle { abs((try s.held(VisualElementContract.opacity, on: view) ?? 0) - 0.25) < 0.01 }
            s.expect(try s.held(VisualElementContract.opacity, on: view), 0.25, within: 0.01)
        }
    }

    /// A view takes input or not as the tree says, and stops when the tree says so.
    static func enabled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).takesInputAsTheTreeSays", covers: [
            Covered(VisualElementContract.isEnabled, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let enabled = State(wrappedValue: true)
            s.start(reducesMotion: true) {
                Specimens.page(element, [Write(VisualElementContract.isEnabled, enabled.wrappedValue)], beside: [
                    Button("Disable").onClicked { enabled.wrappedValue = false }.id("change"),
                ])
            }
            let view = try s.specimen(element)
            s.expect(try s.held(VisualElementContract.isEnabled, on: view), true)

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(VisualElementContract.isEnabled, on: view) == false }
            s.expect(try s.held(VisualElementContract.isEnabled, on: view), false)
        }
    }

    /// A view stands at the size the tree states.
    static func sized(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsAtItsStatedSize", covers: [
            Covered(VisualElementContract.width, on: element), Covered(VisualElementContract.height, on: element),
            Covered(ViewContract.frameChanged, on: element),
        ]) { s in
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    ViewTests.reporting(element, frames, [
                        Write(VisualElementContract.width, 120), Write(VisualElementContract.height, 40),
                    ])
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { frames.values.last.map(FrameReport.place) == [0, 0, 120, 40] }
            s.expect(frames.values.last.map(FrameReport.place), [0, 0, 120, 40], "x, y, width, height in its parent")
        }
    }

    /// A stated size is held to the bounds the tree sets it.
    static func bounded(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isHeldToTheBoundsTheTreeSets", covers: [
            Covered(VisualElementContract.maximumWidth, on: element),
            Covered(VisualElementContract.minimumWidth, on: element),
            Covered(VisualElementContract.maximumHeight, on: element),
            Covered(VisualElementContract.minimumHeight, on: element), Covered(ViewContract.frameChanged, on: element),
        ]) { s in
            let narrowed = Received<[Double]>()
            let widened = Received<[Double]>()
            s.start {
                VStack {
                    ViewTests.reporting(element, narrowed, [
                        Write(VisualElementContract.width, 120), Write(VisualElementContract.maximumWidth, 60),
                        Write(VisualElementContract.height, 20), Write(VisualElementContract.minimumHeight, 50),
                    ], id: "narrowed")
                    ViewTests.reporting(element, widened, [
                        Write(VisualElementContract.width, 20), Write(VisualElementContract.minimumWidth, 50),
                        Write(VisualElementContract.height, 120), Write(VisualElementContract.maximumHeight, 60),
                    ], id: "widened")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle {
                narrowed.values.last.map(FrameReport.size) == [60, 50] && widened.values.last.map(FrameReport.size) == [50, 60]
            }
            s.expect(narrowed.values.last.map(FrameReport.size), [60, 50], "no wider than its maximum, no lower than its minimum")
            s.expect(widened.values.last.map(FrameReport.size), [50, 60], "no narrower than its minimum, no taller than its maximum")
        }
    }

    /// A view with something to say, which assistive technology meets unless the view is left out: a decoration
    /// with no name is met by no one either way.
    static var named: [any Worn] {
        [Write(VisualElementContract.accessibilityLabel, "Named")]
    }

    /// What a pivot is seen by: a view turned, with a size to take a part of.
    static var turned: [any Worn] {
        [Write(VisualElementContract.rotation, 30), Write(VisualElementContract.width, 40),
         Write(VisualElementContract.height, 20)]
    }

    /// A press reaches a view, and goes through it to what is beneath once the tree says it ignores input.
    static func reachable(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPressReachesItUnlessItIgnoresInput", covers: [
            Covered(VisualElementContract.ignoresInput, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let ignores = State(wrappedValue: false)
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(VisualElementContract.background, Background.color(.red)),
                        Write(VisualElementContract.ignoresInput, ignores.wrappedValue),
                    ])
                    Button("Ignore").onClicked { ignores.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let view = try s.element("specimen")
            s.expect(try s.reaches(view, at: Point(40, 20)), true, "a press reaches it")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.reaches(view, at: Point(40, 20)) == false }
            s.expect(try s.reaches(view, at: Point(40, 20)), false, "and goes through it once it ignores input")
        }
    }

    /// A view's frame lands in the state the tree gives it, and again where the tree moves it.
    static func framed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).itsFrameLandsInItsState", covers: [
            Covered(VisualElementContract.frame, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let room = State(wrappedValue: Rect(x: 0, y: 0, width: 0, height: 0))
            let wide = State(wrappedValue: false)
            s.start {
                VStack {
                    Opened.framed(Specimens.view(element, [
                        Write(VisualElementContract.width, wide.wrappedValue ? 90 : 60), Write(VisualElementContract.height, 30),
                        Write(ViewContract.horizontalAlignment, Alignment.start),
                    ]), into: room.projectedValue)
                    Button("Widen").onClicked { wide.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { room.wrappedValue.width == 60 }
            s.expect(room.wrappedValue, Rect(x: 0, y: 0, width: 60, height: 30))
            try s.perform(.activate, on: s.element("change"))
            s.settle { room.wrappedValue.width == 90 }
            s.expect(room.wrappedValue, Rect(x: 0, y: 0, width: 90, height: 30), "again where the tree moved it")
        }
    }

    /// The keyboard put on a view that takes it is heard coming, and heard going as it is taken off; a view that
    /// refuses it says so and hears nothing.
    static func focused(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theKeyboardComingAndGoingIsHeard", covers: [
            Covered(VisualElementContract.focus, on: element), Covered(VisualElementContract.unfocus, on: element),
            Covered(VisualElementContract.isFocusedChanged, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let aim = FocusAim()
            let heard = Received<Bool>()
            let took = Received<Bool>()
            s.start {
                VStack {
                    Opened.aimed(Specimens.view(element, [
                        Hear(VisualElementContract.isFocusedChanged) { heard.values.append($0) },
                    ]), by: aim)
                    Button("Focus").onClicked { took.values.append(try await aim.focus()) }.id("focus")
                    Button("Unfocus").onClicked { try await aim.unfocus() }.id("unfocus")
                }
            }
            let view = try s.element("specimen")

            try s.perform(.activate, on: s.element("focus"))
            s.settle { !took.values.isEmpty && (took.values == [false] || heard.values == [true]) }
            guard took.values == [true] else {
                s.expect(heard.values, [], "a view that refused the keyboard hears nothing")
                return s.expect(try s.focused(view), false)
            }
            s.expect(heard.values, [true], "the keyboard coming heard")
            s.expect(try s.focused(view), true)

            try s.perform(.activate, on: s.element("unfocus"))
            s.settle { heard.values == [true, false] }
            s.expect(heard.values, [true, false], "and its going")
            s.expect(try s.focused(view), false)
        }
    }

    /// A view naming a style takes the values the style gives it.
    static func styled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).takesTheValuesOfTheStyleItNames", covers: [
            Covered(VisualElementContract.style, on: element),
        ]) { s in
            s.start {
                StyledPage(inner: Specimens.view(element, [Write(VisualElementContract.style, Name(Styled.key(element)))]))
            }
            let view = try s.element("specimen")

            try s.settle { abs((try s.held(VisualElementContract.opacity, on: view) ?? 1) - 0.5) < 0.01 }
            s.expect(try s.held(VisualElementContract.opacity, on: view), 0.5, within: 0.01, "the style's opacity")
        }
    }
}
