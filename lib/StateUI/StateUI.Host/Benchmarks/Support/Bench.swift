// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One application run over the core and the host layer on a clock wound by hand, its native halves counted: what a
/// benchmark drives, counts and times.
/// Design: docs/design/host/benchmarks.md
@MainActor
final class Bench {
    /// The room every view that reads where it stands stands in: a phone's.
    let room: Rect

    var calls = NativeCalls()
    private(set) var runtime: HostRuntime!
    private let clock = BenchClock()

    /// Where the last child a run placed went, kept so the release build places every child.
    var placedAt = Rect(0, 0, 0, 0)

    /// Runs `application` in `room`: its window, the first render, and a second of frames for its arrival.
    init<Declared: Application>(_ application: @autoclosure @escaping () -> Declared, room: Rect = Rect(0, 0, 390, 700)) {
        self.room = room
        stateUIUseApp(application())
        runtime = HostRuntime(
            clock: clock, reducesMotion: { false },
            makeNative: { [unowned self] element in CountedView(element, in: self) }, log: { _ in })
        runtime.presenter = self
        runtime.connectWindow()
        runtime.pump.turn()
        laidOut()
        frames(for: 1_000)
    }

    /// The work done so far: the core's tally and the calls on the native halves.
    var work: Work {
        let tally = HostBoundary.tally
        return Work(
            renders: tally.renders, built: tally.built, walks: tally.walks, texts: tally.texts, made: calls.made,
            applied: calls.applied, arranged: calls.arranged, presented: calls.presented, placed: calls.placed,
            left: calls.left)
    }

    /// The first element of `type`.
    func element(_ type: NodeType) throws -> MountedElement {
        try XCTUnwrap(runtime.tree.root?.first(type: type), "no \(type.name) in the tree")
    }

    /// The toolkit laid the views out: each the tree reads says where it stands, and the turn renders what moved.
    func laidOut() {
        runtime.frames.laidOut()
        _ = runtime.frames.reportLaidOut()
        runtime.pump.turn()
    }

    /// One display frame, a sixtieth of a second on.
    func frame() {
        clock.time += 1_000 / 60
        runtime.displayCycle.frame(now: clock.time)
    }

    /// The display's frames for `milliseconds`.
    func frames(for milliseconds: Double) {
        let end = clock.time + milliseconds
        while clock.time < end { frame() }
    }

    /// The hand over `element` at `phase`, moving what is under it by `moved` - lifted at `speed`, pressed at `point`.
    func hand(
        _ phase: GesturePhase, on element: MountedElement, moved: Point = Point(0, 0), speed: Point? = nil,
        at point: Point? = nil
    ) {
        element.hear(.hand(phase, moved: moved, speed: speed, at: clock.time, point: point), in: runtime)
    }

    /// Runs `steps` steps of a gesture, each timed: the work they cost, written out with their times as a trend.
    func measure(_ name: String, steps: Int, _ step: (Int) -> Void) -> Work {
        let before = work
        let watch = ContinuousClock()
        var times: [Duration] = []
        for index in 0..<steps {
            times.append(watch.measure { step(index) })
        }
        let done = work - before
        print(Self.line(name, steps: steps, times: times, work: done))
        return done
    }

    /// The trend's line: the build, the steps' median and longest times, and the work.
    private static func line(_ name: String, steps: Int, times: [Duration], work: Work) -> String {
        #if DEBUG
        let build = "debug"
        #else
        let build = "release"
        #endif
        let sorted = times.sorted()
        func milliseconds(_ duration: Duration) -> String {
            let micros = Int((Double(duration.components.seconds) * 1e6
                + Double(duration.components.attoseconds) / 1e12).rounded())
            return "\(micros / 1_000).\(String(micros % 1_000 + 1_000).dropFirst()) ms"
        }
        return "StateUI benchmark \(name) (\(build)): \(steps) steps, median \(milliseconds(sorted[sorted.count / 2])), "
            + "longest \(milliseconds(sorted.last ?? .zero)); \(work)"
    }
}

/// No windows around the tree, and no acts performed: what a bench counts is the tree's.
extension Bench: HostPresenter {
    func presentRendered(touchedChrome: Bool) {}
    func presentFrame(movedChrome: Bool) {}
    func perform(_ call: HostActCall) {}
    func open(link address: String) {}
    func focus(_ element: MountedElement) {}
}

/// The clock a bench winds by hand.
@MainActor
private final class BenchClock: FrameClock {
    var time = 0.0
    var held = false
    var onFrame: ((Double) -> Void)?
    var now: () -> Double { { [unowned self] in time } }
}
