// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ViewContract.sharedPresentation` in the layouts holding it: views of one transition id, one leaving and one
/// coming in another holder, drawn as one - the one coming setting out where the other was drawn, in front of what
/// it passes until it lands, the one leaving kept for it, and each id of a change with its own partner.
extension ViewTests {
    /// A layout shares the presentation of the views in it by their ids: one made in another holder as its partner
    /// is dropped sets out as large as that one was drawn, and grows to its own size.
    @MainActor
    static func sharedIn(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theViewsInItShareTheirPresentationByTheirIds", proves: [
            Covered(ViewContract.sharedPresentation, on: element),
        ], needs: [
            Covered(ViewContract.sharedPresentation, on: RectangleContract.self),
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
                        element, Swapped(detailed: detailed.projectedValue, drawn: drawn, placed: placed), [])
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

    /// A layout draws a view setting out in it from its partner in front of the views beside it
    /// until it lands, and in its own order again then.
    @MainActor
    static func drawnInFront(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aViewSettingOutInItIsDrawnInFrontUntilItLands", proves: [
            Covered(ViewContract.sharedPresentation, on: element),
        ], needs: [
            Covered(ViewContract.sharedPresentation, on: RectangleContract.self),
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

    /// A layout that keeps a view that leaves keeps the one leaving it for its partner: drawn where
    /// it stood, behind the larger one setting out, until that one lands - and gone then.
    @MainActor
    static func keptForItsPartner(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theViewLeavingItStandsUntilItsPartnerLands", proves: [
            Covered(ViewContract.sharedPresentation, on: element),
        ], needs: [
            Covered(ViewContract.sharedPresentation, on: RectangleContract.self),
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

    /// A layout that keeps a view that leaves draws the two views of one presentation as one: on the way, its toolkit
    /// draws the large one coming and the small one kept for it in one rectangle.
    @MainActor
    static func drawnAsOne(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theTwoViewsOfAPresentationAreDrawnAsOne", proves: [
            Covered(ViewContract.sharedPresentation, on: element),
        ], needs: [
            Covered(ViewContract.sharedPresentation, on: RectangleContract.self),
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
            try drawnAsOne(s, clock)
        }
    }

    /// A view its layout draws smaller goes along as it is drawn: a motion layout drawing its middle card at half its
    /// size, kept as it leaves, draws that card where the large one coming is drawn, all the way.
    @MainActor
    static var drawnAsOneFromAPlaceDrawnSmaller: ConformanceCase {
        ConformanceCase("MotionLayout.aViewItDrawsSmallerGoesAlongAsItIsDrawn", proves: [
            Covered(ViewContract.sharedPresentation, on: "MotionLayout"),
        ], needs: [
            Covered(ViewContract.sharedPresentation, on: RectangleContract.self),
            Covered(ClickElementContract.clicked, on: ButtonContract.self),
        ]) { s in
            let clock = TestClock()
            let detailed = State(wrappedValue: false)
            s.start(clock: clock) {
                VStack {
                    Button("Toggle").onClicked { detailed.wrappedValue.toggle() }.id("toggle")
                    SettingOut.halved(detailed: detailed.wrappedValue)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            try drawnAsOne(s, clock)
        }
    }

    /// Opens the large picture out of the small one in the layout of id "layout", and reads, three times on the
    /// way, that its toolkit draws the two in one rectangle.
    @MainActor
    private static func drawnAsOne(_ s: Session, _ clock: TestClock) throws {
        s.frames(of: clock, until: 200)
        let layout = try s.element("layout")
        let small = try s.element("picture")
        try s.perform(.activate, on: s.element("toggle"))
        s.settle { small.lifecycle != .active }
        let large = try s.element("picture")

        for time in [350.0, 500, 650] {
            s.frames(of: clock, until: time)
            let (leaving, coming) = (try s.drawnRect(of: small), try s.drawnRect(of: large))
            let apart = zip([leaving.x, leaving.y, leaving.width, leaving.height],
                            [coming.x, coming.y, coming.width, coming.height]).map { abs($0 - $1) }.max() ?? 0
            s.expect(apart <= 1, true, "at \(Int(time)) ms in \(layout.type.name), drawn as one: \(leaving), \(coming)")
        }
        // Landed, nothing moves it: drawn where its toolkit placed it - the read stands in the window's points.
        s.frames(of: clock, until: 1_400)
        let (drawn, placed) = (try s.drawnRect(of: large), try s.place(of: large))
        let off = zip([drawn.x, drawn.y, drawn.width, drawn.height], [placed.x, placed.y, placed.width, placed.height])
            .map { abs($0 - $1) }.max() ?? 0
        s.expect(off <= 1, true, "landed, drawn where it stands: \(drawn), \(placed)")
    }

    /// A layout that keeps a view that leaves keeps the one closed as it opens: the small view made again while the
    /// large one still grows out of it meets it through their presentation - never taking the small one leaving
    /// back - and the large one goes back along onto it, drawn until that run lands, and gone then.
    @MainActor
    static func closedAsItOpens(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aViewClosedAsItOpensGoesBackAlong", proves: [
            Covered(ViewContract.sharedPresentation, on: element),
        ], needs: [
            Covered(ViewContract.sharedPresentation, on: RectangleContract.self),
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
            try s.perform(.activate, on: s.element("toggle"))
            s.settle { layout.children.count == 3 && layout.children.map(\.id) != small }
            let large = layout.children[1].id
            s.frames(of: clock, until: 300)

            // A sixth of its way in, the large one is closed: the small one made again where it still leaves, and
            // the two on their way back - a view let go had gone two frames on.
            try s.perform(.activate, on: s.element("toggle"))
            s.frames(of: clock, until: 500)
            s.expect(try s.drawingOrder(of: layout).contains(large), true, "the large one goes back along, drawn")

            s.frames(of: clock, until: 2_000)
            let landed = layout.children.map(\.id)
            try s.settle { try s.drawingOrder(of: layout) == landed }
            s.expect(try s.drawingOrder(of: layout), landed, "landed: the large one is gone")
        }
    }

    /// A layout that keeps a view that leaves pairs each id of one change with its own partner: two
    /// views leaving in a row, an id on each, and two made in a column - each sets out as large as its own partner
    /// was drawn, and grows onto its own place.
    @MainActor
    static func eachKeyOwn(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).eachIdOfAChangeSetsOutFromItsOwnPartner", proves: [
            Covered(ViewContract.sharedPresentation, on: element),
        ], needs: [
            Covered(ViewContract.sharedPresentation, on: RectangleContract.self),
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
}

/// A small picture or - once `detailed` - a large one in a holder of its own, the two of one id: the large one says
/// where it is drawn to `drawn`, and where its layout puts it to `placed`.
private struct Swapped: View {
    let detailed: Binding<Bool>
    let drawn: Received<[Double]>
    let placed: Received<[Double]>

    var body: some View {
        VStack {
            if detailed.wrappedValue {
                HStack {
                    Rectangle()
                        .fill(.red)
                        .width(160)
                        .height(80)
                        .onEvent(ViewContract.presentationFrameChanged) { drawn.values.append($0) }
                        .onEvent(ViewContract.layoutFrameChanged) { placed.values.append($0) }
                        .id("picture")
                        .transition(id: "picture")
                        .motion(.eased(.milliseconds(600), curve: .linear))
                }
                .id("large")
            } else {
                Rectangle()
                    .fill(.red)
                    .width(40)
                    .height(40)
                    .id("picture")
                    .transition(id: "picture")
            }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

/// Three views side by side in a layout of each kind that holds several: the middle one small, or large in a holder
/// of its own once `detailed`, the two of one id.
@MainActor
enum SettingOut {
    /// The layouts whose children are its own views, side by side or over each other.
    static let kinds: Set<String> = ["VStack", "HStack", "Grid", "ZStack", "MotionLayout"]

    /// The layouts that keep a view leaving them: a stack, a grid, a ZStack.
    static let keeping: Set<String> = ["VStack", "HStack", "Grid", "ZStack"]

    static func layout(_ element: String, detailed: Bool) -> AnyView {
        let dressing = Dressing([], id: "layout")
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

    /// Three cards a motion layout places, the middle one drawn at half its size - or, once `detailed`, the large
    /// picture in a holder of its own - in a stack that keeps a view leaving it; the two pictures of one id.
    static func halved(detailed: Bool) -> AnyView {
        let dressing = Dressing([], id: "layout")
        return AnyView(dressing.dress(VStack {
            if detailed {
                picture(true)
            } else {
                MotionLayout([0, 1, 2], parameters: State(wrappedValue: 0.0).projectedValue) { index in
                    if index == 1 { picture(false) } else { box("box\(index)") }
                } placements: { _, _ in
                    (0..<3).map {
                        Placement(Rect(x: Double($0) * 50, y: 0, width: 40, height: 40), transform: .scale($0 == 1 ? 0.5 : 1))
                    }
                }
                .width(150)
                .height(40)
            }
        }))
    }

    /// Two views of two keys in a layout of each kind that keeps a view leaving it, the scope: small side by side in a
    /// row, or - once `detailed` - large one under the other in a column, each large one telling where it is drawn.
    static func pairs(
        _ element: String, detailed: Bool, first: Received<[Double]>, second: Received<[Double]>
    ) -> AnyView {
        let dressing = Dressing([], id: "layout")
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
                Rectangle().fill(.red).width(160).height(80).transition(id: "a")
                    .onEvent(ViewContract.presentationFrameChanged) { first.values.append($0) }
                    .motion(.eased(.milliseconds(600), curve: .linear))
                Rectangle().fill(.blue).width(100).height(50).transition(id: "b")
                    .onEvent(ViewContract.presentationFrameChanged) { second.values.append($0) }
                    .motion(.eased(.milliseconds(600), curve: .linear))
            }
            .horizontalAlignment(.start)
        } else {
            HStack {
                Rectangle().fill(.red).width(40).height(40).transition(id: "a")
                Rectangle().fill(.blue).width(20).height(20).transition(id: "b")
            }
        }
    }

    private static func box(_ id: String) -> some View {
        Rectangle().fill(.blue).width(40).height(40).id(id)
    }

    @ViewBuilder
    private static func picture(_ detailed: Bool) -> some View {
        if detailed {
            HStack {
                Rectangle()
                    .fill(.red)
                    .width(160)
                    .height(80)
                    .id("picture")
                    .transition(id: "picture")
                    .motion(.eased(.milliseconds(600), curve: .linear))
            }
            .id("large")
        } else {
            Rectangle()
                .fill(.red)
                .width(40)
                .height(40)
                .id("picture")
                .transition(id: "picture")
                .motion(.eased(.milliseconds(600), curve: .linear))
        }
    }
}
