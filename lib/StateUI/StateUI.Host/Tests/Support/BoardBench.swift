// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A scope whose card and detail are tied by one key, each coming and going by a transition, over a line a state
/// the host carries moves and a hand takes, and a row whose two views stand half its room apart.
private struct BoardPage: View {
    var body: some View {
        VStack {
            Rectangle()
                .translationX(BoardBench.lineShift.projectedValue)
                .interaction(
                    .value(BoardBench.lineShift.projectedValue, input: .translation(.horizontal))
                        .range(0...300).snaps([150]).release(.nearest(.eased(.milliseconds(160), curve: .linear))))
            if BoardBench.cardShown.wrappedValue {
                Text("card")
                    .transition(Transition(enter: .opacity, exit: .opacity.combined(with: .translation(y: 12))))
                    .id("card")
            } else {
                // In a holder of its own: of one id and one kind among the same siblings, it would be the card itself.
                HStack {
                    Text("detail")
                        .transition(.symmetric(.opacity))
                        .id("card")
                }
            }
            MotionLayout([0, 1], parameters: BoardBench.dealt.projectedValue) { Text("item \($0)") } placements: {
                room, _ in
                [0, 1].map { Placement(Rect(x: Double($0) * room.bounds.width / 2, y: 0, width: 10, height: 10)) }
            }
            .layoutBodies(.onChange(response: .milliseconds(160)))
        }
        .motion(.eased(.milliseconds(200), curve: .linear))
        .aim(BoardBench.scope)
    }
}

private struct BoardApplication: Application {
    var body: some Scene { WindowGroup { BoardPage() } }
}

/// The board over the core and the host layer on a clock wound by hand, every native half it made held weakly.
@MainActor
final class BoardBench {
    /// Whether the board shows its card - its detail otherwise - how far its line is moved, and the aim on its scope.
    static let cardShown = State(wrappedValue: true)
    static let lineShift = State(wrappedValue: 0.0, motion: .eased(.milliseconds(200), curve: .linear))
    static let scope = Aim(VStack.self)
    static let dealt = State(wrappedValue: 0.0, motion: .none)

    /// A native half held weakly: alive only while something still keeps it.
    final class Made {
        weak var view: NoView?
        init(_ view: NoView) { self.view = view }
    }

    /// The board's states and its aim, for a test holding the bench: the board stands before they are used.
    var shown: State<Bool> { Self.cardShown }
    var shift: State<Double> { Self.lineShift }
    var scope: Aim<VStack> { Self.scope }

    let clock = WoundClock()
    var runtime: HostRuntime?
    var made: [Made] = []
    var reducesMotion = false

    init() {
        Self.cardShown.wrappedValue = true
        Self.lineShift.projectedValue.journey.snap(to: 0)
        BoardApplication.register()
        runtime = HostRuntime(
            clock: clock, reducesMotion: { [unowned self] in reducesMotion },
            makeNative: { [unowned self] _ in
                let view = NoView()
                view.keepsExits = true
                view.animatesProperties = true
                made.append(Made(view))
                return view
            }, log: { _ in })
        open()
    }

    /// A window made anew shows the board, its row told a room.
    func open() {
        runtime?.connectWindow()
        step(0)
        room(300)
        step(0)
    }

    /// The row is told a room `width` wide, as a toolkit laying it out anew tells it.
    func room(_ width: Double) {
        guard let runtime else { return }

        row?.reportFrame([0, 0, width, 200, 0, 0, 0, 0], in: runtime)
    }

    /// The user closes the board's window.
    func close() {
        guard let window = runtime?.tree.root?.windows.first else { return }

        runtime?.userClosed(window)
        step(0)
    }

    /// A turn, `milliseconds` later, and the frame of that time.
    func step(_ milliseconds: Double) {
        clock.time += milliseconds
        runtime?.pump.turn()
        runtime?.displayCycle.frame(now: clock.time)
        runtime?.pump.turn()
    }

    /// Frames until everything that moves has landed and every layout window is over.
    func rest() { for _ in 0..<6 { step(250) } }

    /// The line, the scope holding it, and the row with where its views are shown across.
    var line: MountedElement? { runtime?.tree.root?.first(type: .rectangle) }
    var holder: MountedElement? { line?.parent }
    var row: MountedElement? { runtime?.tree.root?.first(type: .motionLayout) }
    var dealt: [Double] { row?.placement?.placements.map(\.bounds.x) ?? [] }

    /// The hand over the line as the sessions hear it, and the frame after it.
    func hand(_ phase: GesturePhase, moved: Point = .zero, velocity: Point = .zero) {
        guard let runtime, let line else { return }

        runtime.interactions.hand(phase, moved: moved, speed: velocity, on: line)
        step(0)
    }

    /// The native halves still alive.
    var halves: Int { made.filter { $0.view != nil }.count }

    /// What stands held: the runtime's own counts, and the core's elements, runs and movements.
    var held: String {
        let tally = HostBoundary.tally
        return "\(runtime?.holdings.description ?? "no runtime"); elements \(tally.alive), runs \(tally.runs), "
            + "movements \(MotionRun.open), halves \(halves)"
    }
}
