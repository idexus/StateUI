// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A BINDING CONVERTED ON ITS WAY TO A CONTROL: a second state the host
// carries, worked out from the first by an engine the differ writes, and - with
// `convertBack` - worked back from a report. Held here end to end: the derived
// image, the engines each way, the one object across renders, and the read at
// build that makes a body a reader of the sources.

import XCTest
@testable import StateUI

/// Counts builds of a body.
private final class Builds {
    var count = 0
}

/// A body that READS a conversion - so it is a reader of the source.
private struct Percent: ContentView {
    let volume: State<Double>
    let builds: Builds

    var content: Element {
        builds.count += 1

        return label("\(Int(volume.projectedValue.convert { $0 * 100 }.wrappedValue))%")
    }
}

/// A body that hands a conversion on, twice over, so the registration's
/// number can be compared between two renders.
private struct Twice: ContentView {
    let volume: State<Double>

    var content: Element {
        Slider(volume.projectedValue.convert { $0 * 100 }.convertBack { $0 / 100 })
    }
}

final class ConversionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// The journey a converted slider walks, read off its image.
    private func destination(of number: Int32) -> Double? {
        guard let image = Renderer.shared.storage(of: number) else { return nil }

        let board = Renderer.shared.board(of: image)

        return AnimatedValue<Double>(carried: board.read(image, lanes: AnimatedValue<Double>.lanes))?.setPoint
    }

    /// A converted binding is a second state the host carries: the control is
    /// tied to the DERIVED image, the forward engine settles it from the
    /// source, a report on it comes back through `convertBack`, and a write to
    /// the source goes forward again.
    func testAConvertedBindingIsASecondStateTheHostCarries() throws {
        let volume = State(wrappedValue: 0.2)
        let renders = Renders()

        let patch = renders.render(
            Slider(volume.projectedValue.convert { $0 * 100 }.convertBack { $0 / 100 })
                .maximum(100)
                .body)

        let number = try XCTUnwrap(patch.driven?[.value]?.number)
        let board = Renderer.shared.board(of: try XCTUnwrap(Renderer.shared.storage(of: number)))

        XCTAssertNotEqual(number, volume.number, "the control is tied to the derived state, not the source")
        XCTAssertEqual(destination(of: number), 20, "worked out from 0.2 as the conversion was made")

        board.cycle(now: 0, reducesMotion: false)
        board.cycle(now: 16, reducesMotion: false)

        // A drag on the derived image comes back through convertBack.
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

        let first = renders.render(view.body)
        let again = renders.renderFromScratch(view.body)

        XCTAssertEqual(
            first.driven?[.value]?.number, again.driven?[.value]?.number,
            "the same line converting the same source is the same derived state")
    }

    /// Two states make one derived value, followed both ways: a text driven
    /// from two numbers changes when either does.
    func testTwoSourcesMakeOneDerivedValue() throws {
        let width = State(wrappedValue: 3.0)
        let height = State(wrappedValue: 4.0)
        let renders = Renders()

        let patch = renders.render(
            Label()
                .text(width.projectedValue.convert(with: height.projectedValue) { "\(Int($0 + $1))" })
                .body)

        let number = try XCTUnwrap(patch.driven?[.text]?.number)
        let image = try XCTUnwrap(Renderer.shared.storage(of: number))
        let board = Renderer.shared.board(of: image)

        func words() -> String? {
            String(carried: board.read(image, lanes: 0))
        }

        XCTAssertEqual(words(), "7")

        board.cycle(now: 0, reducesMotion: false)
        height.wrappedValue = 10
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(words(), "13", "the engine followed the second source")
    }

    /// `.multi` reads several states as one, in the order they are named -
    /// the same engine, written at the call site the way a control reads.
    func testMultiReadsSeveralStatesAsOne() throws {
        let info = State(wrappedValue: "width")
        let value = State(wrappedValue: 3.0)
        let renders = Renders()

        let patch = renders.render(
            Label(Binding.multi(info.projectedValue, value.projectedValue).convert { "\($0) = \(Int($1))" })
                .body)

        let number = try XCTUnwrap(patch.driven?[.text]?.number)
        let image = try XCTUnwrap(Renderer.shared.storage(of: number))
        let board = Renderer.shared.board(of: image)

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
            Label(Binding.multi(
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
                .body)

        let number = try XCTUnwrap(patch.driven?[.text]?.number)
        let image = try XCTUnwrap(Renderer.shared.storage(of: number))
        let board = Renderer.shared.board(of: image)

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
            Label(Binding.multi(info.projectedValue, value.projectedValue)
                .convert { "\($0) \(Int($1))" })
                .body)

        XCTAssertFalse(info.storage.readAtBuild, "a multi source is read off its storage")
        XCTAssertFalse(value.storage.readAtBuild, "and so is the second")
    }

    /// A report into a two-source conversion lands on both sources.
    func testAReportComesBackIntoBothSources() throws {
        let hours = State(wrappedValue: 1.0)
        let minutes = State(wrappedValue: 30.0)
        let renders = Renders()

        let patch = renders.render(
            Slider(
                hours.projectedValue
                    .convert(with: minutes.projectedValue) { h, m in h * 60 + m }
                    .convertBack { total in ((total / 60).rounded(.down), total.truncatingRemainder(dividingBy: 60)) })
            .maximum(600)
            .body)

        let number = try XCTUnwrap(patch.driven?[.value]?.number)
        let board = Renderer.shared.board(of: try XCTUnwrap(Renderer.shared.storage(of: number)))

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

        let first = renders.render(Percent(volume: volume, builds: builds).body)

        XCTAssertEqual(first.props[.text], .string("20%"))
        XCTAssertEqual(builds.count, 1)

        volume.wrappedValue = 0.75
        let patch = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(builds.count, 2, "the body read the source through the conversion")
        XCTAssertEqual(patch.props[.text], .string("75%"), "and read the converted value afresh")
    }

    /// A conversion of a part of a state, or of a binding made from closures,
    /// is worked out at build and reports nothing back - said out loud, and
    /// still a value.
    func testAConversionOfAPartIsWorkedOutAtBuild() {
        let room = State(wrappedValue: Rect(0, 0, 200, 100))
        let half = room.projectedValue.width.convert { $0 / 2 }

        XCTAssertEqual(half.wrappedValue, 100)
        XCTAssertNil(half.conversion, "nothing the host could carry, so nothing to arm")
    }
}
