// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A BINDING CONVERTED ON ITS WAY TO A CONTROL: a second state the host
// carries, worked out from the first by an engine the differ writes, and - with
// a way back - worked back from a report. Held here end to end: the derived
// image, the engines each way, the one object across renders, and the read at
// build that makes a body a reader of the sources.

import XCTest
@_spi(Host) @testable import StateUI

/// Counts builds of a body.
private final class Builds {
    var count = 0
}

/// A body that READS a conversion - so it is a reader of the source.
private struct Percent: View {
    let volume: State<Double>
    let builds: Builds

    var body: some View {
        builds.count += 1

        return AnyView(node: label("\(Int(volume.projectedValue.convert { $0 * 100 }.wrappedValue))%"))
    }
}

/// A body that READS a chain of two conversions - so it is a reader of the first source.
private struct Chained: View {
    let volume: State<Double>
    let builds: Builds

    var body: some View {
        builds.count += 1

        let words = volume.projectedValue.convert { $0 * 100 }.convert { "\(Int($0.rounded()))%" }
        return AnyView(node: label(words.wrappedValue))
    }
}

/// A slider over a conversion that reports back only while `editable`.
private struct Editable: View {
    let volume: State<Double>
    let editable: Bool

    var body: some View {
        Slider(volume.projectedValue.convert({ $0 * 100 }, back: editable ? { $0 / 100 } : nil)).maximum(100)
    }
}

/// A body that hands a conversion on, twice over, so the registration's
/// number can be compared between two renders.
private struct Twice: View {
    let volume: State<Double>

    var body: some View {
        Slider(volume.projectedValue.convert { $0 * 100 } back: { $0 / 100 })
    }
}

/// The derived states some readouts were handed, in the order built.
private final class Seen {
    var storages: [ObjectIdentifier] = []
}

/// A readout of one source in a unit it was built with - two of them, one line,
/// converting one source two ways.
private struct Readout: View {
    let volume: State<Double>
    let unit: String
    let seen: Seen

    var body: some View {
        let shown = volume.projectedValue.convert { "\($0) \(unit)" }
        seen.storages.append(ObjectIdentifier(shown.storage))

        return Slider(volume.projectedValue).accessibilityLabel(shown.wrappedValue)
    }
}

/// A slider for each factor, each converting one source by its own factor in one ForEach - noting the derived
/// state each factor was handed.
private struct Factors: View {
    let source: Binding<Double>
    let factors: State<[Double]>
    let seen: SeenByFactor

    var body: some View {
        VStack {
            ForEach(factors.wrappedValue) { factor in
                let scaled = source.convert({ $0 * factor }, back: { $0 / factor })
                let _ = seen.note(factor, scaled)
                Slider(scaled).maximum(100).id(factor)
            }
        }
    }
}

/// The derived state each factor was handed, last build.
@MainActor
private final class SeenByFactor {
    var storages: [Double: ObjectIdentifier] = [:]

    func note(_ factor: Double, _ binding: Binding<Double>) {
        storages[factor] = ObjectIdentifier(binding.storage)
    }
}

/// One helper making a converted slider, called twice in one body.
private struct HelperTwice: View {
    let source: Binding<Double>

    var body: some View {
        VStack {
            scaled(10).id("ten")
            scaled(100).id("hundred")
        }
    }

    private func scaled(_ factor: Double) -> some View {
        Slider(source.convert({ $0 * factor }, back: { $0 / factor })).maximum(100)
    }
}

@MainActor
final class ConversionTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// TWO VIEWS CONVERTING ONE SOURCE ON ONE LINE keep two derived states - each
    /// its own unit, each one object across renders - and the one that leaves
    /// takes its own with it.
    func testTwoViewsConvertingOneSourceOnOneLineKeepTwoStates() {
        let renders = Renders()
        let seen = Seen()
        let volume = State(0.5)

        func tree(_ both: Bool) -> Node {
            VStack {
                Readout(volume: volume, unit: "cm", seen: seen).id("cm")
                if both { Readout(volume: volume, unit: "in", seen: seen).id("in") }
            }.node
        }

        renders.render(tree(true))
        XCTAssertEqual(Set(seen.storages).count, 2, "the two readouts share one derived state")

        let live = { volume.storage.derivations.values.filter { $0.state != nil }.count }
        renders.render(tree(true))
        XCTAssertEqual(live(), 2, "one derived state a readout, kept across renders")

        renders.render(tree(false))
        XCTAssertEqual(live(), 1, "the readout that left kept its derived state")
    }

    /// EACH ROW OF A FOREACH KEEPS ITS OWN CONVERSION: its own derived state, worked out by its own factor, the
    /// same one across a reorder - one line written, as many uses as rows.
    func testEachRowOfAForEachKeepsItsOwnConversion() throws {
        let (source, factors, seen) = (State(0.5), State([10.0, 100.0]), SeenByFactor())
        let renders = Renders()
        let patch = renders.render(Factors(source: source.projectedValue, factors: factors, seen: seen).node)
        let numbers = try patch.subtree.filter { $0.type == .slider }.map { try XCTUnwrap($0.driven?[.value]?.state) }
        let board = Renderer.shared.board

        XCTAssertEqual(Set(numbers).count, 2, "two rows, two derived states")
        board.cycle(now: 0, reducesMotion: false)
        XCTAssertEqual(numbers.map { destination(of: $0) }, [5, 50])

        source.wrappedValue = 0.7
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(numbers.map { destination(of: $0) }, [7, 70])

        let before = seen.storages
        factors.wrappedValue = [100, 10]
        renders.revisit(changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(seen.storages, before, "each factor kept its derived state as the rows changed places")
    }

    /// A ROW'S REPORT COMES BACK THROUGH ITS OWN WAY BACK, not the last row's.
    func testARowsReportComesBackThroughItsOwnWayBack() throws {
        let source = State(0.5)
        let renders = Renders()
        let patch = renders.render(Factors(source: source.projectedValue, factors: State([10.0, 100.0]), seen: SeenByFactor()).node)
        let number = try XCTUnwrap(patch.subtree.first { $0.type == .slider }?.driven?[.value]?.state)
        let board = Renderer.shared.board

        board.cycle(now: 0, reducesMotion: false)
        dragged(number, to: 8)
        board.cycle(now: 16, reducesMotion: false)
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(source.wrappedValue, 0.8, accuracy: 1e-9, "the first row's factor, ten")
    }

    /// A HELPER CALLED TWICE IN ONE BODY MAKES TWO CONVERSIONS: one line, two uses, told apart by which time it ran.
    func testAHelperCalledTwiceMakesTwoConversions() throws {
        let source = State(0.5)
        let renders = Renders()
        let patch = renders.render(HelperTwice(source: source.projectedValue).node)
        let numbers = try patch.subtree.filter { $0.type == .slider }.map { try XCTUnwrap($0.driven?[.value]?.state) }

        XCTAssertEqual(Set(numbers).count, 2, "two calls, two derived states")
        Renderer.shared.board.cycle(now: 0, reducesMotion: false)
        XCTAssertEqual(numbers.map { destination(of: $0) }, [5, 50])
    }

    /// The journey a converted slider walks, read off its image.
    private func destination(of number: Int32) -> Double? {
        guard let image = Renderer.shared.storage(of: number) else { return nil }

        let board = Renderer.shared.board

        return JourneyLanes<Double>(carried: board.read(image, lanes: JourneyLanes<Double>.lanes))?.destination
    }

    /// A converted binding is a second state the host carries: the control is
    /// tied to the DERIVED image, the forward engine settles it from the
    /// source, a report on it comes back through the way back, and a write to
    /// the source goes forward again.
    func testAConvertedBindingIsASecondStateTheHostCarries() throws {
        let volume = State(wrappedValue: 0.2)
        let renders = Renders()

        let patch = renders.render(
            Slider(volume.projectedValue.convert { $0 * 100 } back: { $0 / 100 })
                .maximum(100)
                .node)

        let number = try XCTUnwrap(patch.driven?[.value]?.state)
        XCTAssertNotNil(Renderer.shared.storage(of: number), "a state rides that number")
        let board = Renderer.shared.board

        XCTAssertNotEqual(number, volume.number, "the control is tied to the derived state, not the source")
        XCTAssertEqual(destination(of: number), 20, "worked out from 0.2 as the conversion was made")

        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        // A drag on the derived image comes back through the way back.
        dragged(number, to: 50)
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(volume.wrappedValue, 0.5, accuracy: 1e-9, "the report landed on the source in its own terms")

        // A write to the source goes forward.
        volume.wrappedValue = 1
        board.cycle(now: 48, reducesMotion: false)

        XCTAssertEqual(destination(of: number), 100, "the derived state followed the source")
    }

    /// A conversion written once is ONE state across renders: the tie the host
    /// holds keeps its number, and nothing is registered again.
    func testAConversionKeepsOneDerivedStateAcrossRenders() throws {
        let volume = State(wrappedValue: 0.2)
        let renders = Renders()
        let view = Twice(volume: volume)

        let first = renders.render(view.node)
        let again = renders.renderFromScratch(view.node)

        XCTAssertEqual(
            first.driven?[.value]?.state, again.driven?[.value]?.state,
            "the same line converting the same source is the same derived state")
    }

    /// A CONVERSION'S PLACE IS A NUMBER: its file, line and column and the element building it, spelled nowhere.
    func testAConversionsPlaceIsSpelledNowhere() {
        let renders = Renders()
        let view = Twice(volume: State(wrappedValue: 0.2))
        renders.render(view.node)
        let texts = Renderer.shared.texts

        renders.renderFromScratch(view.node)

        XCTAssertEqual(Renderer.shared.texts, texts, "no text built")
        XCTAssertEqual(PathNumber(file: #fileID, line: 1, column: 2), PathNumber(file: #fileID, line: 1, column: 2))
        XCTAssertNotEqual(PathNumber(file: #fileID, line: 1, column: 2), PathNumber(file: #fileID, line: 2, column: 1))
    }

    /// Two states make one derived value, followed both ways: a text driven
    /// from two numbers changes when either does.
    func testTwoSourcesMakeOneDerivedValue() throws {
        let width = State(wrappedValue: 3.0)
        let height = State(wrappedValue: 4.0)
        let renders = Renders()

        let patch = renders.render(
            Text(.multi(width.projectedValue, height.projectedValue).convert { "\(Int($0 + $1))" })
                .node)

        let number = try XCTUnwrap(patch.driven?[.text]?.state)
        let image = try XCTUnwrap(Renderer.shared.storage(of: number))
        let board = Renderer.shared.board

        func words() -> String? {
            String(carried: board.read(image, lanes: 0))
        }

        XCTAssertEqual(words(), "7")

        board.cycle(now: 0, reducesMotion: false)
        height.wrappedValue = 10
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(words(), "13", "the engine followed the second source")
    }

    /// A CONVERSION OF A CONVERSION follows the first source: a control handed the last of a chain is told every write
    /// to the first, whichever of the chain it was handed.
    func testAConversionOfAConversionFollowsTheFirstSource() throws {
        let volume = State(wrappedValue: 0.2)
        let renders = Renders()

        let patch = renders.render(
            Text(volume.projectedValue.convert { $0 * 100 }.convert { "\(Int($0.rounded()))%" })
                .node)

        let number = try XCTUnwrap(patch.driven?[.text]?.state)
        let image = try XCTUnwrap(Renderer.shared.storage(of: number))
        let board = Renderer.shared.board

        func words() -> String? {
            String(carried: board.read(image, lanes: 0))
        }

        XCTAssertEqual(words(), "20%")

        board.cycle(now: 0, reducesMotion: false)
        volume.wrappedValue = 0.7
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(words(), "70%", "the chain followed its first source")
    }

    /// A body READING a chain reads its first source: rebuilt as the source moves, the chain worked out afresh.
    func testABodyReadingAChainIsAReaderOfItsFirstSource() {
        let volume = State(wrappedValue: 0.2)
        let builds = Builds()
        let renders = Renders()

        let first = renders.render(Chained(volume: volume, builds: builds).node)
        XCTAssertEqual(first.props[.text], .string("20%"))

        volume.wrappedValue = 0.75
        let patch = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(builds.count, 2, "the body read the first source through the chain")
        XCTAssertEqual(patch.props[.text], .string("75%"), "and read the chain afresh")
    }

    /// A report on the last of a chain comes back through every link to the first source.
    func testAReportComesBackThroughAChain() throws {
        let volume = State(wrappedValue: 0.2)
        let renders = Renders()

        let patch = renders.render(
            Slider(
                volume.projectedValue.convert({ $0 * 100 }, back: { $0 / 100 })
                    .convert({ $0 * 10 }, back: { $0 / 10 }))
                .maximum(1000)
                .node)

        let number = try XCTUnwrap(patch.driven?[.value]?.state)
        let board = Renderer.shared.board
        XCTAssertEqual(destination(of: number), 200)

        board.cycle(now: 0, reducesMotion: false)
        dragged(number, to: 500)
        board.cycle(now: 16, reducesMotion: false)
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(volume.wrappedValue, 0.5, accuracy: 1e-9, "the report landed on the first source")
    }

    /// A conversion declared again is the new declaration's alone: written without a way back, a report goes back
    /// to nobody; written with it again, only reports made since land.
    func testAConversionDeclaredAgainKeepsNoWayBackItNoLongerWrites() throws {
        let volume = State(wrappedValue: 0.2)
        let renders = Renders()

        let patch = renders.render(Editable(volume: volume, editable: true).node)
        let number = try XCTUnwrap(patch.driven?[.value]?.state)
        let board = Renderer.shared.board
        board.cycle(now: 0, reducesMotion: false)

        renders.render(Editable(volume: volume, editable: false).node)
        dragged(number, to: 50)
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(volume.wrappedValue, 0.2, accuracy: 1e-9, "no way back is written now")

        renders.render(Editable(volume: volume, editable: true).node)
        board.cycle(now: 32, reducesMotion: false)
        XCTAssertEqual(volume.wrappedValue, 0.2, accuracy: 1e-9, "a report made with no way back stays unanswered")

        // The host reads the frame - the slider shows the source again - before the user drags it.
        _ = board.dirty()
        dragged(number, to: 70)
        board.cycle(now: 48, reducesMotion: false)
        XCTAssertEqual(volume.wrappedValue, 0.7, accuracy: 1e-9, "a report made since lands")
    }

    /// A conversion made with no element being built and never read lets its source go: the source holds the
    /// derived state, and nothing the derived state keeps holds the source.
    func testAConversionNobodyReadLetsItsSourceGo() {
        weak var held: AnyObject?
        weak var heldByJourney: AnyObject?
        do {
            let source = State(wrappedValue: 0.2)
            held = source.storage
            _ = source.projectedValue.convert { $0 * 100 }

            let moving = State(wrappedValue: 0.2)
            heldByJourney = moving.storage
            _ = moving.projectedValue.journey.convert { $0.value * 100 }
        }
        XCTAssertNil(held, "a conversion nobody read kept its source")
        XCTAssertNil(heldByJourney, "a journey's conversion nobody read kept its source")
    }

    /// `.multi` reads several states as one, in the order they are named -
    /// the same engine, written at the call site the way a control reads.
    func testMultiReadsSeveralStatesAsOne() throws {
        let info = State(wrappedValue: "width")
        let value = State(wrappedValue: 3.0)
        let renders = Renders()

        let patch = renders.render(
            Text(Binding.multi(info.projectedValue, value.projectedValue).convert { "\($0) = \(Int($1))" })
                .node)

        let number = try XCTUnwrap(patch.driven?[.text]?.state)
        let image = try XCTUnwrap(Renderer.shared.storage(of: number))
        let board = Renderer.shared.board

        func words() -> String? {
            String(carried: board.read(image, lanes: 0))
        }

        XCTAssertEqual(words(), "width = 3")

        board.cycle(now: 0, reducesMotion: false)
        value.wrappedValue = 8
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(words(), "width = 8", "the engine follows every source it was handed")

        info.wrappedValue = "height"
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(words(), "height = 8", "including the first one")
    }

    /// Ten is the last arity `.multi` is written out for, and it reads like
    /// the two-state one: the arguments arrive in the order they were named.
    func testMultiReadsAsManyAsTenStates() throws {
        let first = State(wrappedValue: 1.0)
        let rest = (0 ..< 9).map { _ in State(wrappedValue: 1.0) }
        let renders = Renders()

        let patch = renders.render(
            Text(Binding.multi(
                first.projectedValue,
                rest[0].projectedValue,
                rest[1].projectedValue,
                rest[2].projectedValue,
                rest[3].projectedValue,
                rest[4].projectedValue,
                rest[5].projectedValue,
                rest[6].projectedValue,
                rest[7].projectedValue,
                rest[8].projectedValue
            ).convert { "\(Int($0 + $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8 + $9))" })
                .node)

        let number = try XCTUnwrap(patch.driven?[.text]?.state)
        let image = try XCTUnwrap(Renderer.shared.storage(of: number))
        let board = Renderer.shared.board

        XCTAssertEqual(String(carried: board.read(image, lanes: 0)), "10")

        board.cycle(now: 0, reducesMotion: false)
        rest[8].wrappedValue = 11
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(String(carried: board.read(image, lanes: 0)), "20", "the tenth is followed too")
    }

    /// Handing states to `.multi` makes a reader of nobody: the sources are
    /// read off their storages, so the closure that wrote the conversion is
    /// not rebuilt when any of them moves.
    func testMultiMakesNoReader() {
        let info = State(wrappedValue: "width")
        let value = State(wrappedValue: 3.0)
        let renders = Renders()

        _ = renders.render(
            Text(Binding.multi(info.projectedValue, value.projectedValue)
                .convert { "\($0) \(Int($1))" })
                .node)

        XCTAssertFalse(info.storage.readAtBuild, "a multi source is read off its storage")
        XCTAssertFalse(value.storage.readAtBuild, "and so is the second")
    }

    /// The way back is the host's reports alone: what the application writes goes forward and stays as written,
    /// however the conversion rounds it on the way - only a report comes back.
    func testTheApplicationsWriteIsNotWorkedBack() throws {
        let volume = State(wrappedValue: 0.2)
        let renders = Renders()

        let patch = renders.render(
            Slider(volume.projectedValue.convert({ ($0 * 100).rounded() }, back: { $0 / 100 }))
                .maximum(100)
                .node)

        let number = try XCTUnwrap(patch.driven?[.value]?.state)
        XCTAssertNotNil(Renderer.shared.storage(of: number), "a state rides that number")
        let board = Renderer.shared.board
        board.cycle(now: 0, reducesMotion: false)

        volume.wrappedValue = 0.123
        board.cycle(now: 16, reducesMotion: false)
        board.cycle(now: 32, reducesMotion: false)

        XCTAssertEqual(volume.wrappedValue, 0.123, accuracy: 1e-12, "the application's write stays as written")
        XCTAssertEqual(destination(of: number), 12, "and goes forward rounded")

        _ = board.dirty()  // the host reads the frame, as it does every frame, before the user moves the thumb
        dragged(number, to: 40)
        board.cycle(now: 48, reducesMotion: false)

        XCTAssertEqual(volume.wrappedValue, 0.4, accuracy: 1e-12, "a report still comes back")
    }

    /// A report into a two-source conversion lands on both sources.
    func testAReportComesBackIntoBothSources() throws {
        let hours = State(wrappedValue: 1.0)
        let minutes = State(wrappedValue: 30.0)
        let renders = Renders()

        let patch = renders.render(
            Slider(
                Binding<Double>.multi(hours.projectedValue, minutes.projectedValue)
                    .convert({ h, m in h * 60 + m },
                             back: { total in ((total / 60).rounded(.down), total.truncatingRemainder(dividingBy: 60)) }))
            .maximum(600)
            .node)

        let number = try XCTUnwrap(patch.driven?[.value]?.state)
        XCTAssertNotNil(Renderer.shared.storage(of: number), "a state rides that number")
        let board = Renderer.shared.board

        XCTAssertEqual(destination(of: number), 90)

        board.cycle(now: 0, reducesMotion: false)
        dragged(number, to: 125)
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(hours.wrappedValue, 2)
        XCTAssertEqual(minutes.wrappedValue, 5)
    }

    /// A body that READS a conversion reads its source: the value is worked
    /// out afresh on the read, and the body is rebuilt when the source moves -
    /// with no engine anywhere, nothing having been handed on.
    func testABodyReadingAConversionIsAReaderOfItsSource() {
        let volume = State(wrappedValue: 0.2)
        let builds = Builds()
        let renders = Renders()

        let first = renders.render(Percent(volume: volume, builds: builds).node)

        XCTAssertEqual(first.props[.text], .string("20%"))
        XCTAssertEqual(builds.count, 1)

        volume.wrappedValue = 0.75
        let patch = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(builds.count, 2, "the body read the source through the conversion")
        XCTAssertEqual(patch.props[.text], .string("75%"), "and read the converted value afresh")
    }
}
