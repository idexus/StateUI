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
        Specimens.wearing(VisualElementContract.self).flatMap { element -> [ConformanceCase] in
            let held: [ConformanceCase] = [
                shown(element), opacity(element), enabled(element), sized(element), bounded(element),
                reachable(element), framed(element), styled(element), layered(element),
                headed(element),
                Aspects.holds(VisualElementContract.accessibilityLabel, on: element, "Confirm", then: "Save"),
                Aspects.holds(VisualElementContract.accessibilityHint, on: element, "Saves the form", then: "Saves it all"),
                Aspects.holds(VisualElementContract.accessibilityRole, on: element, .button, then: .adjustable),
                Aspects.holds(VisualElementContract.accessibilityValue, on: element, "3 of 5", then: "4 of 5"),
                readerActed(element), readerStepped(element),
                Aspects.holds(VisualElementContract.tooltip, on: element, "Saves the draft", then: "Saves every draft"),
                Aspects.holds(VisualElementContract.accessibilityHeading, on: element, .h2, then: .h3),
                Aspects.holds(VisualElementContract.isAccessibilityHidden, on: element, false, then: true, with: named),
                Aspects.holds(
                    VisualElementContract.hidesChildrenFromAccessibility, on: element, false, then: true, with: named),
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
            ]
            let answered: [ConformanceCase] = answeringByGestures.contains(element) ? [answering(element)] : []
            let laidOut: [ConformanceCase] = layouts.contains(element)
                ? [disablingItsBranch(element), directingItsChild(element)] : []
            let boxed: [ConformanceCase] = boxes.contains(element) ? [blurredOrGlass(element)] : []
            let material: [ConformanceCase] = element == "VStack" ? [followsAMaterial] : []
            return held + answered + laidOut + boxed + boxFilled(element) + material
        }
    }

    /// The views whose only answer to the hand is the View tier's gestures: what disabling one stops is what it hears
    /// of them.
    static let answeringByGestures: Set<String> = [
        "Spinner", "Capsule", "Ellipse", "Fill", "Grid", "HStack", "Image", "Line", "Path", "Polygon",
        "Polyline", "ProgressBar", "Rectangle", "Space", "Text", "VStack", "ZStack",
    ]

    /// The layouts, a space and a fill drawing their own box, whose background may be a blur or glass.
    static let boxes: Set<String> = ["Fill", "Grid", "HStack", "LayoutEngine", "Space", "VStack", "ZStack"]

    /// A box's background is the blur the tree gives it and then the glass it changes it to - or what stands in for
    /// the glass, the blur as clear as it is, whose color a host that blurs nothing paints.
    @MainActor
    static func blurredOrGlass(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).background.showsABlurOrGlassOrWhatStandsInForIt", proves: [
            Covered(VisualElementContract.background, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let value = State(wrappedValue: Material.blur(.thin))
            let changed = Material.glass(.clear)
            s.start {
                Specimens.page(element, Words.on(element) + [Write(VisualElementContract.background, value.wrappedValue)],
                               beside: [Button("Change").onClicked { value.wrappedValue = changed }.id("change")])
            }
            let specimen = try s.specimen(element)
            @MainActor func shows(_ wanted: Material) throws -> Bool {
                let held = try s.held(VisualElementContract.background, on: specimen)
                return held == wanted || held == wanted.withoutGlass
            }
            s.expect(try shows(.blur(.thin)), true, "the blur the tree gave")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try shows(changed) }
            s.expect(try shows(changed), true, "the glass the tree changed it to, or the blur standing in for it")
        }
    }

    /// A box's background follows the material state handed to it as `$x` - a material's channel.
    @MainActor
    static var followsAMaterial: ConformanceCase {
        ConformanceCase("VStack.background.followsAMaterialState", proves: [
            Covered(VisualElementContract.background, on: "VStack"),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let (first, second) = (Material.color(Color(hex: 0x0F766E)), Material.color(Color(hex: 0x512BD4)))
            let value = State(wrappedValue: first)
            s.start {
                VStack {
                    Button("Change").onClicked { value.wrappedValue = second }.id("change")
                    VStack { Text("Box") }.background(value.projectedValue).id("specimen")
                }
            }
            let specimen = try s.element("specimen")
            try s.settle { try s.held(VisualElementContract.background, on: specimen) == first }
            s.expect(try s.held(VisualElementContract.background, on: specimen), first, "the material the state holds")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(VisualElementContract.background, on: specimen) == second }
            s.expect(try s.held(VisualElementContract.background, on: specimen), second, "the material written into it")
        }
    }

    /// A screen reader performs the element's actions by their words, each reaching the element as the one it is.
    @MainActor
    static func readerActed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).performsAScreenReadersActions", proves: [
            Covered(VisualElementContract.accessibilityActionPerformed, on: element),
            Covered(VisualElementContract.accessibilityActions, on: element),
        ]) { s in
            let performed = Received<String>()
            s.start {
                Specimens.view(element, [
                    Write(VisualElementContract.accessibilityActions, ["Archive", "Delete"]),
                    Hear(VisualElementContract.accessibilityActionPerformed) { performed.values.append($0) },
                ])
            }
            let view = try s.element("specimen")

            try s.perform(.performAccessibilityAction("Delete"), on: view)
            s.settle { performed.values == ["Delete"] }
            s.expect(performed.values, ["Delete"], "the action performed")
            try s.perform(.performAccessibilityAction("Archive"), on: view)
            s.settle { performed.values == ["Delete", "Archive"] }
            s.expect(performed.values, ["Delete", "Archive"], "the other")
        }
    }

    /// A screen reader steps the element up and down where it says it is adjustable.
    @MainActor
    static func readerStepped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isSteppedByAScreenReader", proves: [
            Covered(VisualElementContract.accessibilityAdjusted, on: element),
        ], needs: [Covered(VisualElementContract.accessibilityRole, on: element)]) { s in
            let stepped = Received<AccessibilityAdjustment>()
            s.start {
                Specimens.view(element, [
                    Write(VisualElementContract.accessibilityRole, .adjustable),
                    Hear(VisualElementContract.accessibilityAdjusted) { stepped.values.append($0) },
                ])
            }
            let view = try s.element("specimen")

            try s.perform(.adjust(.increment), on: view)
            s.settle { stepped.values == [.increment] }
            s.expect(stepped.values, [.increment], "a step up")
            try s.perform(.adjust(.decrement), on: view)
            s.settle { stepped.values == [.increment, .decrement] }
            s.expect(stepped.values, [.increment, .decrement], "and a step down")
        }
    }

    /// The views holding others: their `isEnabled` is their branch's, and they lay their child out in their direction.
    static let layouts: Set<String> = ["Grid", "HStack", "LayoutEngine", "ScrollView", "VStack", "ZStack"]

    /// A view is shown or not as the tree says, and hides when the tree says so.
    @MainActor
    static func shown(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isShownAsTheTreeSays", proves: [
            Covered(VisualElementContract.isVisible, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
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

    /// A view stands in front of a sibling it overlaps or behind it as its `zIndex` says, whatever the order they
    /// were written in - as its toolkit draws them.
    @MainActor
    static func layered(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsInTheDepthTheTreeSays", proves: [
            Covered(VisualElementContract.zIndex, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let depth = State(wrappedValue: 1)
            s.start(reducesMotion: true) {
                VStack {
                    ZStack {
                        Specimens.view(element, [Write(VisualElementContract.zIndex, depth.wrappedValue)])
                        Rectangle()
                            .fill(.blue)
                            .id("cover")
                    }
                    .width(120).height(80).id("layers")
                    Button("Lower").onClicked { depth.wrappedValue = -1 }.id("change")
                }
            }
            let (layers, specimen, cover) = (try s.element("layers"), try s.specimen(element), try s.element("cover"))
            s.expect(try s.drawingOrder(of: layers), [cover.id, specimen.id], "in front of the box written after it")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.drawingOrder(of: layers) == [specimen.id, cover.id] }
            s.expect(try s.drawingOrder(of: layers), [specimen.id, cover.id], "behind it, lowered")
        }
    }

    /// A view is as opaque as the tree says, and changes as the tree does.
    @MainActor
    static func opacity(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isAsOpaqueAsTheTreeSays", proves: [
            Covered(VisualElementContract.opacity, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
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

    /// A view is a heading to assistive technology where the tree makes it one, whatever level it says, and is none
    /// where the tree says none.
    @MainActor
    static func headed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isAHeadingWhereTheTreeSays", proves: [
            Covered(VisualElementContract.accessibilityHeading, on: element),
        ]) { s in
            s.start {
                VStack {
                    Specimens.view(element, [Write(VisualElementContract.accessibilityHeading, .h2)], id: "heading")
                    Specimens.view(element, [Write(VisualElementContract.accessibilityHeading, .none)], id: "plain")
                }
            }
            s.expect(try s.isHeading(s.element("heading")), true, "made a heading")
            s.expect(try s.isHeading(s.element("plain")), false, "made plain")
        }
    }

    /// A view the tree disables answers no tap, and answers once the tree enables it.
    @MainActor
    static func answering(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).answersNoTapWhileDisabled", proves: [
            Covered(VisualElementContract.isEnabled, on: element),
        ], needs: [Covered(ButtonContract.clicked), Covered(ViewContract.tapped, on: element)]) { s in
            let enabled = State(wrappedValue: false)
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(VisualElementContract.isEnabled, enabled.wrappedValue),
                        HearDone(ViewContract.tapped) { heard.values.append("tapped") },
                    ])
                    Button("Enable").onClicked { enabled.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")

            try s.perform(.tap(count: 1), on: view)
            s.turn()
            s.expect(heard.values, [], "disabled, it answers no tap")

            try s.perform(.activate, on: s.element("change"))
            try s.settle {
                if heard.values.isEmpty { try s.perform(.tap(count: 1), on: view) }
                return !heard.values.isEmpty
            }
            s.expect(heard.values, ["tapped"], "enabled, it answers")
        }
    }

    /// A control in a layout the tree disables takes no input, and takes it again as the layout is enabled.
    @MainActor
    static func disablingItsBranch(_ layout: String) -> ConformanceCase {
        ConformanceCase("\(layout).disablesTheControlsInIt", proves: [
            Covered(VisualElementContract.isEnabled, on: layout),
        ], needs: [Covered(ButtonContract.clicked), Covered(VisualElementContract.isEnabled, on: "Button")]) { s in
            let enabled = State(wrappedValue: false)
            s.start {
                VStack {
                    Specimens.holding(layout, Button("Inside").id("inside"), [
                        Write(VisualElementContract.isEnabled, enabled.wrappedValue),
                        Write(VisualElementContract.height, 60),
                    ])
                    Button("Enable").onClicked { enabled.wrappedValue = true }.id("change")
                }
            }
            let inside = try s.element("inside")
            s.expect(try s.held(VisualElementContract.isEnabled, on: inside), false, "disabled with its layout")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(VisualElementContract.isEnabled, on: inside) == true }
            s.expect(try s.held(VisualElementContract.isEnabled, on: inside), true, "enabled with it")
        }
    }

    /// A layout lays its child out in its direction, and again as the direction turns: a child at its start stands
    /// at its left, then at its right.
    @MainActor
    static func directingItsChild(_ layout: String) -> ConformanceCase {
        ConformanceCase("\(layout).placesItsChildInItsDirection", proves: [
            Covered(VisualElementContract.layoutDirection, on: layout),
        ], needs: [Covered(ButtonContract.clicked), Covered(VisualElementContract.frame, on: "Rectangle")]) { s in
            let room = State(wrappedValue: Rect(x: -1, y: 0, width: 0, height: 0))
            let direction = State(wrappedValue: LayoutDirection.leftToRight)
            s.start {
                VStack {
                    Specimens.holding(
                        layout,
                        Rectangle()
                            .fill(.red)
                            .width(60)
                            .height(30)
                            .horizontalAlignment(.start)
                            .verticalAlignment(.start)
                            .frame(room.projectedValue),
                        [
                            Write(VisualElementContract.layoutDirection, direction.wrappedValue),
                            Write(VisualElementContract.width, 200), Write(VisualElementContract.height, 100),
                        ])
                    Button("Turn").onClicked { direction.wrappedValue = .rightToLeft }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { room.wrappedValue.x == 0 }
            s.expect(room.wrappedValue, Rect(x: 0, y: 0, width: 60, height: 30), "left to right, at its left")
            try s.perform(.activate, on: s.element("change"))
            s.settle { room.wrappedValue.x == 140 }
            s.expect(room.wrappedValue, Rect(x: 140, y: 0, width: 60, height: 30), "right to left, at its right")
        }
    }

    /// A view takes input or not as the tree says: made taking none, then taking it, then stopping again.
    @MainActor
    static func enabled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).takesInputAsTheTreeSays", proves: [
            Covered(VisualElementContract.isEnabled, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let enabled = State(wrappedValue: false)
            s.start(reducesMotion: true) {
                Specimens.page(element, [Write(VisualElementContract.isEnabled, enabled.wrappedValue)], beside: [
                    Button("Change").onClicked { enabled.wrappedValue.toggle() }.id("change"),
                ])
            }
            let view = try s.specimen(element)
            s.expect(try s.held(VisualElementContract.isEnabled, on: view), false, "made taking no input")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(VisualElementContract.isEnabled, on: view) == true }
            s.expect(try s.held(VisualElementContract.isEnabled, on: view), true)

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(VisualElementContract.isEnabled, on: view) == false }
            s.expect(try s.held(VisualElementContract.isEnabled, on: view), false)
        }
    }

    /// A drawn box's fill, where `element` is one (`BorderElementTests.drawnBoxes`).
    @MainActor
    static func boxFilled(_ element: String) -> [ConformanceCase] {
        BorderElementTests.drawnBoxes.contains(element) ? [BorderElementTests.boxFilled(element)] : []
    }

    /// A view stands at the size the tree states.
    @MainActor
    static func sized(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsAtItsStatedSize", proves: [
            Covered(VisualElementContract.width, on: element), Covered(VisualElementContract.height, on: element),
        ], needs: [Covered(ViewContract.frameChanged, on: element)]) { s in
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
    @MainActor
    static func bounded(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isHeldToTheBoundsTheTreeSets", proves: [
            Covered(VisualElementContract.maximumWidth, on: element),
            Covered(VisualElementContract.minimumWidth, on: element),
            Covered(VisualElementContract.maximumHeight, on: element),
            Covered(VisualElementContract.minimumHeight, on: element),
        ], needs: [Covered(ViewContract.frameChanged, on: element)]) { s in
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
    @MainActor
    static var named: [any Worn] {
        [Write(VisualElementContract.accessibilityLabel, "Named")]
    }

    /// What a pivot is seen by: a view turned, with a size to take a part of.
    @MainActor
    static var turned: [any Worn] {
        [Write(VisualElementContract.rotation, 30), Write(VisualElementContract.width, 40),
         Write(VisualElementContract.height, 20)]
    }

    /// A press reaches a view, and goes through it to what is beneath once the tree says it ignores input.
    @MainActor
    static func reachable(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPressReachesItUnlessItIgnoresInput", proves: [
            Covered(VisualElementContract.ignoresInput, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let ignores = State(wrappedValue: false)
            s.start {
                VStack {
                    Specimens.view(element, painted(element) + [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(VisualElementContract.background, Material.color(.red)),
                        Write(VisualElementContract.ignoresInput, ignores.wrappedValue),
                    ])
                    Button("Ignore").onClicked { ignores.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let view = try s.element("specimen")
            try s.settle { try s.reaches(view, at: Point(40, 20)) }
            s.expect(try s.reaches(view, at: Point(40, 20)), true, "a press reaches it")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.reaches(view, at: Point(40, 20)) == false }
            s.expect(try s.reaches(view, at: Point(40, 20)), false, "and goes through it once it ignores input")
        }
    }

    /// What `element` paints at the middle of a box of 80 by 40, where a press is read: a host may hand a view
    /// only the presses on what it paints - a figure filled across it, a line through it, a picture.
    @MainActor
    static func painted(_ element: String) -> [any Worn] {
        let red = Brush.solidColor(.red)
        let figure = [Point(20, 5), Point(60, 5), Point(60, 35), Point(20, 35)]
        let atItsSize = Write(ShapeContract.contentMode, ContentMode.center)
        return switch element {
        case "Rectangle", "Ellipse", "Capsule": [Write(FilledShapeContract.fill, red)]
        case "Line": [
            Write(LineContract.x1, 0), Write(LineContract.y1, 20), Write(LineContract.x2, 80), Write(LineContract.y2, 20),
            Write(ShapeContract.stroke, red), Write(ShapeContract.lineWidth, 8),
        ]
        case "Polygon": [Write(PolygonContract.points, figure), Write(FilledShapeContract.fill, red), atItsSize]
        case "Polyline": [Write(PolylineContract.points, figure + [figure[0]]), Write(FilledShapeContract.fill, red), atItsSize]
        case "Path": [Write(PathContract.data, "M 20 5 L 60 5 L 60 35 L 20 35 Z"), Write(FilledShapeContract.fill, red), atItsSize]
        case "Image": [Write(ImageContract.source, ImageSource("test_dot.png"))]
        default: []
        }
    }

    /// A view's frame lands in the state the tree gives it, and again as the tree widens it.
    @MainActor
    static func framed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).itsFrameLandsInItsState", proves: [
            Covered(VisualElementContract.frame, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
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

    /// A view naming a style takes the values the style gives it.
    @MainActor
    static func styled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).takesTheValuesOfTheStyleItNames", proves: [
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
