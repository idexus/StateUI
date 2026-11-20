// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A motion layout on a runtime with nothing native behind it: mounted as a window's page, told its room as a
/// toolkit tells it, and moved by the hand as the host layer's sessions hear it - each report followed by a display
/// frame on a clock the bench winds.
@MainActor
final class LayoutBench {
    let clock = WoundClock()
    private(set) var runtime: HostRuntime?

    /// Mounts the layout `tree` describes, tells it `room` - none for a layout its toolkit has not laid out yet -
    /// and runs the frames that lay it out; where it puts its views.
    @discardableResult
    func laid(
        _ tree: @escaping () -> Node, room: Rect? = Rect(x: 10, y: 20, width: 300, height: 200),
        file: StaticString = #filePath, line: UInt = #line
    ) -> [Placement] {
        mounted(tree)
        guard let runtime, let layout else {
            XCTFail("no layout was mounted", file: file, line: line)
            return []
        }

        if let room { layout.reportFrame([room.x, room.y, room.width, room.height, 0, 0, 0, 0], in: runtime) }
        cycle()
        cycle()
        return placed
    }

    /// Mounts the views `tree` describes as a window's page, whatever they are, and runs a frame.
    func mounted(_ tree: @escaping () -> Node) {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
        benchTree = tree
        Renderer.shared.setApplication(BenchApplication())
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        self.runtime = runtime
        runtime.connectWindow()
        runtime.pump.turn()
        cycle()
    }

    /// The first element of `type` the tree mounted.
    func element(_ type: NodeType) -> MountedElement? {
        runtime?.tree.root?.first(type: type)
    }

    /// The journey of the first state `element`'s hand moves, as its channel carries it.
    func journey(movedOn element: MountedElement) -> HostJourney? {
        guard let state = element.interactionProgram?.values.first?.state else { return nil }
        return runtime?.stateChannels.standing(state)
    }

    /// The layout's element, as the tree mounted it: the first, where the tree holds several.
    var layout: MountedElement? { layouts.first }

    /// Every motion layout the tree mounted, in the tree's order.
    var layouts: [MountedElement] {
        var found: [MountedElement] = []
        func walk(_ element: MountedElement) {
            if element.type == .motionLayout { found.append(element) }
            element.children.forEach(walk)
        }
        runtime?.tree.root.map(walk)
        return found
    }

    /// The journey of the layout's parameters as their channel carries it, a lane an axis: where each stands,
    /// where it is going and how fast.
    var journey: HostJourney? {
        guard let runtime, let state = layout?.driven[.parameters]?.state else { return nil }
        return runtime.stateChannels.standing(state)
    }

    /// Describes the tree again, as a write of a state its page read does.
    func render() {
        redescribed.wrappedValue += 1
        runtime?.pump.turn()
    }

    /// One display frame, sixteen milliseconds on: what the hand `says` is heard at its start, as a frame says the
    /// reports gathered since the last.
    func cycle(on element: MountedElement? = nil, _ says: (HostRuntime, MountedElement) -> Void = { _, _ in }) {
        guard let runtime else { return }

        clock.time += 16
        if let layout = element ?? layout { says(runtime, layout) }
        runtime.displayCycle.frame(now: clock.time)
        runtime.pump.turn()
    }

    /// `count` display frames.
    func frames(_ count: Int = 30) {
        for _ in 0..<count { cycle() }
    }

    /// Lets the runs the frames started go on: the handlers a rest tells, each to its first wait.
    func settle() async {
        for _ in 0..<50 {
            await Task.yield()
            runtime?.pump.turn()
            if Renderer.shared.resumesPending == 0, UIThreadExecutor.shared.pendingCount == 0 { break }
        }
    }

    /// Where the layout puts its views now, in the items' order, as its run wrote it.
    var placed: [Placement] { layout?.layoutProgram?.run?().placements ?? [] }

    /// What the layout last answered its host.
    var answer: HostLayoutAnswer { layout?.layoutProgram?.answered() ?? HostLayoutAnswer() }

    /// Says the layout another room, as a toolkit laying it out anew does.
    func room(_ width: Double, _ height: Double) {
        guard let runtime, let layout else { return }

        layout.reportFrame([0, 0, width, height, 0, 0, 0, 0], in: runtime)
    }

    /// The hand over the layout as the sessions hear it - its phase, how far it moved what is under it since its
    /// last report, and the speed it lets go at, a second - and a frame after it.
    func hand(
        _ phase: GesturePhase, moved: Point = .zero, velocity: Point = .zero, on element: MountedElement? = nil
    ) {
        cycle(on: element) { runtime, layout in
            runtime.interactions.hand(phase, moved: moved, speed: velocity, on: layout)
        }
    }

    /// Two fingers over the layout as the sessions hear them - their phase, the scale and the degrees since their
    /// last report, and their speed as they lift - and a frame after them.
    func pinch(_ phase: GesturePhase, scale: Double = 1, degrees: Double = 0, velocity: Point = .zero) {
        cycle { runtime, layout in
            runtime.interactions.fingers(phase, scale: scale, degrees: degrees, speed: velocity, on: layout)
        }
    }

    /// A wheel's whole notches over the layout - across and down - and a frame after them.
    func step(_ notches: Point) {
        cycle { runtime, layout in runtime.interactions.notches(notches, on: layout) }
    }
}

/// The tree the bench's page shows, and what a render of it again writes.
@MainActor private var benchTree: (() -> Node)?
@MainActor private let redescribed = State(wrappedValue: 0)

private struct BenchPage: View {
    var body: some View {
        _ = redescribed.wrappedValue
        return AnyView(node: benchTree?() ?? Grid {}.node)
    }
}

private struct BenchApplication: Application {
    var body: some Scene { WindowGroup { BenchPage() } }
}

extension State where Value: Walked {
    /// The state's binding, the state moving under `motion` from now on: how a test gives a layout's parameters
    /// their law, which is their state's own.
    @MainActor
    func traveling(_ motion: Motion) -> Binding<Value> {
        try? projectedValue.journey.setMotion(motion)
        return projectedValue
    }
}
