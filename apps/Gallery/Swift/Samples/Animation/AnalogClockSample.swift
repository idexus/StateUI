import StateUI

/// MAUI: VisualElement.Rotation, sprung to real time by a plain Swift loop.
struct AnalogClockSample: SampleContent {
    @State private var ticking = false

    /// The angle each hand is GOING to. Each hand's rotation is ARMED with
    /// this state, so the tree always says where the hand belongs and the
    /// walk is the control's.
    ///
    /// It only ever grows - a flight to 0 from 354 would walk the long way
    /// back - and each tick's target is this angle plus the FORWARD distance
    /// to where the time says the hand should point, so a wrap and a catch-up
    /// after the page returns are the same small spring.
    @State private var sAngle = 0.0
    @State private var mAngle = 0.0
    @State private var hAngle = 0.0

    /// Whether the first reading of this visit has SET the clock. Flying there
    /// from noon would wind the whole day forward in a blur.
    @State private var started = false

    /// Which visit to this page the running loop belongs to. Each load begins
    /// a loop of its own, and this is what tells any earlier one - even one
    /// whose unload never fired - that its page is gone.
    @State private var visit = 0

    /// Where each mark sits and how it is shaped: a bar on the quarters, a
    /// dot on the other hours, at radius 94 from the centre. Written out
    /// because they are layout, not drawing - each is a small box pushed off
    /// centre by margins, with no rotation anywhere.
    static let marks: [(x: Double, y: Double, wide: Double, tall: Double)] = [
        (0, -94, 4, 14), (47, -81.4, 5, 5), (81.4, -47, 5, 5),
        (94, 0, 14, 4), (81.4, 47, 5, 5), (47, 81.4, 5, 5),
        (0, 94, 4, 14), (-47, 81.4, 5, 5), (-81.4, 47, 5, 5),
        (-94, 0, 14, 4), (-81.4, -47, 5, 5), (-47, -81.4, 5, 5),
    ]

    static let id = "analogClock"
    static let title = "Analog clock"
    static let summary = "Real time on springing hands, from a plain Swift loop."

    static let code = """
        @State private var ticking = false
        @State private var sAngle = 0.0
        @State private var mAngle = 0.0
        @State private var hAngle = 0.0
        @State private var started = false
        @State private var visit = 0

        static let marks: [(x: Double, y: Double, wide: Double, tall: Double)] = [
            (0, -94, 4, 14), (47, -81.4, 5, 5), (81.4, -47, 5, 5),
            (94, 0, 14, 4), (81.4, 47, 5, 5), (47, 81.4, 5, 5),
            (0, 94, 4, 14), (-47, 81.4, 5, 5), (-81.4, 47, 5, 5),
            (-94, 0, 14, 4), (-81.4, -47, 5, 5), (-47, -81.4, 5, 5),
        ]

        Grid {
            Border()
                .backgroundColor(Palette.raised)
                .stroke(Palette.outline)
                .strokeShape(.roundRectangle(110))
                .widthRequest(220)
                .heightRequest(220)
                .horizontalOptions(.center)
                .verticalOptions(.center)

            // The marks are laid out, not rotated: a quarter gets a bar,
            // the other hours a dot, each pushed off centre by margins -
            // margin(2x, 2y, 0, 0) shifts a centred view by (x, y).
            ForEach(Array(Self.marks.enumerated()), id: \\.offset) { pair in
                let (x, y, wide, tall) = pair.element
                return BoxView(Palette.outline)
                    .widthRequest(wide)
                    .heightRequest(tall)
                    .margin(2 * x, 2 * y, 0, 0)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
            }

            hand($hAngle, length: 56, width: 6, color: Palette.text)
            hand($mAngle, length: 84, width: 4, color: Palette.text)
            hand($sAngle, length: 96, width: 2, color: Palette.accent)

            Border()
                .backgroundColor(Palette.accent)
                .strokeShape(.roundRectangle(6))
                .widthRequest(12)
                .heightRequest(12)
                .horizontalOptions(.center)
                .verticalOptions(.center)
        }
        .onLoaded {
            // Each visit starts a loop of its own and retires the last. The
            // hands come back at the angles the state kept, and the first
            // reading below ASSIGNS the time rather than flying through
            // everything that passed while the page was away.
            visit += 1
            let mine = visit
            ticking = true
            started = false

            while ticking && visit == mine {
                let lap = ContinuousClock.now
                let time = try await ClockTime.now()

                // Where each hand should POINT, within one turn.
                let second = Double(time.second) * 6
                let minute = Double(time.minute) * 6 + Double(time.second) * 0.1
                let hour = Double(time.hour % 12) * 30
                    + Double(time.minute) * 0.5 + Double(time.second) / 120

                if started {
                    // Advance by the forward distance only, so a wrap never
                    // spins back and a return catches up in one spring. The
                    // angle holds where the last flight was GOING, which is
                    // where the hand now stands, so the arithmetic starts
                    // from it - but the new target is a LOCAL: assigning the
                    // state would snap the hand there and leave the flight
                    // nothing to walk. `async let` starts all three at once;
                    // short and springy, because the snap IS the tick.
                    let toSecond = sAngle + (second - sAngle).forwardTurn
                    let toMinute = mAngle + (minute - mAngle).forwardTurn
                    let toHour = hAngle + (hour - hAngle).forwardTurn

                    async let s: Bool = $sAngle.animateTo(
                        toSecond, length: 260, easing: .springOut)
                    async let m: Bool = $mAngle.animateTo(
                        toMinute, length: 300, easing: .cubicOut)
                    async let h: Bool = $hAngle.animateTo(
                        toHour, length: 300, easing: .cubicOut)
                    _ = try await (s, m, h)
                } else {
                    // The first reading SETS the hands: a plain assignment to
                    // an armed property snaps it, so there is no flight here
                    // and nothing to await.
                    started = true
                    (sAngle, mAngle, hAngle) = (second, minute, hour)
                }

                // Sleep to the NEXT whole second, not for a fixed while: the
                // reading said how far into this one it was, the lap clock
                // says what the flights used, and the difference is what
                // keeps every tick landing just past the boundary.
                let used = lap.duration(to: .now)
                let wait = .milliseconds(1000 - time.millisecond) - used

                if wait > .milliseconds(20) {
                    try await Task.sleep(for: wait)
                }
            }
        }
        .onUnloaded {
            ticking = false
        }

        /// One hand: bottom at the face's centre, rotating about that bottom.
        /// The bottom margin equals the length, so centring the margin box puts
        /// the hand's foot exactly on the middle - plain layout, no transforms.
        /// `.rotation(angle)` ARMS the rotation with the state handed in, which
        /// is what makes a flight on that state turn this hand.
        private func hand(
            _ angle: Binding<Double>, length: Double, width: Double, color: Color
        ) -> some View {
            BoxView(color)
                .rotation(angle)
                .widthRequest(width)
                .heightRequest(length)
                .margin(0, 0, 0, length)
                .anchorY(1)
                .horizontalOptions(.center)
                .verticalOptions(.center)
        }

        /// The forward distance to an angle within one turn, 0 up to but not
        /// 360 - the minute hand at 354 asked to show 0 steps +6, never -354.
        extension Double {
            var forwardTurn: Double {
                let step = truncatingRemainder(dividingBy: 360)
                return step >= 0 ? step : step + 360
            }
        }
        """

    var content: Element {
        Grid {
            Border()
                .backgroundColor(Palette.raised)
                .stroke(Palette.outline)
                .strokeThickness(2)
                .strokeShape(.roundRectangle(110))
                .widthRequest(220)
                .heightRequest(220)
                .horizontalOptions(.center)
                .verticalOptions(.center)

            ForEach(Array(Self.marks.enumerated()), id: \.offset) { pair in
                let (x, y, wide, tall) = pair.element
                return BoxView(Palette.outline)
                    .widthRequest(wide)
                    .heightRequest(tall)
                    .margin(2 * x, 2 * y, 0, 0)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
            }

            hand($hAngle, length: 56, width: 6, color: Palette.text)
            hand($mAngle, length: 84, width: 4, color: Palette.text)
            hand($sAngle, length: 96, width: 2, color: Palette.accent)

            Border()
                .backgroundColor(Palette.accent)
                .stroke(.transparent)
                .strokeShape(.roundRectangle(6))
                .widthRequest(12)
                .heightRequest(12)
                .horizontalOptions(.center)
                .verticalOptions(.center)
        }
        .horizontalOptions(.center)
        .onLoaded {
            // Each visit starts a loop of its own and retires the last. The
            // hands come back at the angles the state kept, and the first
            // reading below ASSIGNS the time rather than flying through
            // everything that passed while the page was away.
            visit += 1
            let mine = visit
            ticking = true
            started = false

            while ticking && visit == mine {
                let lap = ContinuousClock.now
                let time = try await ClockTime.now()

                // Where each hand should POINT, within one turn.
                let second = Double(time.second) * 6
                let minute = Double(time.minute) * 6 + Double(time.second) * 0.1
                let hour = Double(time.hour % 12) * 30
                    + Double(time.minute) * 0.5 + Double(time.second) / 120

                if started {
                    // Advance by the forward distance only, so a wrap never
                    // spins back and a return catches up in one spring. The
                    // angle holds where the last flight was GOING, which is
                    // where the hand now stands, so the arithmetic starts from
                    // it - but the new target is a LOCAL: assigning the state
                    // would snap the hand there and leave the flight nothing to
                    // walk. `async let` starts all three at once; short and
                    // springy, because the snap IS the tick.
                    let toSecond = sAngle + (second - sAngle).forwardTurn
                    let toMinute = mAngle + (minute - mAngle).forwardTurn
                    let toHour = hAngle + (hour - hAngle).forwardTurn

                    async let s: Bool = $sAngle.animateTo(
                        toSecond, length: 260, easing: .springOut)
                    async let m: Bool = $mAngle.animateTo(
                        toMinute, length: 300, easing: .cubicOut)
                    async let h: Bool = $hAngle.animateTo(
                        toHour, length: 300, easing: .cubicOut)
                    _ = try await (s, m, h)
                } else {
                    // The first reading SETS the hands: a plain assignment to
                    // an armed property snaps it, so there is no flight here
                    // and nothing to await.
                    started = true
                    (sAngle, mAngle, hAngle) = (second, minute, hour)
                }

                let used = lap.duration(to: .now)
                let wait = .milliseconds(1000 - time.millisecond) - used

                if wait > .milliseconds(20) {
                    try await Task.sleep(for: wait)
                }
            }
        }
        .onUnloaded {
            ticking = false
        }
    }

    var notes: Element? {
        VStack {
            Label("The time comes from the platform - ClockTime.now() - and the wait is "
                + "plain Task.sleep, which resumes on time on every platform.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Every tick sleeps to the NEXT whole second rather than for a "
                + "fixed while - the reading carries milliseconds, so the spring "
                + "lands just past each boundary instead of drifting across one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Each hand is a box whose bottom sits at the face's centre - "
                + "the bottom margin equals its length, so centring the margin "
                + "box puts the foot on the middle - and anchorY(1) makes that "
                + "foot the pivot.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A hand's rotation is ARMED - .rotation($sAngle) rather than "
                + ".rotation(sAngle) - so a tick is that state moving: the angle "
                + "is given its new target as the walk begins, and the hand "
                + "springs there. Reading sAngle answers where the hand is "
                + "GOING, which is exactly what the next tick's arithmetic "
                + "wants - it adds the FORWARD distance to the time, so the "
                + "angles only grow and the hands never spin back.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Leaving this page stops the loop, and coming back starts a "
                + "fresh one. The hands are drawn wherever the angles were left, "
                + "because the angles are state, and the first reading ASSIGNS "
                + "the time instead of flying to it - a plain write snaps - so "
                + "the clock is right at once, with no winding through what "
                + "passed.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One hand: bottom at the face's centre, rotating about that bottom.
    /// The bottom margin equals the length, so centring the margin box puts
    /// the hand's foot exactly on the middle - plain layout, no transforms.
    /// `.rotation(angle)` ARMS the rotation with the state handed in, which is
    /// what makes a flight on that state turn this hand.
    private func hand(
        _ angle: Binding<Double>, length: Double, width: Double, color: Color
    ) -> some View {
        BoxView(color)
            .rotation(angle)
            .widthRequest(width)
            .heightRequest(length)
            .margin(0, 0, 0, length)
            .anchorY(1)
            .horizontalOptions(.center)
            .verticalOptions(.center)
    }
}

/// The forward distance to an angle within one turn, 0 up to but not 360.
///
/// What lets a hand's angle only ever grow: the minute hand at 354 asked to
/// show 0 steps +6, never -354. On the difference between two angles in
/// degrees.
extension Double {
    var forwardTurn: Double {
        let step = truncatingRemainder(dividingBy: 360)
        return step >= 0 ? step : step + 360
    }
}
