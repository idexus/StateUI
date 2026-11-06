// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How the window's rectangle reads its frame: into the first state (0), the second (1), nowhere (2) or to a handler
/// (3) - and what the handler heard.
@MainActor
private enum Measuring {
    static var first = State(wrappedValue: Rect.zero)
    static var second = State(wrappedValue: Rect.zero)
    static var way = State(wrappedValue: 0)
    static var heard: [Rect] = []
}

private struct MeasuringApplication: Application {
    var body: some Scene { WindowGroup { Measured().id("measured") } }
}

/// A rectangle reading its frame as `Measuring.way` says.
private struct Measured: View {
    var body: some View {
        let way = Measuring.way.wrappedValue
        var view = Rectangle().width(100).height(60)
        if way == 0 { view = view.frame(into: Measuring.first.projectedValue) }
        if way == 1 { view = view.frame(into: Measuring.second.projectedValue) }
        if way == 3 { view = view.onFrameChanged { Measuring.heard.append($0) } }
        return view
    }
}

/// Where an element stands, said to what reads it: once to each reader, and again as it changes.
@MainActor
final class FrameReportsTests: XCTestCase {
    private let standing: [Double] = [10, 20, 100, 60, 110, 120, 110, 80]

    /// The application running, its rectangle said once into the first state.
    private func measured() throws -> (runtime: HostRuntime, view: MountedElement) {
        Measuring.first = State(wrappedValue: .zero)
        Measuring.second = State(wrappedValue: .zero)
        Measuring.way = State(wrappedValue: 0)
        Measuring.heard = []
        MeasuringApplication.register()
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let view = try XCTUnwrap(runtime.tree.root?.first(id: .manual("measured")))
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()
        XCTAssertEqual(Measuring.first.wrappedValue, Rect(10, 20, 100, 60))
        return (runtime, view)
    }

    /// A state handed to `.frame` since reads where the view stands, the view standing still: the element says its
    /// standing report once more, to the reader that came.
    func testAStateHandedSinceHearsTheStandingFrame() throws {
        let (runtime, view) = try measured()
        Measuring.way.wrappedValue = 1
        runtime.pump.turn()
        XCTAssertTrue(runtime.tree.root?.first(id: .manual("measured")) === view, "the same element")
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()
        XCTAssertEqual(Measuring.second.wrappedValue, Rect(10, 20, 100, 60))
    }

    /// A handler of the frame's changes added since hears where the view stands, the view standing still.
    func testAHandlerAddedSinceHearsTheStandingFrame() throws {
        let (runtime, view) = try measured()
        Measuring.way.wrappedValue = 3
        runtime.pump.turn()
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()
        XCTAssertEqual(Measuring.heard, [Rect(10, 20, 100, 60)])
    }

    /// The same reader hears the same report no more: what the application wrote onto the state stands, and where
    /// the element stands is known all the same.
    func testTheSameReaderHearsTheSameReportNoMore() throws {
        let (runtime, view) = try measured()
        Measuring.first.wrappedValue = .zero
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()
        XCTAssertEqual(Measuring.first.wrappedValue, .zero)
        XCTAssertEqual(view.reportedFrame, standing)
    }
}
