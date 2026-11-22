// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `LayoutContract` on a host: a layout cuts what it holds to its outline where it clips and not otherwise, lets a
/// press through where nothing it holds stands where it says so, and standing a page whole runs under what stands over
/// the page where it ignores the safe area - the keyboard among it - each case made for every layout.
@_spi(Host) public enum LayoutTests: ConformanceFamily {
    public static let name = "Layout"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(LayoutContract.self).flatMap { element in
            [
                clipped(element), throughIt(element), underTheBars(element), clearOfTheKeyboard(element),
                Aspects.holds(LayoutContract.clipsContent, on: element, false, then: true),
                Aspects.holds(LayoutContract.letsInputThrough, on: element, false, then: true),
                bodied(element), unbodied(element), scoped(element),
            ] + (SettingOut.kinds.contains(element) ? [drawnInFront(element)] : [])
                + (SettingOut.keeping.contains(element) ? [keptForItsPartner(element), eachKeyOwn(element)] : [])
        }
    }

    /// What a layout holds drawn past its edge - moved there, which its arithmetic does not see - shows until the tree
    /// says it clips, and then shows no more.
    @MainActor
    static func clipped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).cutsWhatItHoldsToItsOutlineWhereItClips", proves: [
            Covered(LayoutContract.clipsContent, on: element),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let clips = State(wrappedValue: false)
            s.start {
                VStack {
                    ZStack {
                        Holding.layout(element, clips: clips.wrappedValue, width: 40, height: 40) {
                            Rectangle()
                                .fill(.red)
                                .width(20)
                                .height(20)
                                .horizontalAlignment(.start)
                                .verticalAlignment(.start)
                                .translationX(30).translationY(30)
                        }
                    }
                    .width(100).height(100).id("room")
                    Button("Clip").onClicked { clips.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let room = try s.element("room")
            try s.settle { try s.shows(.red, on: room, at: Point(x: 45, y: 45)) }
            s.expect(try s.color(of: room, at: Point(x: 45, y: 45)), shows: .red, "past its edge, shown")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: room, at: Point(x: 45, y: 45)) == nil }
            s.expect(try s.color(of: room, at: Point(x: 45, y: 45)), nil, "cut once it clips")
            s.expect(try s.color(of: room, at: Point(x: 35, y: 35)), shows: .red, "inside, still shown")
        }
    }

    /// A press on a layout where it holds nothing reaches what stands beneath it once the tree lets input through.
    @MainActor
    static func throughIt(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).letsAPressThroughWhereItHoldsNothing", proves: [
            Covered(LayoutContract.letsInputThrough, on: element),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let through = State(wrappedValue: false)
            s.start {
                VStack {
                    ZStack {
                        Rectangle()
                            .fill(.blue)
                            .id("beneath")
                        Holding.layout(element, through: through.wrappedValue) {
                            Rectangle()
                                .fill(.red)
                                .width(20)
                                .height(20)
                                .horizontalAlignment(.start)
                                .verticalAlignment(.start)
                        }
                    }
                    .width(100).height(100)
                    Button("Through").onClicked { through.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let beneath = try s.element("beneath")
            s.expect(try s.reaches(beneath, at: Point(x: 60, y: 60)), false, "the layout over it takes the press")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.reaches(beneath, at: Point(x: 60, y: 60)) }
            s.expect(try s.reaches(beneath, at: Point(x: 60, y: 60)), true, "let through where it holds nothing")
        }
    }
}

extension LayoutTests {
    /// A layout standing a page whole reaches out under what stands over the page - a window's bar, a status bar, a
    /// home indicator - where the tree says it ignores the safe area, its room the larger by it and
    /// holding the one it stood in, and stands back clear of it told to ignore none.
    @MainActor
    static func underTheBars(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).runsUnderWhatStandsOverItsPageWhereItIgnoresTheSafeArea", proves: [
            Covered(LayoutContract.ignoresSafeArea, on: element),
        ]) { s in
            let edges = State<SafeAreaEdges>(wrappedValue: [])
            let frames = Received<[Double]>()
            s.start {
                Holding.layout(element, ignores: edges.wrappedValue, heard: { frames.values.append($0) }) {
                    Rectangle()
                        .fill(.red)
                }
                .pageTitle("Under")
            }

            // A phone's bars, where the host's test window stands under none.
            s.standUnderSystemBars(top: 24, bottom: 48)

            // Its room in the window: top, bottom, left, right.
            let room = { () -> [Double]? in
                guard let frame = frames.values.last else { return nil }
                let (corner, size) = (FrameReport.inWindow(frame), FrameReport.size(frame))
                return [corner[1], corner[1] + size[1], corner[0], corner[0] + size[0]]
            }
            s.settle { room() != nil }
            let clear = room() ?? []

            edges.wrappedValue = .all
            s.settle { room() != nil && room() != clear }
            let under = room() ?? []
            let holds = under.count == 4 && clear.count == 4 && under[0] <= clear[0] && under[1] >= clear[1]
                && under[2] <= clear[2] && under[3] >= clear[3]
            s.expect(holds && under != clear, true, "under what stands over it: \(under) around \(clear)")

            edges.wrappedValue = []
            s.settle { room() == clear }
            s.expect(room(), clear, "and clear of it again")
        }
    }
}

extension LayoutTests {
    /// A layout standing a page whole stands clear of the keyboard docked at the window's foot - its foot as far above
    /// the window's as the keyboard is tall - runs under it where the tree says it ignores the bottom of the safe
    /// area, and stands as it stood once the keyboard goes.
    @MainActor
    static func clearOfTheKeyboard(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsClearOfTheKeyboardOrUnderItWhereItIgnoresTheSafeArea", proves: [
            Covered(LayoutContract.ignoresSafeArea, on: element),
        ]) { s in
            let edges = State<SafeAreaEdges>(wrappedValue: [])
            let frames = Received<[Double]>()
            s.start {
                Holding.layout(element, ignores: edges.wrappedValue, heard: { frames.values.append($0) }) {
                    Rectangle()
                        .fill(.red)
                }
            }

            // The foot of its room in the window.
            let foot = { () -> Double? in
                frames.values.last.map { FrameReport.inWindow($0)[1] + FrameReport.size($0)[1] }
            }
            s.settle { foot() != nil }
            let alone = foot() ?? 0

            let keyboard = 300.0
            try s.standUnderKeyboard(height: keyboard)
            s.settle { (foot() ?? alone) < alone }
            let clear = foot() ?? alone

            edges.wrappedValue = [.bottom]
            s.settle { (foot() ?? clear) > clear }
            let under = foot() ?? clear
            s.expect(abs(under - clear - keyboard) < 1, true, "clear of the keyboard by its height, \(under - clear) under it")

            edges.wrappedValue = []
            s.settle { foot() == clear }
            s.expect(foot(), clear, "and clear of it again")

            try s.standUnderKeyboard(height: 0)
            s.settle { foot() == alone }
            s.expect(foot(), alone, "and where it stood once the keyboard goes")
        }
    }
}

extension LayoutTests {
    /// A child a change of its layout moves comes onto its new place as the layout's bodies say: on their spring -
    /// past its place, where the spring is damped below one - though the layout's own motion moves nothing.
    @MainActor
    static func bodied(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aChildComesOntoItsPlaceAsItsBodiesSay", proves: [
            Covered(LayoutContract.layoutBodies, on: element),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let clock = TestClock()
            let far = State(wrappedValue: false)
            let bodies = LayoutBody.onChange(response: .milliseconds(400), damping: 0.5)
            s.start(clock: clock) {
                VStack {
                    Shifting(element: element, bodies: bodies, law: .none, far: far.projectedValue)
                    Button("Move").onClicked { far.wrappedValue = true }.id("move")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            while clock.now < 200 {
                clock.now += 16
                s.frame()
            }
            let start = try s.place(of: s.element("specimen"))
            let moved = { () -> Double in
                guard let place = try? s.place(of: s.element("specimen")) else { return .nan }
                return max(abs(place.x - start.x), abs(place.y - start.y))
            }

            try s.perform(.activate, on: s.element("move"))
            var (first, farthest) = (Double.nan, 0.0)
            while clock.now < 3_400 {
                clock.now += 16
                s.frame()
                if first.isNaN, moved() > 0 { first = moved() }
                farthest = max(farthest, moved())
            }
            s.expect(first < 120, true, "on its way, not there at once: \(first)")
            s.expect(farthest > 161, true, "past its place, on its bodies' spring: \(farthest)")
            s.expect(abs(moved() - 160) < 0.5, true, "and onto it: \(moved())")
        }
    }

    /// A layout that is a scope ties the views in it by their keys: one made as its partner is dropped sets out
    /// as large as that one was drawn, and grows to its own size.
    @MainActor
    static func scoped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theViewsInItAreTiedByTheirKeysWhereItIsAScope", proves: [
            Covered(LayoutContract.transitionScope, on: element),
        ], needs: [
            Covered(ViewContract.sharedTransition, on: RectangleContract.self),
            Covered(ViewContract.presentationFrameChanged, on: RectangleContract.self),
            Covered(ViewContract.layoutFrameChanged, on: RectangleContract.self),
            Covered(ClickElementContract.clicked, on: ButtonContract.self),
        ]) { s in
            let clock = TestClock()
            let detailed = State(wrappedValue: false)
            let drawn = Received<[Double]>()
            let placed = Received<[Double]>()
            s.start(clock: clock) {
                VStack {
                    Button("Toggle").onClicked { detailed.wrappedValue.toggle() }.id("toggle")
                    Specimens.holding(
                        element, Swapped(detailed: detailed.projectedValue, drawn: drawn, placed: placed),
                        [Write(LayoutContract.transitionScope, 1)])
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.frames(of: clock, until: 200)

            try s.perform(.activate, on: s.element("toggle"))
            s.settle { !drawn.values.isEmpty }
            let first = drawn.values.first.map(FrameReport.size) ?? []
            s.expect(first.map { $0.rounded() }, [40, 40], "it sets out as large as its partner was drawn")

            // How large the layout makes it is the layout's own: a motion layout gives it its room.
            s.frames(of: clock, until: 1_400)
            s.settle { drawn.values.last.map(FrameReport.size) == placed.values.last.map(FrameReport.size) }
            let rests = drawn.values.last.map(FrameReport.size) ?? []
            s.expect(rests, placed.values.last.map(FrameReport.size) ?? [], "and grows onto the place its layout gives it")
            s.expect(rests == [40, 40], false, "larger than its partner was: \(rests)")
        }
    }

    /// A layout that is a scope draws a view setting out in it from its partner in front of the views beside it
    /// until it lands, and in its own order again then.
    @MainActor
    static func drawnInFront(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aViewSettingOutInItIsDrawnInFrontUntilItLands", proves: [
            Covered(LayoutContract.transitionScope, on: element),
        ], needs: [
            Covered(ViewContract.sharedTransition, on: RectangleContract.self),
            Covered(ClickElementContract.clicked, on: ButtonContract.self),
        ]) { s in
            let clock = TestClock()
            let detailed = State(wrappedValue: false)
            s.start(clock: clock) {
                VStack {
                    Button("Toggle").onClicked { detailed.wrappedValue.toggle() }.id("toggle")
                    SettingOut.layout(element, detailed: detailed.wrappedValue)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.frames(of: clock, until: 200)

            // Read as the patch is laid out, no frame passing first: a toolkit lays a patch out within its frame.
            let layout = try s.element("layout")
            // The one setting out is drawn last; the one leaving, kept for it, stands where it stood.
            let traveling = { () -> [ElementID] in
                let written = layout.children.map(\.id)
                guard written.count == 3 else { return [] }
                return layout.presentedChildren.map(\.id).filter { $0 != written[1] } + [written[1]]
            }
            try s.perform(.activate, on: s.element("toggle"))
            try s.settle { try s.drawingOrder(of: layout) == traveling() }
            s.expect(try s.drawingOrder(of: layout), traveling(), "the one setting out, in front")
            let written = layout.children.map(\.id)

            s.frames(of: clock, until: 1_400)
            try s.settle { try s.drawingOrder(of: layout) == written }
            s.expect(try s.drawingOrder(of: layout), written, "landed: in its layout's order")
        }
    }

    /// A layout that is a scope and keeps a view that leaves keeps the one leaving it for its partner: drawn where
    /// it stood, behind the larger one setting out, until that one lands - and gone then.
    @MainActor
    static func keptForItsPartner(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theViewLeavingItStandsUntilItsPartnerLands", proves: [
            Covered(LayoutContract.transitionScope, on: element),
        ], needs: [
            Covered(ViewContract.sharedTransition, on: RectangleContract.self),
            Covered(ClickElementContract.clicked, on: ButtonContract.self),
        ]) { s in
            let clock = TestClock()
            let detailed = State(wrappedValue: false)
            s.start(clock: clock) {
                VStack {
                    Button("Toggle").onClicked { detailed.wrappedValue.toggle() }.id("toggle")
                    SettingOut.layout(element, detailed: detailed.wrappedValue)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.frames(of: clock, until: 200)

            let layout = try s.element("layout")
            let small = layout.children.map(\.id)
            let standing = { () -> [ElementID] in
                small.count == 3 && layout.children.count == 3 ? small + [layout.children[1].id] : []
            }
            try s.perform(.activate, on: s.element("toggle"))
            try s.settle { try s.drawingOrder(of: layout) == standing() }
            s.expect(try s.drawingOrder(of: layout), standing(), "the small one where it stood, the large in front")
            s.frames(of: clock, until: 400)
            s.expect(try s.drawingOrder(of: layout), standing(), "both drawn on the way")

            s.frames(of: clock, until: 1_400)
            let landed = layout.children.map(\.id)
            try s.settle { try s.drawingOrder(of: layout) == landed }
            s.expect(try s.drawingOrder(of: layout), landed, "landed: the one that left is gone")
        }
    }

    /// A layout that is a scope and keeps a view that leaves pairs each key of one change with its own partner: two
    /// views leaving in a row, a key on each, and two made in a column - each sets out as large as its own partner
    /// was drawn, and grows onto its own place.
    @MainActor
    static func eachKeyOwn(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).eachKeyOfAChangeSetsOutFromItsOwnPartner", proves: [
            Covered(LayoutContract.transitionScope, on: element),
        ], needs: [
            Covered(ViewContract.sharedTransition, on: RectangleContract.self),
            Covered(ViewContract.presentationFrameChanged, on: RectangleContract.self),
            Covered(ClickElementContract.clicked, on: ButtonContract.self),
        ]) { s in
            let clock = TestClock()
            let detailed = State(wrappedValue: false)
            let (first, second) = (Received<[Double]>(), Received<[Double]>())
            s.start(clock: clock) {
                VStack {
                    Button("Toggle").onClicked { detailed.wrappedValue.toggle() }.id("toggle")
                    SettingOut.pairs(element, detailed: detailed.wrappedValue, first: first, second: second)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.frames(of: clock, until: 200)

            try s.perform(.activate, on: s.element("toggle"))
            s.settle { !first.values.isEmpty && !second.values.isEmpty }
            let setOut = [first, second].map { $0.values.first.map(FrameReport.size)?.map { $0.rounded() } ?? [] }
            s.expect(setOut, [[40, 40], [20, 20]], "each sets out as large as its own partner was drawn")

            s.frames(of: clock, until: 1_400)
            let landed = { [first, second].map { $0.values.last.map(FrameReport.size) ?? [] } }
            s.settle { landed() == [[160, 80], [100, 50]] }
            s.expect(landed(), [[160, 80], [100, 50]], "and grows onto its own place")
        }
    }

    /// A layout whose bodies are none stands a child at its new place at once, though the layout's own motion
    /// would take it there in time.
    @MainActor
    static func unbodied(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aLayoutOfNoBodiesStandsItsChildAtOnce", proves: [
            Covered(LayoutContract.layoutBodies, on: element),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let clock = TestClock()
            let far = State(wrappedValue: false)
            s.start(clock: clock) {
                VStack {
                    Shifting(
                        element: element, bodies: LayoutBody.none, law: .eased(.milliseconds(600), curve: .linear),
                        far: far.projectedValue)
                    Button("Move").onClicked { far.wrappedValue = true }.id("move")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            while clock.now < 200 {
                clock.now += 16
                s.frame()
            }
            let start = try s.place(of: s.element("specimen"))

            try s.perform(.activate, on: s.element("move"))
            for _ in 0..<3 {
                clock.now += 16
                s.frame()
            }
            let place = try s.place(of: s.element("specimen"))
            let moved = max(abs(place.x - start.x), abs(place.y - start.y))
            s.expect(abs(moved - 160) < 0.5, true, "at its place within a frame or two: \(moved)")
        }
    }
}

/// A layout of `element`'s kind, two hundred points square, holding one view of forty at its start - or, once `far`,
/// at its end: a change of the layout that moves the view a hundred and sixty points. Its children are the bodies
/// `bodies`, and its own motion is `law`.
private struct Shifting: View {
    let element: String
    let bodies: LayoutBody
    let law: Motion
    let far: Binding<Bool>

    var body: some View {
        let far = far.wrappedValue
        let edge: Alignment = far ? .end : .start
        let dressing = Dressing([
            Write(LayoutContract.layoutBodies, bodies), Write(VisualElementContract.width, 200),
            Write(VisualElementContract.height, 200), Write(ViewContract.horizontalAlignment, Alignment.start),
            Write(ViewContract.verticalAlignment, Alignment.start),
        ], id: "layout")
        let held = Rectangle()
            .fill(.red)
            .width(40)
            .height(40)
            .horizontalAlignment(edge)
            .verticalAlignment(edge)
            .id("specimen")

        let layout: any View = switch element {
        case "Grid": dressing.dress(Grid { held }.motion(law))
        case "HStack": dressing.dress(HStack { held }.motion(law))
        case "ZStack": dressing.dress(ZStack { held }.motion(law))
        case "MotionLayout":
            dressing.dress(AnyView(
                MotionLayout([0], parameters: State(wrappedValue: 0.0).projectedValue) { _ in
                    Rectangle()
                        .fill(.red)
                        .id("specimen")
                } placements: { _, _ in
                    [Placement(Rect(x: far ? 160 : 0, y: far ? 160 : 0, width: 40, height: 40))]
                }
                .motion(law)))
        default: dressing.dress(VStack { held }.motion(law))
        }
        return AnyView(layout)
    }
}

/// A layout of each kind holding a view, as a layout's cases need it.
@MainActor
enum Holding {
    /// A layout of `element`'s kind holding `content`, clipping, letting input through and ignoring the safe area as
    /// said, as large as said where it is and then at its room's corner, its frames told to `heard`.
    static func layout(
        _ element: String, clips: Bool = false, through: Bool = false, width: Double? = nil, height: Double? = nil,
        ignores: SafeAreaEdges = [], heard: (@MainActor ([Double]) -> Void)? = nil, _ content: () -> any View
    ) -> AnyView {
        let held = AnyView(content())
        var worn: [any Worn] = [
            Write(LayoutContract.clipsContent, clips), Write(LayoutContract.letsInputThrough, through),
            Write(LayoutContract.ignoresSafeArea, ignores),
        ]
        if let heard { worn.append(Hear(ViewContract.layoutFrameChanged, heard)) }
        if let width {
            worn += [Write(VisualElementContract.width, width), Write(ViewContract.horizontalAlignment, Alignment.start)]
        }
        if let height {
            worn += [Write(VisualElementContract.height, height), Write(ViewContract.verticalAlignment, Alignment.start)]
        }
        let dressing = Dressing(worn, id: "layout")
        let layout: any View = switch element {
        case "Grid": dressing.dress(Grid { held })
        case "HStack": dressing.dress(HStack { held })
        case "ZStack": dressing.dress(ZStack { held })
        case "MotionLayout": dressing.dress(AnyView(Specimens.motionLayout(holding: held)))
        default: dressing.dress(VStack { held })
        }
        return AnyView(layout)
    }
}

/// A small picture or - once `detailed` - a large one in its place, each wearing one key: the large one says where
/// it is drawn to `drawn`, and where its layout puts it to `placed`.
private struct Swapped: View {
    let detailed: Binding<Bool>
    let drawn: Received<[Double]>
    let placed: Received<[Double]>

    var body: some View {
        VStack {
            if detailed.wrappedValue {
                Rectangle()
                    .fill(.red)
                    .width(160)
                    .height(80)
                    .onEvent(ViewContract.presentationFrameChanged) { drawn.values.append($0) }
                    .onEvent(ViewContract.layoutFrameChanged) { placed.values.append($0) }
                    .sharedTransition("picture")
                    .motion(.eased(.milliseconds(600), curve: .linear))
            } else {
                Rectangle()
                    .fill(.red)
                    .width(40)
                    .height(40)
                    .sharedTransition("picture")
            }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

/// Three views side by side in a layout of each kind that holds several, the scope: the middle one small, or large
/// once `detailed`, each wearing one key.
@MainActor
enum SettingOut {
    /// The layouts whose children are its own views, side by side or over each other.
    static let kinds: Set<String> = ["VStack", "HStack", "Grid", "ZStack", "MotionLayout"]

    /// The layouts that keep a view leaving them: a stack, a grid, a ZStack.
    static let keeping: Set<String> = ["VStack", "HStack", "Grid", "ZStack"]

    static func layout(_ element: String, detailed: Bool) -> AnyView {
        let dressing = Dressing([Write(LayoutContract.transitionScope, 1)], id: "layout")
        let layout: any View = switch element {
        case "HStack": dressing.dress(HStack { box("before"); picture(detailed); box("after") })
        case "Grid": dressing.dress(Grid { box("before"); picture(detailed); box("after") })
        case "ZStack": dressing.dress(ZStack { box("before"); picture(detailed); box("after") })
        case "MotionLayout":
            dressing.dress(MotionLayout([0, 1, 2], parameters: State(wrappedValue: 0.0).projectedValue) { index in
                if index == 1 { picture(detailed) } else { box("box\(index)") }
            } placements: { _, _ in
                (0..<3).map { Placement(Rect(x: Double($0) * 30, y: 0, width: 160, height: 80)) }
            }
            .width(240).height(80))
        default: dressing.dress(VStack { box("before"); picture(detailed); box("after") })
        }
        return AnyView(layout)
    }

    /// Two views of two keys in a layout of each kind that keeps a view leaving it, the scope: small side by side in a
    /// row, or - once `detailed` - large one under the other in a column, each large one telling where it is drawn.
    static func pairs(
        _ element: String, detailed: Bool, first: Received<[Double]>, second: Received<[Double]>
    ) -> AnyView {
        let dressing = Dressing([Write(LayoutContract.transitionScope, 1)], id: "layout")
        let layout: any View = switch element {
        case "HStack": dressing.dress(HStack { pair(detailed, first, second) })
        case "Grid": dressing.dress(Grid { pair(detailed, first, second) })
        case "ZStack": dressing.dress(ZStack { pair(detailed, first, second) })
        default: dressing.dress(VStack { pair(detailed, first, second) })
        }
        return AnyView(layout)
    }

    @ViewBuilder
    private static func pair(_ detailed: Bool, _ first: Received<[Double]>, _ second: Received<[Double]>) -> some View {
        if detailed {
            VStack {
                Rectangle().fill(.red).width(160).height(80).sharedTransition("a")
                    .onEvent(ViewContract.presentationFrameChanged) { first.values.append($0) }
                    .motion(.eased(.milliseconds(600), curve: .linear))
                Rectangle().fill(.blue).width(100).height(50).sharedTransition("b")
                    .onEvent(ViewContract.presentationFrameChanged) { second.values.append($0) }
                    .motion(.eased(.milliseconds(600), curve: .linear))
            }
            .horizontalAlignment(.start)
        } else {
            HStack {
                Rectangle().fill(.red).width(40).height(40).sharedTransition("a")
                Rectangle().fill(.blue).width(20).height(20).sharedTransition("b")
            }
        }
    }

    private static func box(_ id: String) -> some View {
        Rectangle().fill(.blue).width(40).height(40).id(id)
    }

    @ViewBuilder
    private static func picture(_ detailed: Bool) -> some View {
        if detailed {
            Rectangle()
                .fill(.red)
                .width(160)
                .height(80)
                .id("large")
                .sharedTransition("picture")
                .motion(.eased(.milliseconds(600), curve: .linear))
        } else {
            Rectangle()
                .fill(.red)
                .width(40)
                .height(40)
                .id("small")
                .sharedTransition("picture")
        }
    }
}
