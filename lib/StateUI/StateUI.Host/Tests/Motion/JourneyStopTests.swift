// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A journey stopped mid-way stays where it stood: through the core and the host's channel, across the render
/// the stop's own handler causes and the frames after it.
@MainActor
final class JourneyStopTests: XCTestCase {
    /// A number stopped half-way stands at the half, and so does what the state answers.
    func testAStoppedNumberStaysWhereItStood() throws {
        let (runtime, clock) = start()

        Stage.held.$fade.journey.move(to: 0, .eased(1000, .linear))
        turn(runtime, clock, to: 500)
        let stood = Stage.held.$fade.journey.value
        XCTAssertEqual(stood, 0.5, accuracy: 0.05, "half-way at half the time")

        stop(runtime, clock) { Stage.held.$fade.journey.stop() }

        XCTAssertEqual(Stage.held.$fade.journey.value, stood, accuracy: 0.02, "where it stood")
        XCTAssertEqual(Stage.held.fade, Stage.held.$fade.journey.value, accuracy: 0.001, "and the state answers it")
    }

    /// A themed colour stopped half-way stands at the colour it showed, across the render the stop's own handler
    /// causes - which lays a themed pair the state still kept.
    func testAStoppedColourStaysWhereItStood() throws {
        let (runtime, clock) = start()

        Stage.held.$wash.journey.move(to: Stage.brand, .eased(1000, .linear))
        turn(runtime, clock, to: 500)
        stop(runtime, clock, after: 16) { Stage.held.$wash.journey.stop() }
        let stood = Stage.held.$wash.journey.value
        turn(runtime, clock, to: clock.time + 1500)

        XCTAssertEqual(Stage.held.$wash.journey.value, stood, "where it stood")
        XCTAssertEqual(Stage.held.wash, stood, "and the state answers it")
    }

    /// A themed colour sent somewhere is where the state answers it is going, the moment it is sent.
    func testAMovedColourAnswersWhereItIsGoing() throws {
        let (runtime, clock) = start()

        Stage.held.$wash.journey.move(to: Stage.brand, .eased(1000, .linear))

        XCTAssertEqual(Stage.held.wash, Stage.brand, "the state answers where it is going")
        turn(runtime, clock, to: 1500)
        XCTAssertEqual(lanes(Stage.held.$wash.journey.value), lanes(Stage.brand), "and arrives there")
    }

    /// A colour as the host draws it in the theme in force.
    private func lanes(_ colour: Color) -> [UInt8] {
        StateImage.bytes(of: colour.carried(in: .current))
    }

    /// The stage shown, with nothing moving yet, on a clock the test turns.
    private func start() -> (HostRuntime, TurnedClock) {
        Stage.held = Stage()
        stateUIUseApp(StageApplication())
        let clock = TurnedClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        return (runtime, clock)
    }

    /// The display's frames every 16 ms up to `end`, each followed by a turn, as a host runs them.
    private func turn(_ runtime: HostRuntime, _ clock: TurnedClock, to end: Double) {
        while clock.time < end {
            clock.time += 16
            runtime.displayCycle.frame(now: clock.time)
            runtime.pump.turn()
        }
    }

    /// Stops as the Gallery's Stop does - the stop, then a write the body reads - and runs the frames after it.
    private func stop(_ runtime: HostRuntime, _ clock: TurnedClock, after: Double = 1500, _ stop: () -> Void) {
        stop()
        Stage.held.playing = false
        runtime.pump.turn()
        turn(runtime, clock, to: clock.time + after)
    }
}

/// A clock the test turns by hand.
@MainActor
private final class TurnedClock: FrameClock {
    var time = 0.0
    var held = false
    var onFrame: ((Double) -> Void)?
    lazy var now: () -> Double = { [unowned self] in time }
}

/// The states the stage wears, held by the test.
@MainActor
private struct Stage {
    static var held = Stage()

    static let accent = Color(light: Color("#7C3AED"), dark: Color("#A78BFA"))
    static let brand = Color(light: Color("#EA580C"), dark: Color("#F05037"))

    @State var fade = 1.0
    @State var wash = Stage.accent
    @State var playing = true
}

private struct StageApplication: Application {
    var body: some Scene {
        WindowGroup { StageView(fade: Stage.held.$fade, wash: Stage.held.$wash, playing: Stage.held.$playing) }
    }
}

/// A box whose opacity and colour the states drive, under a caption that reads whether it plays.
private struct StageView: View {
    @Binding var fade: Double
    @Binding var wash: Color
    @Binding var playing: Bool

    var body: some View {
        VStack {
            Text(playing ? "playing" : "stopped")
            ColorBox(.white)
                .opacity($fade)
                .background($wash)
        }
    }
}
