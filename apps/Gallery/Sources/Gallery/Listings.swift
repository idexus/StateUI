// The code each example shows, by name - written by SampleListingsTests from the regions the
// sources mark `// listing: <name>`. Change the marked code, never this file.

/// The code each example shows, by the name its region is marked with.
enum Listings {
    /// Every listing, by name: the code every host runs, and a host's own where a host's build shows it.
    static let all: [String: String] = shared.merging(ofHosts) { shared, _ in shared }

    /// The code every host runs, by name.
    private static let shared: [String: String] = [
        "AboutScene": #"""
        // Sources/Samples/Windows/AboutScene.swift
        extension WindowType where Value == Void {
            /// About the gallery: one window for the whole application.
            static let about = WindowType("gallery.about")
        }

        /// About the gallery: one window for the whole application, in a scene of its
        /// own. It belongs to no other scene, so it stands while the gallery's windows
        /// open and close, and `application.openWindow(.about)` opens it from any of
        /// them - or answers `WindowError.alreadyOpen`. See `ScenesSample`.
        struct AboutScene: Scene {
            var body: some Scene {
                Window(.about) { AboutPage() }
            }
        }
        """#,
        "AccessibilitySettingsSample": #"""
        // Sources/Samples/Environment/AccessibilitySettingsSample.swift
        /// The settings, as the host last reported them.
        @Environment(\.device) var device

        var body: some View {
            let settings = device.accessibility

            return VStack {
                // Each setting is read here, so a change to one builds this
                // closure.
                DebugInfoLabel()

                Text("less motion · \(settings.reducesMotion ? "on" : "off")")
                Text("more contrast · \(settings.prefersHigherContrast ? "on" : "off")")
                Text("screen reader · \(settings.isScreenReaderOn ? "on" : "off")")
                Text("words · \(Int((settings.textScale * 100).rounded())) %")

                // A rule drawn stronger where the user asked for more contrast.
                Rectangle()
                    .fill(settings.prefersHigherContrast ? Palette.accent : Palette.outline)
                    .height(settings.prefersHigherContrast ? 3 : 1)
                    .isAccessibilityHidden(true)
            }
        }
        """#,
        "AcrossList": #"""
        // Sources/Samples/Collections/ItemsViewSample.swift
        static let tags = [
            "State", "Binding", "Journey", "Engine", "Motion", "Placement", "Environment", "Scene", "Window",
            "Page", "Aim", "Style", "Theme", "Gesture", "Frame", "Conversion", "Sample", "Identity", "Session",
            "Persistence",
        ]

        var body: some View {
            VStack {
                DebugInfoLabel()

                // A row: one card beside another, each as wide as it says.
                ItemsView(1...200) { number in
                    Text("Card \(number)")
                        .width(120)
                }
                .itemsLayout(.row(spacing: 8))
                .height(80)

                // Each tag as wide as its word.
                ItemsView(Self.tags) { tag in
                    Text(tag)
                }
                .itemsLayout(.row(spacing: 8))
                .height(40)
            }
        }
        """#,
        "AimSample": #"""
        // Sources/Samples/State/AimSample.swift
        @State private var text = ""

        /// The control an act is about. `.aim` puts the element's own identity in
        /// here as the differ walks, so nothing is named and nothing collides.
        @Aim(TextField.self) private var field

        /// A second one, to show that two of them are two controls - and that an
        /// act aims at exactly the view it was put on.
        @Aim(TextField.self) private var note

        /// What the last act did, written by the handler that reads the aim: the
        /// differ fills an aim as it WALKS, which is after the body that would read
        /// it was built.
        @State private var says = "Press a button, and it says which view it reached."

        var body: some View {
            VStack {
                // `says` is written by the handlers and read here, so this is the
                // closure a press rebuilds. The two fields are handed a binding
                // and an aim, neither of which reads anything.
                DebugInfoLabel()

                TextField($text)
                    .placeholder("The first field")
                    .aim(field)

                TextField()
                    .placeholder("The second field")
                    .aim(note)

                HStack {
                    // Printing an aim says where it is: the element identity the
                    // differ settled - "#12" - or the name an .id() gave it. Read
                    // in the HANDLER, because the walk fills it after the body
                    // that describes the view was built.
                    Button("Focus the first")
                        .onClicked(.ignoreWhileRunning) {
                            try await field.focus()
                            says = "focused \(field)"
                        }

                    Button("Focus the second")
                        .onClicked(.ignoreWhileRunning) {
                            try await note.focus()
                            says = "focused \(note)"
                        }
                }

                // Each aim reaches its own field: letting go of both is two acts.
                Button("Let go")
                    .onClicked(.ignoreWhileRunning) {
                        try await field.unfocus()
                        try await note.unfocus()
                        says = "let go of \(field) and \(note)"
                    }

                Text(says)
            }
        }
        """#,
        "AnalogClockSample": #"""
        // Sources/Samples/Animation/AnalogClockSample.swift
        @State private var ticking = false

        /// Whether the first reading of this visit has SET the clock. Traveling
        /// there from where the hands stand - noon, on the first visit - would
        /// sweep them round in a blur.
        @State private var started = false

        /// Which visit to this page the running loop belongs to. The page leaving
        /// ends its loop: its sleep throws. `visit` tells an earlier loop on a
        /// covered copy of this page that a newer visit took over.
        @State private var visit = 0

        /// The angle each hand is GOING to. Each hand's rotation is DRIVEN by
        /// this state, so the host turns the hand on its own frames and a tick
        /// costs no render at all.
        ///
        /// It only ever grows - a movement to 0 from 354 would turn the long way
        /// back - and each tick's target is this angle plus the FORWARD distance
        /// to where the time says the hand should point, so a wrap and the
        /// catch-up after a late tick are the same short movement.
        @State private var sAngle = 0.0
        @State private var mAngle = 0.0
        @State private var hAngle = 0.0

        /// Where each mark sits and how it is shaped: a bar on the quarters, a
        /// dot on the other hours, at radius 94 from the center. Written out
        /// because they are layout, not drawing - each is a small box pushed off
        /// center by margins, with no rotation anywhere.
        static let marks: [(x: Double, y: Double, wide: Double, tall: Double)] = [
            (0, -94, 4, 14), (47, -81.4, 5, 5), (81.4, -47, 5, 5),
            (94, 0, 14, 4), (81.4, 47, 5, 5), (47, 81.4, 5, 5),
            (0, 94, 4, 14), (-47, 81.4, 5, 5), (-81.4, 47, 5, 5),
            (-94, 0, 14, 4), (-81.4, -47, 5, 5), (-47, -81.4, 5, 5),
        ]

        var body: some View {
            Grid {
                // The hands are driven, and nothing here reads them: this stays
                // at one build while the clock runs.
                DebugInfoLabel()

                ZStack().style(.card)
                    .stroke(Palette.accent)
                    .lineWidth(3)
                    .width(220)
                    .height(220)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)

                // The marks are laid out, not rotated: a quarter gets a bar,
                // the other hours a dot, each pushed off center by margins -
                // margin(2x, 2y, 0, 0) shifts a centered view by (x, y).
                ForEach(Array(Self.marks.enumerated()), id: \.offset) { pair in
                    let (x, y, wide, tall) = pair.element
                    return Rectangle()
                        .fill(Palette.accent)
                        .opacity(wide == tall ? 0.5 : 1)
                        .width(wide)
                        .height(tall)
                        .horizontalAlignment(.center)
                        .verticalAlignment(.center)
                }

                hand($hAngle, length: 56, width: 6, color: Palette.text)
                hand($mAngle, length: 84, width: 4, color: Palette.text)
                hand($sAngle, length: 96, width: 2, color: Palette.brand)

                ZStack().style(.card)
                    .stroke(.transparent)
                    .width(12)
                    .height(12)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
            }
            .horizontalAlignment(.fill)
            .onCreated {
                // The page leaving ends its loop: its sleep throws. `visit` tells
                // an earlier loop on a covered copy of this page that a newer
                // visit took over. The hands come back at the angles the state
                // kept, and the first reading below ASSIGNS the time rather than
                // flying through everything that passed while the page was away.
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
                    let hours = Double(time.hour % 12) * 30
                    let minutesPast = Double(time.minute) * 0.5
                    let secondsPast = Double(time.second) / 120
                    let hour = hours + minutesPast + secondsPast

                    if started {
                        // Advance by the forward distance only, so a wrap never
                        // spins back and a late tick catches up in one movement.
                        // The STATE is where the last movement was going, which
                        // is where the hand belongs now, so the arithmetic starts
                        // from it - never from the journey's value, which is
                        // wherever the host had got to when this reading came
                        // in. All three start as they are sent, and are awaited
                        // after; each is short, because the movement IS the tick.
                        let atSecond = sAngle
                        let atMinute = mAngle
                        let atHour = hAngle

                        let toSecond = atSecond + (second - atSecond).forwardTurn
                        let toMinute = atMinute + (minute - atMinute).forwardTurn
                        let toHour = atHour + (hour - atHour).forwardTurn

                        let s = $sAngle.journey.move(to: toSecond, .eased(.milliseconds(260), .backOut))
                        let m = $mAngle.journey.move(to: toMinute, .eased(.milliseconds(300), .cubicOut))
                        let h = $hAngle.journey.move(to: toHour, .eased(.milliseconds(300), .cubicOut))
                        try await s.arrived()
                        try await m.arrived()
                        try await h.arrived()
                    } else {
                        // The first reading SETS the hands: `value` is written, and
                        // the state to match, so nothing travels and nothing is awaited.
                        started = true
                        ($sAngle.journey.value, $mAngle.journey.value, $hAngle.journey.value) = (second, minute, hour)
                        (sAngle, mAngle, hAngle) = (second, minute, hour)
                    }

                    // Sleep to the NEXT whole second, not for a fixed while: the
                    // reading said how far into this one it was, the lap clock
                    // says what the movements used, and the difference is what
                    // keeps every tick landing just past the boundary.
                    let used = lap.duration(to: .now)
                    let wait = .milliseconds(1000 - time.millisecond) - used

                    if wait > .milliseconds(20) {
                        try await Task.sleep(for: wait)
                    }
                }
            }
            .onDestroying {
                ticking = false
            }
        }

        /// One hand: bottom at the face's center, rotating about that bottom.
        /// The bottom margin equals the length, so centering the margin box puts
        /// the hand's foot exactly on the middle - plain layout, no transforms.
        /// `.rotation(angle)` DRIVES the rotation from the state handed in, which
        /// is what makes a movement on that state turn this hand - on the host's
        /// own frames, with nothing described in between.
        private func hand(
            _ angle: Binding<Double>,
            length: Double, width: Double, color: Color
        ) -> some View {
            Rectangle()
                .fill(color)
                .rotation(angle)
                .width(width)
                .height(length)
                .pivotY(1)
                .horizontalAlignment(.center)
                .verticalAlignment(.center)
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
        """#,
        "AnimatedInputSample": #"""
        // Sources/Samples/Animation/AnimatedInputSample.swift
        /// The TOP slider's value. The caption above the slider PRINTS it, which
        /// makes the closure it sits in a reader - so every report the thumb
        /// makes builds that closure again, and nothing around it.
        @State private var volume = 0.2   // printed by this body: a reader

        /// The BOTTOM slider's value. Nothing here reads it: it is handed on as
        /// `$level` - to the slider, and to the caption's own conversion - and a
        /// binding makes no reader.
        ///
        /// Its JOURNEY is the second half of what this page shows: `level` is
        /// where the value is GOING and `$level.journey.value` where it HAS GOT
        /// TO, so a caption converted off the journey counts its way along it
        /// where one converted from the state would jump to the destination at
        /// once.
        @State private var level = 0.2   // handed on: no reader

        /// The stepper's value, declared the same way. Its caption matters more
        /// than the slider's: on some platforms a Stepper draws two buttons and
        /// no number, and there the caption above it is what shows the value.
        @State private var count = 3.0

        var body: some View {
            // Each part is a closure of its own and takes its own build reading,
            // which is what tells them apart.
            VStack {
                VStack {
                    Text("A get")

                    // A GET. The label below prints `volume`, which makes THIS
                    // closure a reader of it - so every report the thumb makes
                    // builds it.
                    DebugInfoLabel()

                    Text("volume · \(percent(volume))")

                    Slider($volume)
                        .minimum(0)
                        .maximum(1)

                    button("Send the top one") {
                        // An assignment sends the thumb there under the element's
                        // law, and costs the one render this line asks for.
                        volume = volume < 0.5 ? 1 : 0
                    }
                }

                VStack {
                    Text("A binding")

                    DebugInfoLabel()

                    // A CONVERTED TEXT: an engine works it out from the same image
                    // the thumb is walking, on the display's frames, so the words
                    // keep up with the movement and cost no render.
                    Text()
                        .text($level.journey.convert { "level · \(Int(($0.value * 100).rounded()))%" })

                    // THE SAME DECLARATION as above, and the same spelling: what
                    // differs is that nothing here reads `level` at build.
                    Slider($level)
                        .minimum(0)
                        .maximum(1)

                    button("Send the bottom one") {
                        try await $level.journey.move(to: level < 0.5 ? 1 : 0,
                                                   .eased(.milliseconds(900), .cubicInOut)).arrived()
                    }
                }

                VStack {
                    DebugInfoLabel()

                    Text()
                        .text($count.journey.convert { "count · \(Int($0.value.rounded()))" })

                    Stepper($count)
                        .minimum(0)
                        .maximum(20)
                        .step(1)
                        .horizontalAlignment(.start)

                    button("Send the stepper to 12") {
                        try await $count.journey.move(to: 12, .eased(.milliseconds(800), .cubicOut)).arrived()
                    }
                }
            }
        }

        /// Whole percent, written by hand - a formatter is Foundation.
        private func percent(_ value: Double) -> String {
            "\(Int((value * 100).rounded()))%"
        }

        /// One of the buttons, all of which look the same.
        private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
            Button(caption)
                .onClicked(.cancelPrevious, act)
        }
        """#,
        "AnimatedPropertySample": #"""
        // Sources/Samples/Animation/AnimatedPropertySample.swift
        @State private var wide = false

        @State private var panelColor = AppColors.lineDark
        @State private var panelHeight = 90.0
        @State private var panelPadding = Insets(16)
        @State private var captionColor = AppColors.ink
        @State private var captionSize = 17.0

        var body: some View {
            VStack {
                // Every property below is driven, and `wide` is read by the
                // handler alone - so this stands at one build while five of them
                // travel at once.
                DebugInfoLabel()

                ZStack {
                    Grid {
                        Text("A property, carried")
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)
                    }
                }
                .style(.card)
                .height($panelHeight)
                .stroke(.transparent)

                HStack {
                    button("Color") {
                        try await $panelColor.journey.move(to: AppColors.swiftOrangeDeep, .eased(.milliseconds(500))).arrived()

                        // The caption sits on the violet field inside the panel
                        // rather than on the panel itself, so what it goes to is
                        // white, the color that reads on that field.
                        try await $captionColor.journey.move(to: AppColors.white, .eased(.milliseconds(500))).arrived()
                    }

                    button("Size") {
                        wide.toggle()
                        try await $panelHeight.journey.move(to: wide ? 160 : 90,
                                                         .eased(.milliseconds(400), .cubicInOut)).arrived()
                    }

                    button("Padding") {
                        try await $panelPadding.journey.move(to: Insets(48), .eased(.milliseconds(400))).arrived()
                        try await $panelPadding.journey.move(to: Insets(16), .eased(.milliseconds(400))).arrived()
                    }
                }
                .horizontalAlignment(.center)

                HStack {
                    button("Text size") {
                        try await $captionSize.journey.move(to: 28, .eased(.milliseconds(400), .cubicOut)).arrived()
                        try await $captionSize.journey.move(to: 17, .eased(.milliseconds(400), .cubicIn)).arrived()
                    }

                    button("Back") {
                        // EVERYTHING THE OTHER BUTTONS LEAVE CHANGED - the height
                        // and the two colors. The padding and the text size send
                        // themselves back, so there is nothing here for them; and
                        // `wide` is put right with the height, or the next press
                        // of Size would ask for the value it already has.
                        wide = false

                        try await $panelHeight.journey.move(to: 90, .eased(.milliseconds(400), .cubicInOut)).arrived()
                        try await $panelColor.journey.move(to: AppColors.lineDark, .eased(.milliseconds(400))).arrived()
                        try await $captionColor.journey.move(to: AppColors.ink, .eased(.milliseconds(400))).arrived()
                    }
                }
                .horizontalAlignment(.center)
            }
        }

        /// One of the buttons, all of which look the same.
        private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
            Button(caption)
                .onClicked(.cancelPrevious, act)
        }
        """#,
        "AnimationSample": #"""
        // Sources/Samples/Animation/AnimationSample.swift
        @State private var curve = Easing.linear

        /// The four values the card is drawn from, one per thing a button moves.
        ///
        /// Each is DRIVEN on the card below - the property is read off the state
        /// on the host's own frames rather than described - so a four-hundred
        /// millisecond journey costs no renders at all. A card that names none
        /// of them has nothing to move.
        @State private var fade = 1.0
        @State private var shift = 0.0
        @State private var scale = 1.0
        @State private var angle = 0.0

        static let curves: [Easing] = [.linear, .cubicInOut, .bounceOut, .backOut]

        var body: some View {
            VStack {
                // A curve chosen builds this closure once; the four journeys are
                // the host's, so a button pressed builds nothing.
                DebugInfoLabel()

                ZStack {
                    Text("Animate me")
                }
                .style(.card)
                // Four DRIVEN properties. The host reads each off the state it
                // moves, so none is in a patch after the one that registers it.
                .opacity($fade)
                .translationX($shift)
                .scale($scale)
                .rotation($angle)
                .stroke(Palette.accent)
                .horizontalAlignment(.center)

                Picker(Self.curves, selection: $curve, caption: Self.name)
                    .placeholder("Easing")

                HStack {
                    // A movement answers whether it ran to the END. Stop says
                    // false - and a second press cancels this run, the buttons
                    // passing through `.cancelPrevious` - so the way back is not taken over
                    // whatever happened instead, which is what lets Stop leave the
                    // card where it stood.
                    button("Fade") {
                        let landed = try await $fade.journey.move(to: 0.1, .eased(.milliseconds(400), curve)).arrived()
                        if landed { try await $fade.journey.move(to: 1, .eased(.milliseconds(400), curve)).arrived() }
                    }

                    // ONE movement, because the card only ever moves sideways. A
                    // diagonal would be a second state on translationY, sent
                    // beside this one before either is awaited, so the two land
                    // together.
                    button("Move") {
                        let landed = try await $shift.journey.move(to: 60, .eased(.milliseconds(400), curve)).arrived()
                        if landed { try await $shift.journey.move(to: 0, .eased(.milliseconds(400), curve)).arrived() }
                    }

                    button("Scale") {
                        let landed = try await $scale.journey.move(to: 1.4, .eased(.milliseconds(400), curve)).arrived()
                        if landed { try await $scale.journey.move(to: 1, .eased(.milliseconds(400), curve)).arrived() }
                    }

                    // A movement goes TO a value, never BY one, so a full turn is
                    // the author's arithmetic. The state is where the last one was
                    // headed, which is what makes the next press carry on from
                    // there rather than start over.
                    button("Spin") {
                        try await $angle.journey.move(to: angle + 360, .eased(.milliseconds(700), curve)).arrived()
                    }
                }
                .horizontalAlignment(.center)

                // Whichever of them is moving; a state standing still is
                // unaffected. Each stop leaves the value where it had got to, so
                // the card stays exactly where the user saw it stop.
                button("Stop") {
                    $fade.journey.stop()
                    $shift.journey.stop()
                    $scale.journey.stop()
                    $angle.journey.stop()
                }
                .horizontalAlignment(.center)
            }
        }

        /// One of the buttons, all of which look the same.
        private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
            Button(caption)
                .onClicked(.cancelPrevious, act)
        }

        /// What the picker calls a curve.
        static func name(_ curve: Easing) -> String {
            switch curve {
            case .cubicInOut: "Cubic in-out"
            case .bounceOut: "Bounce out"
            case .backOut: "Back out"
            default: "Linear"
            }
        }
        """#,
        "AppStyles.bars": #"""
        // Sources/Styles/AppStyles.swift
        // Where the host draws the bars' buttons itself - the Web - each
        // group stands in a light rounded box in a fine outline, its buttons
        // inset from it, a button standing alone in one of its own; its
        // buttons' words semibold, each a shade darker under the pointer and
        // pressed.
        Style<ToolbarGroup>()
            .stroke(Color(light: Color(hex: 0xB8BEC6), dark: Color(hex: 0x4A515C)))
            .lineWidth(1)
            .visualState(.pointerOver) { $0.stroke(Color(light: Color(hex: 0x8E96A0), dark: Color(hex: 0x6B7380))) }

        Style<ToolbarButton>()
            .fontWeight(.semibold)
            .visualState(.pointerOver) { $0.background(Color(light: .black, dark: .white).opacity(0.06)) }
            .visualState(.pressed) { $0.background(Color(light: .black, dark: .white).opacity(0.12)) }

        Style<ToolbarToggle>()
            .fontWeight(.semibold)
            .visualState(.pointerOver) { $0.background(Color(light: .black, dark: .white).opacity(0.06)) }
        """#,
        "AppStyles.sample": #"""
        // Sources/Styles/AppStyles.swift
        // A page's own name for itself. Tight tracking, because a large
        // size at the default spacing reads loose.
        Style<Text>(.headline)
            .fontSize(32)
            .fontWeight(.bold)
            .tracking(-0.5)
            .horizontalAlignment(.center)
            .horizontalTextAlignment(.center)

        // A PAIR, and the second is written from the first: everything
        // about the shape of a quotation is stated once here, and
        // "QuoteLoud" adds the one property that makes it loud. The Styles
        // sample draws both, one under the other.
        Style<Text>(.quote)
            .textColor(Palette.subtle)
            .fontSize(17)
            .fontAttributes(.italic)
            .tracking(0.3)
            .horizontalTextAlignment(.center)

        Style<Text>(.quoteLoud)
            .basedOn(.quote)
            .textColor(Palette.accent)

        // Every button the gallery shows wears its violet - a style with no
        // key is every button's - in its platform's shape: a capsule on
        // Apple's platforms and the Web, rounded everywhere else; and
        // lower on the desktops and the Web, where a pointer presses it.
        // Held down on a phone or a tablet, it grows a breath and lights
        // up, under its own motion; elsewhere it presses as the
        // platform's own button does.
        Style<Button>()
            .textColor(Palette.onAccent)
            .background(Palette.accent)
            .lineWidth(0)
            #if APPKIT || UIKIT || WEB
            .shape(.capsule)
            #else
            .shape(.roundedRectangle(10))
            #endif
            #if APPKIT || WINUI || GTK || WEB
            .padding(horizontal: 16, vertical: 6)
            #elseif UIKIT
            .padding(horizontal: 22, vertical: 10)
            #else
            .padding(horizontal: 16, vertical: 11)
            #endif
            #if UIKIT || ANDROID
            .visualState(.pressed) { $0
                .scale(1.05)
                .background(Palette.accentLit)
            }
            #endif
            .visualState(.disabled) { $0
                .textColor(Palette.disabled)
                .background(Palette.outline)
            }

        // A button's role chooses a style over the one above: it says
        // only what the role changes. The main action keeps the violet;
        // the way out steps back, and what destroys something is red -
        // each lit in its own color while held down on a phone or a
        // tablet.
        Style<Button>(role: .cancel)
            .textColor(Palette.text)
            .background(Palette.selected)
            #if UIKIT || ANDROID
            .visualState(.pressed) { $0.background(Palette.selectedLit) }
            #endif
        Style<Button>(role: .destructive)
            .textColor(Palette.danger)
            .background(Palette.dangerWash)
            #if UIKIT || ANDROID
            .visualState(.pressed) { $0.background(Palette.dangerWashLit) }
            #endif

        // A picker's presentation chooses a style as a button's role
        // does: the chosen segment in the gallery's violet.
        Style<Picker>(presentation: .segmented)
            .tint(Palette.accent)
        """#,
        "AppSwitcherSample": #"""
        // Sources/Samples/MotionLayout/AppSwitcherSample.swift
        import StateUIFoundation

        /// One running app: its name, which is its identity, and its picture -
        /// one of the gallery's groups' cards, as its home page shows them.
        struct RunningApp: Hashable {
            let name: String
            let art: String
        }

        /// Every app the switcher starts with.
        static let all = [
            RunningApp(name: "Fundamentals", art: "cat_fundamentals.png"),
            RunningApp(name: "Driven values", art: "cat_driven.png"),
            RunningApp(name: "Using state", art: "cat_state.png"),
            RunningApp(name: "Animation", art: "cat_animation.png"),
            RunningApp(name: "Controls", art: "cat_basicinput.png"),
            RunningApp(name: "Text & typing", art: "cat_text.png"),
            RunningApp(name: "Layout", art: "cat_layout.png"),
            RunningApp(name: "Styles", art: "cat_styles.png"),
            RunningApp(name: "Shapes", art: "cat_shapes.png"),
            RunningApp(name: "Gestures", art: "cat_gestures.png"),
        ]

        /// The apps still running, in order.
        @State private var apps = Self.all

        /// Which card is in front - the third, two older apps under it to the
        /// left - handed on with `$`, never read in the body.
        @State private var turn = 2.0

        var body: some View {
            let (count, running) = (apps.count, apps)

            return Grid {
                Grid {
                    MotionLayout(running, id: \.name, parameters: $turn) { app in
                        AppCard(app: app, index: running.firstIndex(of: app) ?? 0, turn: $turn)
                    } placements: { room, turn in
                        (0..<count).map { place($0, turn, room) }
                    }
                    // Thrown as the gallery's home turns its cards: a spring that
                    // carries the hand on and settles.
                    .axis(\.self, input: .scroll(.horizontal), range: 0...Double(max(count - 1, 0)), snaps: .every(1))
                    .throwMotion(.spring(response: .milliseconds(500), damping: 0.8))
                    // A FIRST MOVE UP is the card's: it follows the hand; let go
                    // high or fast, it flies off and the app closes - the others
                    // close up, the card in front staying in front.
                    .itemDrag(begins: .perpendicular)
                    .onItemDismissed(.up, beyond: 120) { app in close(app) }
                }
                .gridRow(0)
                .clipsContent(true)

                Button("Open all again").onClicked {
                    apps = Self.all
                    $turn.journey.snap(to: 2)
                }
                .horizontalAlignment(.center)
                .gridRow(1)
            }
            .rows(.fill, .auto)
        }

        /// `app` closed: the others close up; one before the card in front keeps
        /// that card in front, and where the last closes, the parameters travel
        /// to the one before.
        private func close(_ app: RunningApp) {
            guard let leaving = apps.firstIndex(of: app) else { return }
            let front = min(max(Int(turn.rounded()), 0), apps.count - 1)
            apps.remove(at: leaving)
            if leaving < front {
                $turn.journey.snap(to: Double(front - 1))
            } else if front > apps.count - 1 {
                $turn.journey.move(to: Double(max(apps.count - 1, 0)))
            }
        }

        /// A card's size in `room`, and where its left edge stands `step` from
        /// the one in front: the next one over it to the right, a card apart;
        /// those before it nearer the room's left edge the farther under they
        /// go, and never past it.
        private func across(_ step: Double, in room: Rect) -> (width: Double, height: Double, left: Double) {
            // A card is its picture's shape, 400 by 560, under its icon's row.
            let width = min((room.height - 36 - 36) * 400 / 560, room.width * 0.66)
            let height = width * 560 / 400 + 36
            let middle = room.width / 2 - width / 2
            let behind = max(-step, 0)
            let edge = 0.0
            let left = step >= 0 ? middle + step * width * 0.84
                : edge + (middle - edge) * exp(-0.8 * behind)
            return (width, height, left)
        }

        /// Where the card at `index` stands, as a phone's switcher stands them,
        /// each later one over the one before, those under the front one a
        /// little smaller.
        private func place(_ index: Int, _ turn: Double, _ room: Rect) -> Placement {
            let step = Double(index) - turn
            let (width, height, left) = across(step, in: room)
            let behind = max(-step, 0)

            return Placement(
                Rect(left, (room.height - height) / 2, width, height),
                transform: .scale(1 - min(behind, 3) * 0.04),
                opacity: min(max(1.6 - behind * 0.6, 0), 1) * min(max(3 - step, 0), 1),
                zIndex: index)
        }

        /// One card: its icon and name over its window - its picture, cut to the
        /// card's corners; the icon is the same picture, small. Its name fades
        /// as the card goes under the one in front: a state of the card's own,
        /// which an engine following the parameters writes where the run is shown -
        /// the hand's place too - and the name's opacity wears.
        struct AppCard: View {
            let app: RunningApp
            let index: Int
            let turn: Binding<Double>

            @State private var named = 1.0

            var body: some View {
                Grid {
                    HStack {
                        ZStack { Image(ImageSource(app.art)).contentMode(.fill) }
                            .clipsContent(true)
                            .width(28)
                            .height(28)
                        Text(app.name)
                            .fontWeight(.semibold)
                            .lineBreak(.tailTruncation)
                            .opacity($named)
                    }
                    .gridRow(0)

                    ZStack { Image(ImageSource(app.art)).contentMode(.fill) }
                        .clipsContent(true)
                        .gridRow(1)
                }
                .rows(.auto, .fill)
                .engine(following: turn) { _ in
                    named = min(max(1 + (Double(index) - turn.journey.value) / 0.6, 0), 1)
                }
            }
        }
        """#,
        "AppThemeSample": #"""
        // Sources/Samples/Styles/AppThemeSample.swift
        /// The application's information, where the theme is read.
        @Environment(\.application) var app

        var body: some View {
            VStack {
                // The theme is read here, so a change to it builds this
                // closure.
                DebugInfoLabel()

                Text("\(app.info.colorScheme)")
                    .fontWeight(.bold)

                // LOGIC on the theme - a different WORD, not a color.
                // A color that differs by theme is Color(light:dark:),
                // which follows by itself.
                Text(app.info.colorScheme == .dark
                    ? "lights off - a view can choose calmer artwork"
                    : "lights on - a view can choose vivid artwork")
            }
        }
        """#,
        "AppearanceSample": #"""
        // Sources/Samples/Styles/AppearanceSample.swift
        /// The gallery's look, which every gallery window wears.
        let style: SessionStyle

        /// The application, whose theme is held here.
        @Environment(\.application) private var application

        /// The device - a phone stands the two looks one under the other.
        @Environment(\.device) private var device

        /// The themes the application may hold, in the order they are offered.
        private static let themes: [(name: String, scheme: ColorScheme)] = [
            ("The system's", .system), ("Light", .light), ("Dark", .dark),
        ]

        /// How the bars' buttons may stand, in the order they are offered.
        private static let toolbarStyles: [(name: String, style: ToolbarStyle)] = [
            ("The Web's own", .system), ("Glass", .glass), ("Plain", .plain), ("Rounded", .rounded),
        ]

        /// The accents the application may hold, the platform's first.
        private static let accents: [(name: String, color: Color?)] =
            [("The platform's", nil)] + AccentChoice.own.map { ($0.name, $0.color(system: .accent, for: .bar)) }

        var body: some View {
            // Read here, so a theme held anywhere builds the picker again at its
            // new place.
            let application = self.application
            let themes = Self.themes
            let accents = Self.accents

            return VStack {
                // The theme first: which of the two looks below the gallery wears.
                SectionTitle("The theme")
                Picker(themes.map(\.scheme),
                       selection: Binding(get: { application.colorScheme }, set: { application.colorScheme = $0 })) { scheme in
                    themes.first { $0.scheme == scheme }?.name ?? ""
                }

                // The accent the platform draws its controls in, where the user
                // chooses none for the system.
                SectionTitle("The accent")
                Picker(Array(accents.indices), selection: Binding(
                    get: { accents.firstIndex { $0.color == application.accentColor } ?? 0 },
                    set: { application.accentColor = accents[$0].color })) { accents[$0].name }

                #if WEB
                // The bars' buttons, which the Web draws itself.
                SectionTitle("The bars' buttons")
                Picker(Self.toolbarStyles.map(\.style), selection: Binding(
                    get: { style.toolbarStyle }, set: { style.toolbarStyle = $0 })) { chosen in
                    Self.toolbarStyles.first { $0.style == chosen }?.name ?? ""
                }
                // The application's own look for them: a style for every group and
                // every button on a bar, its states included (AppStyles.bars).
                Switch(Binding(get: { style.barsInOwnLook }, set: { owns in
                    style.barsInOwnLook = owns
                    application.styles = AppStyles.sheet(barsInOwnLook: owns)
                }))
                    .text("In the gallery's own look")
                #endif

                // A look for each theme: the gallery wears the one of the theme in
                // force, and changes with it. Side by side where there is room,
                // one under the other on a phone.
                if device.info.formFactor == .phone {
                    LookColumn(title: "Light", style: style, look: \.lightLook, choice: \.lightChoice)
                    LookColumn(title: "Dark", style: style, look: \.darkLook, choice: \.darkChoice)
                } else {
                    Grid {
                        LookColumn(title: "Light", style: style, look: \.lightLook, choice: \.lightChoice)
                            .gridColumn(0)
                        LookColumn(title: "Dark", style: style, look: \.darkLook, choice: \.darkChoice)
                            .gridColumn(1)
                    }
                    .columns(.fill, .fill)
                }
            }
        }

        /// One theme's look: its bars, and what its window, its sidebar and its
        /// sidebar over the page are made of - written where `look` says, which makes
        /// it the user's own; the gallery's own again where `choice` says.
        private struct LookColumn: View {
            let title: String
            let style: SessionStyle
            let look: ReferenceWritableKeyPath<SessionStyle, ThemeLook>
            let choice: ReferenceWritableKeyPath<SessionStyle, LookChoice>

            var body: some View {
                // Read here, so a choice made anywhere builds each picker again at its
                // new place.
                let style = self.style
                let key = self.look
                let name = title.lowercased()
                // Each surface's choices write that part of the theme's look.
                let surface = { (part: WritableKeyPath<ThemeLook, SurfaceLook>) in
                    Binding(get: { style[keyPath: key][keyPath: part] }, set: { style[keyPath: key][keyPath: part] = $0 })
                }

                let choice = self.choice
                let composed = style[keyPath: choice] != .own

                return VStack {
                    SectionTitle(title)

                    // Back to the look this gallery draws on this platform, whatever
                    // it was when the user composed another.
                    Button("The gallery's own")
                        .isEnabled(composed)
                        .onClicked { style[keyPath: choice] = .own }

                    SurfacePickers(title: "The bars", label: "Bars", theme: name, part: .bar, surface: surface(\.bars))
                    SurfacePickers(title: "The window", label: "Window", theme: name, part: .window, surface: surface(\.window))
                    SurfacePickers(
                        title: "The sidebar", label: "Sidebar", theme: name, part: .sidebar, surface: surface(\.sidebar))
                    SurfacePickers(
                        title: "The sidebar over the page", label: "Overlay", theme: name, part: .sidebarOverlay,
                        surface: surface(\.sidebarOverlay))
                }
            }
        }

        /// One surface's choices: what it is made of, in which color, and how thick
        /// a blur.
        private struct SurfacePickers: View {
            let title: String
            let label: String
            let theme: String
            let part: GallerySurface
            let surface: Binding<SurfaceLook>

            var body: some View {
                let surface = self.surface
                let look = surface.wrappedValue
                let materials = SurfaceMaterial.offered(on: part)
                let accents = AccentChoice.allCases
                let blurs = SurfaceLook.blurs
                let id = "appearance.\(theme).\(label.lowercased())"

                return VStack {
                    Text(title)
                    Picker(materials, selection: Binding(get: { look.material }, set: { surface.wrappedValue.material = $0 })) {
                        $0.name
                    }
                    Picker(accents, selection: Binding(get: { look.color }, set: { surface.wrappedValue.color = $0 })) {
                        $0.name
                    }
                        .isEnabled(look.material.showsColor)
                    Picker(blurs, selection: Binding(get: { look.blur }, set: { surface.wrappedValue.blur = $0 })) { blur in
                        ["Ultra thin", "Thin", "Regular", "Thick", "Ultra thick"][blurs.firstIndex(of: blur) ?? 0]
                    }
                        .isEnabled(look.material.showsBlur)
                }
            }
        }
        """#,
        "ApplicationSessionSample": #"""
        // Sources/Samples/Environment/ApplicationSessionSample.swift
        /// The application as it runs - one for the whole process.
        @Environment(\.application) var application

        @State private var wide = false

        static let laws: [Motion] = [.standard, .spring(response: .milliseconds(320), damping: 0.6), .none]

        /// What the picker calls a law.
        static func name(_ law: Motion) -> String {
            switch law {
            case .standard: "Standard"
            case .none: "None"
            default: "Spring"
            }
        }

        var body: some View {
            VStack {
                // `application.motion` and `wide` are read here, so a choice or a
                // press builds this closure.
                DebugInfoLabel()

                Text("Pick None, then open another sample: only what has a motion of its own still travels.")

                // One write for the whole application: every value without a
                // motion of its own takes it.
                Picker(Self.laws, selection: Binding(get: { application.motion }, set: { application.motion = $0 }),
                       caption: Self.name)
                    .horizontalAlignment(.center)

                // No `.motion` here: the panel takes the application's.
                Rectangle()
                    .fill(wide ? Palette.accent : Palette.brand)
                    .width(wide ? 300 : 120)
                    .height(60)
                    .horizontalAlignment(.center)

                Button("Change")
                    .horizontalAlignment(.center)
                    .onClicked { wide.toggle() }
            }
        }
        """#,
        "Areas": #"""
        // Sources/Samples/Layout/ZStackSample.swift
        @State private var proportional = true

        var body: some View {
            VStack {
                // NO BUILD READING HERE. `proportional` is read inside the stack's
                // own braces, and a container describes its children when the
                // differ asks, so the only closure this switch rebuilds is that one.
                ZStack {
                    // No area: the whole room, filled.
                    Fill(Palette.outline)

                    // The panel fills the area it names: the right half of the
                    // room, or 120 by 60 at 16, 16 whatever the room's size.
                    Fill(Color(hex: 0x1E88E5))
                        .area(proportional ? .proportional(0.5, 0, 0.5, 1) : .absolute(16, 16, 120, 60))

                    // Its natural size, where its alignments put it.
                    Badge(text: "start", color: Color(hex: 0xE53935))
                        .horizontalAlignment(.start)
                        .verticalAlignment(.start)

                    Badge(text: "end", color: Color(hex: 0x00897B))
                        .horizontalAlignment(.end)
                        .verticalAlignment(.end)
                }
                .height(180)

                SwitchRow("Proportional area", $proportional)
                    .horizontalAlignment(.center)
            }
        }

        /// One labeled badge, so the sample says what is being positioned rather than
        /// how it is drawn.
        private struct Badge: View {
            let text: String
            let color: Color

            var body: some View {
                Text(text)
            }
        }
        """#,
        "AwaitingEvents": #"""
        // Sources/Samples/State/GateSample.swift
        @State private var count = 0
        @State private var query = ""
        @State private var found = "Nothing searched yet."
        @State private var logging = false
        @State private var logged = 0

        var body: some View {
            VStack {
                // No await: the handler runs whole inside the press and names no policy.
                Button("+1 - \(count)")
                    .onClicked { count += 1 }

                // Every letter cancels the search under way: only the last one finishes.
                SearchField($query)
                    .onTextChanged(.cancelPrevious) { text in
                        try await Task.sleep(for: .milliseconds(600))
                        found = text.isEmpty ? "Nothing searched yet." : "Found 3 for \"\(text)\"."
                    }
                Text(found)

                SwitchRow("Log each change", $logging)
                Text("Changes logged: \(logged)")
                    // Each change logged beside the others: nothing held back.
                    .onChanged(logging, policy: .runConcurrently) {
                        try await Task.sleep(for: .milliseconds(800))
                        logged += 1
                    }
            }
        }
        """#,
        "BarStrips": #"""
        // Sources/Samples/Layout/ScrollViewSample.swift
        var body: some View {
            Grid {
                barCase(.visible, "verticalScrollIndicator(.visible)")
                    .gridColumn(0)

                barCase(.never, "verticalScrollIndicator(.never)")
                    .gridColumn(1)
            }
            .columns(.fill, .fill)
        }

        /// One scroller with the setting that made it named underneath, so the pair
        /// reads as one difference rather than as two scrollers.
        ///
        /// - Parameter visibility: what this half asks for.
        /// - Parameter caption: the words under it.
        private func barCase(_ visibility: ScrollIndicatorVisibility, _ caption: String) -> Grid {
            Grid {
                ScrollView {
                    VStack {
                        ForEach(1...40) { line in
                            Text("Line \(line)")
                        }
                    }
                }
                .verticalScrollIndicator(visibility)
                .gridRow(0)

                Text(caption)
                    .gridRow(1)
            }
            .rows(.fill, .auto)
        }
        """#,
        "BatterySample": #"""
        // Sources/Samples/Environment/BatterySample.swift
        /// The device, by its name: nothing is passed anywhere, and the host keeps
        /// its battery current.
        @Environment(\.device) var device

        var body: some View {
            VStack {
                // The battery is read here, so a change the host reports
                // builds this closure - and nothing else on the page.
                DebugInfoLabel()

                Text(device.battery.chargeLevel <= 0
                    ? "the host has not said"
                    : "\(Int(device.battery.chargeLevel * 100))%")
                    .fontWeight(.bold)

                Text("state · \(device.battery.state)")
                Text("source · \(device.battery.powerSource)")
                Text("saver · \(device.battery.energySaverStatus)")
            }
        }
        """#,
        "BindingReaderSample": #"""
        // Sources/Samples/Driven/BindingReaderSample.swift
        /// The one value this page is about, owned here and handed on to every
        /// child as `$level`. This body never reads it.
        @State private var level = 0.2

        var body: some View {
            VStack {
                // The knob is handed the state: it drags it and sends it, and
                // reads it at no build.
                Knob(level: $level)

                // Two meters on the same state. The first READS the value in its
                // body, so every report rebuilds it; the second CONVERTS it and is
                // never rebuilt.
                ReadingMeter(level: $level)

                ConvertedMeter(level: $level)
            }
        }

        /// The input, handed the parent's state: drags it and sends it.
        private struct Knob: View {
            @Binding var level: Double

            var body: some View {
                VStack {
                    Slider($level)
                        .motion(.eased(.milliseconds(600), .cubicOut))

                    HStack {
                        Button("Full")
                            .onClicked { level = 1 }

                        Button("Empty")
                            .onClicked { level = 0 }
                    }
                }
            }
        }

        /// A meter that READS the value: a reader, rebuilt on every report, and it
        /// says so on its own face.
        private struct ReadingMeter: View {
            @Binding var level: Double

            var body: some View {
                // Taken before the container, so it is this view's own reading.
                let count = BuildCount.of(debugInfo())   // this view's own build count

                return VStack {
                    // A GET: this meter is a reader, and every report rebuilds it.
                    ProgressBar()
                        .progress(level)

                    Text("a bar that reads the value — \(count)")
                }
            }
        }

        /// A meter handed the same state and CONVERTING it: no reader, never rebuilt,
        /// and it says so too.
        private struct ConvertedMeter: View {
            @Binding var level: Double

            var body: some View {
                let count = BuildCount.of(debugInfo())   // stays at one

                return VStack {
                    // The words are the host's own arithmetic over the state, worked
                    // out on its frames - handing a conversion on reads nothing here.
                    Text()
                        .text($level.convert { "\(Int(($0 * 100).rounded()))%" })

                    Text("a conversion of the same state — \(count)")
                }
            }
        }
        """#,
        "BottomBarSample": #"""
        // Sources/Samples/Navigation/BottomBarSample.swift
        @State private var presented = false
        @State private var path: [Int] = []
        @State private var messages = Self.talk
        @State private var draft = ""
        /// The list of messages, which opening and Send scroll.
        @Aim(ItemsView<Int>.self) private var list
        /// How tall the field stands at one line: the least it has stood at.
        @State private var oneLine = 0.0
        @State private var edge = ScrollEdge.automatic
        static let edges: [ScrollEdge] = [.automatic, .hard, .none]

        /// One message: what it says, and whether it is ours.
        struct Message: Hashable {
            let text: String
            let mine: Bool
        }

        /// A conversation long enough to scroll under the bar.
        static let talk: [Message] = [
            ("Are we still on for Saturday?", false), ("Yes! Ten o'clock at the station?", true),
            ("Perfect. Should I bring anything?", false), ("Just good shoes - the trail is muddy after the rain.", true),
            ("Noted. How long is the walk?", false), ("About four hours there and back, with a stop for lunch.", true),
            ("Lunch where?", false), ("There's a hut at the top. They make the best soup.", true),
            ("Sold. Is Anna coming too?", false), ("She said she'd try, but she has a deadline.", true),
            ("Tell her the soup is non-negotiable.", false), ("Ha, I will.", true),
            ("What if it rains again?", false), ("Then we take the lower path through the forest.", true),
            ("You've thought of everything.", false), ("I've done this walk a few times.", true),
            ("Can you send me the map?", false), ("I'll send it tonight.", true),
            ("Thanks! See you Saturday.", false), ("See you - don't forget the shoes!", true),
        ].map { Message(text: $0.0, mine: $0.1) }


        var body: some View {
            VStack {
                // How the rows show at the bars' edges as they pass under them.
                Picker(Self.edges, selection: $edge) { "\($0)".titled }
                    .presentation(.segmented)

                Button("Open the conversation")
                    .onClicked { presented = true }
                    .sheet(isPresented: $presented) { conversation }
            }
        }

        private var conversation: some View {
            NavigationStack($path) {
                Grid {
                    // Theirs on the left, ours on the right; the list opens at
                    // its end, and a message sent scrolls there.
                    ItemsView(Array(messages.indices)) { index in
                        VStack { bubble(messages[index]) }
                    }
                    .itemsLayout(.list())
                    .aim(list)
                    .onCreated { try await list.scrollTo(messages.count - 1, anchor: .end) }
                    .onChanged(messages.count, policy: .cancelPrevious) {
                        try await list.scrollTo(messages.count - 1, anchor: .end)
                    }
                }
                .ignoresSafeArea(.all)
                .galleryPage("Conversation")
                // The field grows with its lines, and the bar with it; the rows
                // pass under the bar, and under the field's glass.
                .bottomBar(edge: edge) {
                    Grid {
                        ZStack {
                            TextEditor($draft)
                                .placeholder("Message")
                                .growsWithText(true)
                        }
                        // The field's own ground is glass, its words clear of the
                        // round ends: a capsule at one line, its corners rounding
                        // alike as more lines grow it.
                        .onFrameChanged { frame in
                            if oneLine == 0 || frame.height < oneLine { oneLine = frame.height }
                        }
                        Button("Send")
                            .onClicked {
                                guard !draft.isEmpty else { return }
                                messages.append(Message(text: draft, mine: true))
                                draft = ""
                            }
                            .verticalAlignment(.end)
                            .gridColumn(1)
                    }
                    .columns(.fill, .auto)
                }
            } destination: { _ in
                Text("")
            }
            // The bar at the top shows the same edge as the bar at the foot.
            .barScrollEdge(edge)
        }

        /// A message in its bubble, at its side of the conversation.
        private func bubble(_ message: Message) -> some View {
            ZStack {
                Text(message.text)
            }
            // A capsule at one line - a corner never rounds past half the
            // height - and round corners on more.
            .maximumWidth(300)
            .horizontalAlignment(message.mine ? .end : .start)
        }
        """#,
        "BoundPropertiesSample": #"""
        // Sources/Samples/Driven/BoundPropertiesSample.swift
        /// A number the host WALKS: handed to `fontSize`, an assignment travels
        /// there under the label's law.
        @State private var size = 18.0   // a number: the host walks it

        /// A color the host walks the same way.
        @State private var tint = Palette.accent   // a color: the same

        /// Which of the two tints is worn - read by handlers alone.
        @State private var warm = true   // which tint: read by a handler alone

        /// A flag the host SETS as it stands.
        @State private var shown = true   // a flag: the host sets it

        /// Words the host writes.
        @State private var hint = "Type here"   // words: the host writes them

        /// A value the host sets AND reports: the slider is handed `$level`
        /// both ways, and nothing here reads it.
        @State private var level = 0.25   // a value: set and reported

        /// A toggle the host sets and reports - and one row READS it, which is
        /// the one row that renders.
        @State private var on = false   // a toggle: set and reported

        /// A MEMBER: an enum the host sets as it stands. It crosses as the
        /// member's number, which the host resolves.
        @State private var side = Alignment.start   // a member: the host sets it

        var body: some View {
            VStack {
                // A JOURNEY. `size = 30` sends the font size there under the
                // label's law; the row is never built again.
                row("1 · a number the host walks - fontSize($size)") {
                    Text("The quick brown fox")
                    DebugInfoLabel()   // stays at one
                }

                HStack {
                    button("Smaller") { size = max(10, size - 4) }
                    button("Bigger") { size = min(40, size + 4) }
                }
                .horizontalAlignment(.center)

                row("2 · a color the host walks - textColor($tint)") {
                    Text("Tinted words")
                    DebugInfoLabel()   // stays at one
                }

                button("Swap the tint") {
                    warm.toggle()
                    tint = warm ? Palette.accent : Palette.subtle
                }

                row("3 · a flag the host sets - isVisible($shown)") {
                    Text("Now you see me")
                        .isVisible($shown)
                    DebugInfoLabel()
                }

                SwitchRow("Shown", $shown)

                row("4 · words the host writes - placeholder($hint)") {
                    TextField()
                        .placeholder($hint)
                    DebugInfoLabel()
                }

                button("Another hint") { hint = hint == "Type here" ? "Your name" : "Type here" }

                row("5 · a value, both ways - Slider($level)") {
                    Slider($level)
                    DebugInfoLabel()
                }

                button("To the middle") { level = 0.5 }

                row("6 · a member the host sets - horizontalAlignment($side)") {
                    Text("Where am I?")
                        .horizontalAlignment($side)
                    DebugInfoLabel()
                }

                button("Move me along") {
                    side = side == .start ? .center : side == .center ? .end : .start
                }

                row("7 · a toggle, both ways - and a label that reads it") {
                    Switch($on)
                        .horizontalAlignment(.start)
                    Text(on ? "on" : "off")
                    DebugInfoLabel()   // climbs on every flip
                }
            }
        }

        /// One row: a caption, then the content in a stack of its own, so the
        /// reading taken inside the content is that stack's alone.
        private func row<Content: Views>(_ caption: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
            ZStack {
                VStack {
                    Text(caption)

                    VStack(content: content)
                }
            }
            .style(.card)
            .stroke(Palette.outline)
        }

        /// One of the buttons, all of which look the same.
        private func button(_ caption: String, _ act: @escaping @MainActor () throws -> Void) -> Button {
            Button(caption)
                .onClicked(act)
        }
        """#,
        "BrushSample": #"""
        // Sources/Samples/Shapes/BrushSample.swift
        @State private var end = 0

        /// The two stops the linear gradients here run between.
        private static let stops = [
            GradientStop(Palette.brand, 0),
            GradientStop(.steelBlue, 1),
        ]

        /// Across, down, and corner to corner - the three the button cycles.
        private static let ends: [(point: Point, name: String)] = [
            (Point(1, 0), "Point(1, 0)"),
            (Point(0, 1), "Point(0, 1)"),
            (Point(1, 1), "Point(1, 1)"),
        ]

        var body: some View {
            VStack {
                // The gradient's end is read here, so moving it builds this closure.
                DebugInfoLabel()

                SectionTitle("Along a line")

                Rectangle()
                    .fill(.linearGradient(Self.stops, startPoint: Point(0, 0), endPoint: Self.ends[end].point))
                    .contentMode(.stretch)   // fills the room, proportions and all
                    .height(80)

                Button("endPoint: \(Self.ends[end].name)")
                    .horizontalAlignment(.center)
                    .onClicked { end = (end + 1) % Self.ends.count }

                SectionTitle("Out from a point")

                Ellipse()
                    .fill(.radialGradient(
                        [GradientStop(.white, 0), GradientStop(.steelBlue, 1)],
                        center: Point(0.35, 0.3),
                        radius: 0.75))
                    .width(96)
                    .height(96)
                    .horizontalAlignment(.center)

                SectionTitle("On a stroke and a background")

                ZStack {
                    Text("A stroke is a brush too")
                }
                .style(.card)
                .lineWidth(4)
                .stroke(.linearGradient(Self.stops, startPoint: Point(0, 0), endPoint: Point(1, 0)))

                // Not a shape at all: `.background` takes a brush, so any view can
                // carry one.
                VStack {
                    Text("A whole stack, behind a gradient")
                }
            }
        }
        """#,
        "BuilderSample": #"""
        // Sources/Samples/Fundamentals/BuilderSample.swift
        @State private var signedIn = false
        @State private var note = ""
        @State private var editing = false
        @State private var chosen = 2

        var body: some View {
            VStack {
                // The conditions and the choice are all read here, so THIS is
                // the closure a flip or a pick builds again.
                DebugInfoLabel()

                Switch($signedIn)
                    .text("Signed in")

                // An `if` with no `else`. The TextField below it is child 2 in one
                // state and child 3 in the other - and it is the same control
                // either way, so what has been typed in it survives the toggle.
                if signedIn {
                    Text("Signed in")
                        .fontWeight(.bold)
                }

                TextField($note)
                    .placeholder("Type here, then flip the switch")

                // Two branches are two elements, even though both are TextFields:
                // switching REPLACES the control rather than editing it, which is
                // what the author wrote.
                if editing {
                    TextField("name")
                        .placeholder("name")
                } else {
                    TextField("nickname")
                        .placeholder("nickname")
                }

                SwitchRow("Editing", $editing)
                    .horizontalAlignment(.start)

                // A ForEach whose row changes its KIND with the choice. The
                // row's identity is its ITEM, so moving the choice touches two
                // rows - each replaced for its new kind - and leaves the other
                // three alone.
                ForEach(0..<5) { turn in
                    if turn == chosen {
                        Text("turn \(turn) - chosen")
                            .fontWeight(.bold)
                    } else {
                        Button("turn \(turn)")
                            .horizontalAlignment(.start)
                            .onClicked { chosen = turn }
                    }
                }

            }
        }
        """#,
        "ButtonMenuSample": #"""
        // Sources/Samples/BasicInput/ButtonMenuSample.swift
        @State private var last = "nothing yet"
        @State private var showsArrow = true
        @State private var platformLook = false

        var body: some View {
            // The platform's own buttons, or the gallery's every button wears.
            let look: StyleKey<Button>? = platformLook ? .platform : nil

            return VStack {
                Text("Try each menu: Share's on a click, Save's on its arrow, Open's when held.")

                HStack {
                    Button("Share").style(look).menu {
                        MenuItem("Mail").onClicked { last = "Share by mail" }
                        MenuItem("Message").onClicked { last = "Share by message" }
                        MenuSeparator()
                        MenuItem("Copy link").onClicked { last = "Link copied" }
                    }

                    Button("Save")
                        .style(look)
                        .onClicked { last = "Saved" }
                        .menu {
                            MenuItem("Save as…").onClicked { last = "Saved as" }
                            MenuItem("Save a copy").onClicked { last = "Saved a copy" }
                        }

                    Button("Open")
                        .style(look)
                        .onClicked { last = "Opened" }
                        .menu(.held) {
                            MenuItem("Report.txt").onClicked { last = "Opened Report.txt" }
                            MenuItem("Notes.txt").onClicked { last = "Opened Notes.txt" }
                        }
                }

                HStack {
                    Button("More")
                        .icon(.icon(.more))
                        .showsText(false)
                        .style(look)
                        .menu {
                            MenuItem("Rename").onClicked { last = "Renamed" }
                            MenuItem("Delete").onClicked { last = "Deleted" }
                        }
                        .showsMenuArrow(showsArrow)

                    Switch($showsArrow)
                        .verticalAlignment(.center)

                    Text("Arrow")
                        .verticalAlignment(.center)
                }

                Switch($platformLook)
                    .text("Platform look")

                Text("Last: \(last)")
            }
        }
        """#,
        "ButtonRoleSample": #"""
        // Sources/Samples/BasicInput/ButtonRoleSample.swift
        @State private var name = ""
        @State private var last = "nothing yet"
        @State private var platformLook = false

        var body: some View {
            // The gallery's style for each role, or the platform's own look.
            let look: StyleKey<Button>? = platformLook ? .platform : nil

            return VStack {
                Text("Press Return or Escape; in the field, Return ends the name instead.")

                TextField($name)
                    .placeholder("Name")
                    .onSubmitted { last = "the name \(name)" }

                HStack {
                    // Marked as an action that destroys something.
                    Button("Delete")
                        .style(look)
                        .role(.destructive)
                        .onClicked { last = "Delete" }

                    // Escape presses the way out.
                    Button("Cancel")
                        .style(look)
                        .role(.cancel)
                        .onClicked { last = "Cancel" }

                    // Return presses the main action.
                    Button("Save")
                        .style(look)
                        .role(.primary)
                        .onClicked { last = "Save" }
                }

                Switch($platformLook)
                    .text("Platform look")

                Text("Last: \(last)")
            }
        }
        """#,
        "ButtonRow": #"""
        // Sources/Samples/Layout/GridSample.swift
        @State private var second = true

        var body: some View {
            VStack {
                // Two columns of one share each. Alone, the first button spans
                // both and asks its width of them, so its row stays a button tall.
                Grid {
                    Button("Details")
                        .gridColumnSpan(second ? 1 : 2)

                    if second {
                        Button("Undo")
                            .gridColumn(1)
                    }
                }
                .columns(.fill, .fill)

                SwitchRow("Second button", $second)
                    .horizontalAlignment(.center)
            }
        }
        """#,
        "ButtonSample": #"""
        // Sources/Samples/BasicInput/ButtonSample.swift
        @State private var counter = 0

        var body: some View {
            VStack {
                // The count is read here, so a click builds this closure again.
                DebugInfoLabel()

                Button("Increment")
                    .horizontalAlignment(.center)
                    .onClicked { counter += 1 }

                Text("Clicked \(counter) time(s)")

                Button("Outlined")
                    .stroke(Palette.accent)
                    .lineWidth(1)
                    .shape(.capsule)
                    .horizontalAlignment(.center)
                    .onClicked { counter += 1 }

                Button("Disabled")
                    .isEnabled(false)
                    .horizontalAlignment(.center)
            }
        }
        """#,
        "ChangesAcrossBranches": #"""
        // Sources/Samples/State/OnChangedSample.swift
        @State private var signedIn = false
        @State private var changes = 0

        var body: some View {
            VStack {
                Switch($signedIn)
                    .text("Signed in")

                // Written on the group holding the `if/else`: it watches whichever
                // branch shows. The group adds no view of its own.
                Group {
                    if signedIn {
                        Text("Signed in")
                            .fontWeight(.bold)
                    } else {
                        Button("Sign in")
                            .onClicked { signedIn = true }
                    }
                }
                .horizontalAlignment(.center)
                .onChanged(signedIn) { changes += 1 }

                Text("Changed \(changes) times")
            }
        }
        """#,
        "ChangingDeckSample": #"""
        // Sources/Samples/MotionLayout/ChangingDeckSample.swift
        /// One card: its name, which is its identity, its color and its icon.
        struct Card: Hashable {
            let name: String
            let color: Color
            let icon: Icon
        }

        /// Every card the deck can hold, dealt in this order.
        static let all = [
            Card(name: "Mural", color: Color(hex: 0x7C3AED), icon: .star),
            Card(name: "Nebula", color: Color(hex: 0x2563EB), icon: .heart),
            Card(name: "Ridge", color: Color(hex: 0x0D9488), icon: .home),
            Card(name: "Bloom", color: Color(hex: 0xD97706), icon: .calendar),
            Card(name: "Tide", color: Color(hex: 0xDB2777), icon: .mail),
            Card(name: "Prism", color: Color(hex: 0x4F46E5), icon: .settings),
            Card(name: "Grove", color: Color(hex: 0x16A34A), icon: .person),
            Card(name: "Ember", color: Color(hex: 0xDC2626), icon: .play),
        ]

        /// The cards in the deck, in order.
        @State private var cards = Array(Self.all.prefix(4))

        /// Which card is at the front - handed on with `$`, never read in the body.
        @State private var turn = 1.0

        /// Whether the cards fan out or stand in a pile: read in the body, so a
        /// change is a new description of the layout, and so is the hand's unit.
        @State private var spread = false

        var body: some View {
            Grid {
                Grid {
                    deck
                }
                .gridRow(0)
                .clipsContent(true)

                HStack {
                    // A CARD JOINS AT THE END: it fades in where the arithmetic
                    // puts it, and the others make room.
                    Button("Add").onClicked {
                        if let next { cards.append(next) }
                    }

                    // A CARD COMES IN AT THE FRONT: it fades in where the front
                    // card stood, and the others move aside - the parameters stay
                    // where they were, so the new card is the one at the front.
                    Button("Insert").onClicked {
                        if let next { cards.insert(next, at: min(front, cards.count)) }
                    }

                    // THE FRONT CARD LEAVES: at once, the others closing up, and
                    // the card behind it comes to the front.
                    Button("Remove").onClicked { remove(cards[front]) }
                }
                .horizontalAlignment(.center)
                .gridRow(1)

                HStack {
                    // A NEW ORDER: each card slides from where it stood.
                    Button("Reverse").onClicked { cards.reverse() }

                    SwitchRow("Spread", $spread)
                }
                .horizontalAlignment(.center)
                .gridRow(2)
            }
            .rows(.fill, .auto, .auto)
        }

        /// The next card not in the deck, if any is left.
        private var next: Card? {
            Self.all.first { !cards.contains($0) }
        }

        /// Where the card at the front stands among the cards.
        private var front: Int {
            min(max(Int(turn.rounded()), 0), cards.count - 1)
        }

        /// `card` leaves the deck, the others closing up: one before the front
        /// card keeps that card in front; the front card's place goes to the one
        /// behind it - where it was the last, the parameters travel to the one before.
        private func remove(_ card: Card) {
            guard cards.count > 1, let leaving = cards.firstIndex(of: card) else { return }
            let shown = front
            cards.remove(at: leaving)
            if leaving < shown {
                $turn.journey.snap(to: Double(shown - 1))
            } else {
                $turn.journey.move(to: Double(min(shown, cards.count - 1)))
            }
        }

        /// The cards, placed around the one at the front.
        private var deck: some View {
            // Read here, in the body: a change of it describes the layout anew,
            // and every card travels from where it was to its new place.
            let fanned = spread
            let count = cards.count

            return MotionLayout(cards, id: \.name, parameters: $turn) { card in
                face(card, large: !fanned)
            } placements: { room, turn, segmentStart in
                (0..<count).map { fanned ? fan($0, turn, room) : pile($0, turn, segmentStart, room) }
            }
            // The pile is swiped a card at a time, the fan scrolled through.
            .axis(
                \.self, input: fanned ? .scroll(.horizontal) : .swipe(.horizontal),
                range: 0...Double(max(count - 1, 0)), snaps: .every(1))
            // A CARD PULLED UP is the hand's alone: let go far enough, it flies
            // out of the deck and leaves it; short of that, it goes back.
            .itemDrag(begins: .perpendicular)
            .onItemDismissed(.up, beyond: 120) { card in remove(card) }
            // `.motion` DRIVES MOVING BETWEEN CARDS, the turn and every change
            // where the parameters stand; `.dynamics` THE CARDS reaching their new
            // places after a card joins, leaves or the order changes.
            .motion(.eased(.milliseconds(400), .cubicOut))
            .dynamics(.spring(response: .milliseconds(300), damping: 1))
        }

        /// Where one card stands in the fan: along an arc and turned with it, the
        /// front card in the middle.
        private func fan(_ index: Int, _ turn: Double, _ room: Rect) -> Placement {
            let step = Double(index) - turn
            let width = min(room.width * 0.3, room.height * 0.55, 140)
            let height = width * 1.4

            return Placement(
                Rect(room.width / 2 - width / 2 + step * width * 0.62,
                     room.height / 2 - height / 2 + abs(step) * width * 0.1, width, height),
                transform: .rotate(step * 8).scale(1 - min(abs(step), 3) * 0.05),
                zIndex: 100 - Int(min(abs(step), 9) * 10))
        }

        /// Where one card stands in the pile: the front card large and straight in
        /// the middle, the others peeking out either side - those passed on the
        /// left, those to come on the right - tilted and smaller the farther they
        /// are. The card the run set out from goes out the way it goes, under the
        /// finger, until it stands beside the pile, then tucks under the new front
        /// card.
        private func pile(_ index: Int, _ turn: Double, _ segmentStart: Double, _ room: Rect) -> Placement {
            let step = Double(index) - turn
            let width = min(room.width * 0.62, room.height * 0.75 / 1.33, 320)
            let height = width * 1.33
            let side: Double = step < 0 ? -1 : 1
            let behind = min(abs(step), 4)

            // Out over most of a card - nought to one - then back under at once.
            let leaving = Double(index) == segmentStart && abs(step) < 1
            let outward = abs(step) < 0.8
            let out = leaving ? (outward ? abs(step) / 0.8 : (1 - abs(step)) / 0.2) : 0

            return Placement(
                Rect(room.width / 2 - width / 2 + side * (behind * 14 + out * width * 1.05),
                     room.height / 2 - height / 2 + behind * 3, width, height),
                transform: .rotate(side * (behind * 2.5 + out * 12)).scale(1 - behind * 0.03),
                opacity: min(max(5 - abs(step), 0), 1),
                zIndex: leaving && outward ? 200 : Int(100 - behind * 10))
        }

        /// One card's face: its color, its icon on a light disc and its name -
        /// the icon in the platform's own color, which shows on the disc in a
        /// light theme and a dark one alike - larger on the pile's larger cards.
        private func face(_ card: Card, large: Bool) -> some View {
            let disc = large ? 88.0 : 56.0
            return ZStack {
                Rectangle()
                    .fill(card.color)

                VStack {
                    ZStack {
                        Rectangle()
                            .fill(.white)
                            .opacity(0.3)

                        Image(.icon(card.icon))
                            .width(disc * 0.55)
                            .height(disc * 0.55)
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)
                    }
                    .width(disc)
                    .height(disc)
                    .horizontalAlignment(.center)

                    Text(card.name)
                        .fontWeight(.bold)
                        .horizontalAlignment(.center)
                }
                .verticalAlignment(.center)
            }
        }
        """#,
        "CheckBoxSample": #"""
        // Sources/Samples/BasicInput/CheckBoxSample.swift
        @State private var agreed = false
        @State private var extras = [false, false, false]

        var body: some View {
            VStack {
                // The ticks are read here, so every box builds this closure.
                DebugInfoLabel()

                CheckBox($agreed)
                    .text("I have read the terms")

                Text(agreed ? "Ticked" : "Not ticked")

                SectionTitle("Several of them")

                ForEach(Array(["Cheese", "Bacon", "Egg"].enumerated()), id: \.offset) { pair in
                    let (index, name) = pair
                    return CheckBox(extras[index])
                        .text(name)
                        .onToggled { ticked in extras[index] = ticked }
                        .id(name)
                }

                Text(chosen.isEmpty ? "Nothing extra" : "With \(chosen.joined(separator: ", "))")
            }
        }

        /// What is ticked, in the order the boxes are drawn.
        private var chosen: [String] {
            ["Cheese", "Bacon", "Egg"].enumerated().filter { extras[$0.offset] }.map { $0.element }
        }
        """#,
        "ClipboardSample": #"""
        // Sources/Samples/Navigation/ClipboardSample.swift
        @Environment(\.application) private var application
        @State private var words = "Copy me somewhere"
        @State private var answer = "nothing copied or pasted yet"

        var body: some View {
            VStack {
                TextField($words)

                Button("Copy")
                    .onClicked(.ignoreWhileRunning) {
                        try await application.clipboard.write(text: words)
                        answer = "copied"
                    }

                // What another application copied pastes here too; nil is an empty clipboard.
                Button("Paste")
                    .onClicked(.ignoreWhileRunning) {
                        guard let pasted = try await application.clipboard.text() else { return answer = "the clipboard is empty" }
                        words = pasted
                        answer = "pasted"
                    }

                Text(answer)
            }
        }
        """#,
        "ColorPickerSample": #"""
        // Sources/Samples/BasicInput/ColorPickerSample.swift
        @State private var tint = Color.steelBlue
        @State private var seeThrough = false
        @State private var changes = 0

        var body: some View {
            VStack {
                ColorPicker($tint)
                    .choosesOpacity(seeThrough)
                    .horizontalAlignment(.center)
                    .onColorChanged { _ in changes += 1 }

                // The swatch wears the same state: the color chosen reaches it
                // with no render of this view.
                Rectangle()
                    .fill($tint)
                    .height(80)

                Text("Changed \(changes) time\(changes == 1 ? "" : "s")")

                SwitchRow("Chooses opacity", $seeThrough)

                // A color the program writes is shown, and heard by nobody: the
                // count stays where it is.
                Button("Back to steel blue")
                    .horizontalAlignment(.center)
                    .onClicked { tint = .steelBlue }
            }
        }
        """#,
        "ComplaintsSample": #"""
        // Sources/Samples/Fundamentals/ComplaintsSample.swift
        /// What the library said while the page showed, oldest first.
        @State private var heard: [String] = []

        /// A list of two, for a write past its end.
        @State private var pair = [1, 2]

        /// How many presses landed.
        @State private var presses = 0

        var body: some View {
            VStack {
                Button("Write past the end of a list")
                    .horizontalAlignment(.center)
                    .onClicked {
                        // A binding to the third element of a list of two: the write is dropped.
                        let third = $pair[2]
                        third.wrappedValue = 3
                    }

                // The second press supersedes the first, whose write is refused.
                Button("Press twice, quickly")
                    .horizontalAlignment(.center)
                    .onClicked(.cancelPrevious) {
                        try? await Task.sleep(for: .seconds(1))
                        presses += 1
                    }

                Text("\(presses) press(es) landed")
                    .horizontalAlignment(.center)

                ForEach(Array(heard.enumerated()), id: \.offset) { item in
                    Text(item.element)
                }
            }
            .onCreated {
                // Each complaint comes on the thread that complained, and is posted here.
                let heard = $heard
                Complaints.route { words in heard.post { $0 + [words] } }
            }
            .onDestroying { Complaints.route(to: nil) }
        }
        """#,
        "ConcurrentAnimationSample": #"""
        // Sources/Samples/Animation/ConcurrentAnimationSample.swift
        @State private var playing = false

        /// One driven state per bar. FOUR of them rather than an array, because a
        /// driven state is ONE image the host reads: a binding into an array has no
        /// image of its own, so there would be nothing for the host to read a bar's
        /// place off. Four names is what four independent movements cost.
        @State private var hop0 = 0.0
        @State private var hop1 = 0.0
        @State private var hop2 = 0.0
        @State private var hop3 = 0.0

        /// What the stage is washing to - a `Color(light:dark:)`, driven: the host
        /// carries the half in force, and a change of theme carries it to the
        /// other half.
        @State private var wash = Palette.accent

        /// How opaque the caption is.
        @State private var breath = 1.0

        /// The four bars, in order - one place to write the list, read by both the
        /// view and the beat.
        private var bars: [Binding<Double>] { [$hop0, $hop1, $hop2, $hop3] }

        var body: some View {
            VStack {
                ZStack {
                    VStack {
                        HStack {
                            ForEach(Array(bars.enumerated()), id: \.offset) { bar in
                                Rectangle()
                                    .fill(Palette.onAccent)
                                    .translationY(bar.element)
                                    .width(14)
                                    .height(46)
                                    .verticalAlignment(.end)
                            }
                        }
                        .horizontalAlignment(.center)
                        .height(92)

                        Text("in concert")
                            .opacity($breath)
                    }
                }
                .style(.card)
                .stroke(.transparent)

                HStack {
                    button("Play") {
                        playing = true

                        var n = 0

                        while playing {
                            let finished = try await beat(n)
                            n += 1

                            // A beat that did not run to the end is what Stop
                            // produces, and starting another over it would fight
                            // whoever pressed it.
                            if !finished { playing = false }
                        }

                        try await $breath.journey.move(to: 1, .eased(.milliseconds(200))).arrived()
                    }
                    .isEnabled(!playing)

                    button("Stop") {
                        playing = false

                        // One stop per state, each leaving the value where it had
                        // got to, so the bars have somewhere honest to come home
                        // from.
                        $wash.journey.stop()
                        $breath.journey.stop()

                        for bar in bars {
                            bar.journey.stop()
                            try await bar.journey.move(to: 0, .eased(.milliseconds(120))).arrived()
                        }
                    }
                    .isEnabled(playing)
                }
                .horizontalAlignment(.center)
            }
            .onDestroying {
                playing = false
            }
        }

        /// One beat: two long movements spanning it, the bars hopping inside them.
        ///
        /// - Parameter n: which beat this is, which decides the color it washes to.
        /// - Returns: whether everything in it ran to the end. False is what Stop
        ///   produces, through `stop()` on each of the states.
        private func beat(_ n: Int) async throws -> Bool {
            // A movement starts as it is sent and is awaited apart, so both of these
            // are running while the bars below hop. Each is its own value on its own
            // state, and the host carries all three on the same frames.
            let washing = $wash.journey.move(to:
                n.isMultiple(of: 2) ? Palette.brand : Palette.accent,
                .eased(.milliseconds(1200), .cubicInOut))

            let breathing = $breath.journey.move(to: 0.25, .eased(.milliseconds(600), .cubicInOut))

            // 4 bars x 300ms = the 1200ms the wash takes, so the wave crosses the
            // stage exactly once per color. A hop that did not run to the end is
            // Stop, and the bars after it must not start: each would be a fresh
            // movement over the one being stopped.
            var hopped = true

            for bar in bars where hopped {
                hopped = try await bar.journey.move(to: -26, .eased(.milliseconds(150), .cubicOut)).arrived()

                if hopped {
                    hopped = try await bar.journey.move(to: 0, .eased(.milliseconds(150), .cubicIn)).arrived()
                }
            }

            // Awaited at the BOTTOM: the beat is over when the longest thing in it
            // is over, not when the last one started is.
            let washed = try await washing.arrived()
            let breathed = try await breathing.arrived()

            try await $breath.journey.move(to: 1, .eased(.milliseconds(300), .cubicInOut)).arrived()

            return hopped && washed && breathed
        }

        /// One of the buttons, both of which look the same: a press while its run
        /// is under way is let go.
        private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
            Button(caption)
                .onClicked(.ignoreWhileRunning, act)
        }
        """#,
        "ConcurrentStateSample": #"""
        // Sources/Samples/State/ConcurrentStateSample.swift
        /// The shared count every task adds to. `$total` - the binding - is what the
        /// tasks capture: it crosses to the cooperative pool, and is posted to.
        @State private var total = 0

        /// How many landed last run, to say out loud that none were lost.
        @State private var expected = 0

        @State private var running = false

        var body: some View {
            VStack {
                // The 200 posts land here as renders: this closure reads `total`, and
                // the reading says how many it was actually built for.
                DebugInfoLabel()

                Text("\(total)")
                    .fontWeight(.bold)

                // The proof: after a run, the count equals what was asked for.
                Text(running
                    ? "Counting on 200 tasks at once…"
                    : (expected == 0
                        ? "Press to count 200 × 100 on 200 concurrent tasks"
                        : "\(total) of \(expected) landed - none lost"))

                Button(running ? "Counting…" : "Count from 200 tasks at once")
                    .isEnabled(!running)
                    .horizontalAlignment(.center)
                    .onClicked(.ignoreWhileRunning) {
                        running = true
                        total = 0
                        expected = 200 * 100

                        // The BINDING: a task cannot write the state, which is the
                        // UI thread's, so it posts to it. Each task counts on its
                        // own and posts once; `post { $0 + counted }` runs every
                        // change over the one before, so all 200 land. Their jobs
                        // are queued before the group ends, so the line after it
                        // finds the total whole.
                        let counter = $total

                        await withTaskGroup(of: Void.self) { group in
                            for _ in 0 ..< 200 {
                                group.addTask {
                                    var counted = 0
                                    for _ in 0 ..< 100 { counted += 1 }
                                    counter.post { [counted] in $0 + counted }
                                }
                            }
                        }

                        running = false
                    }
            }
        }

        // In a handler, just write it: it runs on MainActor, the UI thread.
        // From a task, post it - on every host, the Web included:
        //
        //     total = value
        //     $total.post(value)
        """#,
        "ConnectivitySample": #"""
        // Sources/Samples/Environment/ConnectivitySample.swift
        /// The network, as the host last reported it.
        @Environment(\.device) var device

        var body: some View {
            // The list is the host's answer as given, and a host may report one
            // entry per adapter, so repeats are collapsed for display and the
            // value stays untouched. Sorted, because a Set's own order changes
            // run to run.
            let profiles = Set(device.connectivity.connectionProfiles.map { "\($0)" })
                .sorted()
                .joined(separator: ", ")

            return VStack {
                // The connection is read here, so a change to it builds this
                // closure.
                DebugInfoLabel()

                Text(device.connectivity.networkAccess == .internet ? "online" : "offline")
                    .fontWeight(.bold)

                Text("access · \(device.connectivity.networkAccess)")
                Text("via · \(profiles.isEmpty ? "nothing reported" : profiles)")

                Button("Save to the cloud")
                    .isEnabled(device.connectivity.networkAccess == .internet)
                    .horizontalAlignment(.center)
            }
        }
        """#,
        "ContextMenuSample": #"""
        // Sources/Samples/Navigation/ContextMenuSample.swift
        @State private var items = ["Alpha", "Beta", "Gamma"]
        @State private var chosen = "nothing yet"
        @State private var large = false

        var body: some View {
            VStack {
                // What was chosen is read here, so every menu item that acts
                // builds this closure.
                DebugInfoLabel()

                VStack {
                    ForEach(Array(items.enumerated()), id: \.offset) { pair in
                        let (index, item) = pair
                        return Text(item)
                            .contextMenu {
                                MenuItem("Duplicate")
                                    .icon(ImageSource(light: "menu_duplicate.png", dark: "menu_duplicate_dark.png"))
                                    .onClicked {
                                        items.insert(item + " copy", at: index + 1)
                                        chosen = "duplicated \(item)"
                                    }

                                Menu("Move") {
                                    MenuItem("To the top")
                                        .isEnabled(index > 0)
                                        .onClicked {
                                            items.remove(at: index)
                                            items.insert(item, at: 0)
                                            chosen = "moved \(item) to the top"
                                        }
                                }

                                // A setting: its check follows the state, and
                                // choosing it turns the state over.
                                MenuToggle("Large text", isOn: $large)

                                MenuSeparator()

                                MenuItem("Remove")
                                    .icon(ImageSource(light: "menu_remove.png", dark: "menu_remove_dark.png"))
                                    .role(.destructive)
                                    .onClicked {
                                        items.remove(at: index)
                                        chosen = "removed \(item)"
                                    }
                            }
                    }
                }

                Text("Last: \(chosen)")

                Button("Start again")
                    .horizontalAlignment(.start)
                    .onClicked {
                        items = ["Alpha", "Beta", "Gamma"]
                        chosen = "nothing yet"
                        large = false
                    }
            }
        }
        """#,
        "ConverterSample": #"""
        // Sources/Samples/Fundamentals/ConverterSample.swift
        /// The one value the first three rows are about, in 0 to 1.
        @State private var volume = 0.2

        /// A temperature, kept in Celsius and shown in both scales.
        @State private var celsius = 20.0

        /// Two sides of a rectangle, worked into its area.
        @State private var width = 120.0

        @State private var height = 80.0

        /// What the last row calls the rectangle - a third source, and a text
        /// among the numbers.
        @State private var named = "panel"

        var body: some View {
            // Every row is a closure of its own, and every one of them takes
            // its own reading - which is how you see that NONE of them is ever
            // built again: nothing here reads a value, it is all bindings.
            VStack {
                row("1 · the source, 0 to 1") {
                    // The source, as it is.
                    Slider($volume)
                        .minimum(0)
                        .maximum(1)
                    DebugInfoLabel()
                }

                row("2 · the same state in percent") {
                    // THE SAME STATE IN PERCENT: a second state the host carries,
                    // worked out by an engine following `volume` - and a drag comes
                    // back through `convertBack`, in the source's own terms.
                    Slider($volume.convert { $0 * 100 }.convertBack { $0 / 100 })
                        .minimum(0)
                        .maximum(100)
                    DebugInfoLabel()
                }

                row("3 · a caption from the conversion") {
                    // A caption from the conversion: words the host writes.
                    Text()
                        .text($volume.convert { "\(Int(($0 * 100).rounded()))%" })
                    DebugInfoLabel()
                }

                row("4 · one temperature, two scales") {
                    // TWO STEPPERS ON ONE STATE, IN TWO SCALES - and the steps are
                    // what keep the two captions honest: 5 °C IS 9 °F, exactly, and
                    // the ends line up too (-20 °C = -4 °F, 60 °C = 140 °F), so
                    // every value either stepper can reach is a whole number in
                    // both. A step of one on each would leave the state on 20.56
                    // and the two captions would round it their own way.
                    HStack {
                        Stepper($celsius)
                            .step(5)
                            .minimum(-20)
                            .maximum(60)
                        Text()
                            .text($celsius.convert { "\(Int($0)) °C" })
                    }
                    HStack {
                        Stepper($celsius.convert { $0 * 9 / 5 + 32 }.convertBack { ($0 - 32) * 5 / 9 })
                            .step(9)
                            .minimum(-4)
                            .maximum(140)
                        Text()
                            .text($celsius.convert { "\(Int($0 * 9 / 5 + 32)) °F" })
                    }
                    DebugInfoLabel()
                }

                row("5 · two states into one") {
                    // TWO STATES INTO ONE: an engine following both.
                    Slider($width)
                        .minimum(20)
                        .maximum(200)
                    Slider($height)
                        .minimum(20)
                        .maximum(200)
                    Text()
                        // The sides as they are shown, whole, and their product - not the product of what
                        // the sliders hold, which would disagree with the sides it names.
                        .text(.multi($width, $height).convert { w, h in
                            let (across, down) = (Int(w.rounded()), Int(h.rounded()))
                            return "\(across) × \(down) = \(across * down)"
                        })
                    DebugInfoLabel()
                }

                row("6 · a field is handed the state") {
                    // A FIELD IS HANDED THE STATE TOO: `TextField($named)` reads nothing
                    // at build, and what is typed lands on `named` as the host's
                    // own write - so this row stays at one as well.
                    TextField($named)
                        .placeholder("Call it something")
                    DebugInfoLabel()
                }

                row("7 · as many as you like") {
                    // AS MANY AS YOU LIKE: `.multi` names the states and `convert`
                    // is the arithmetic over them, in the order they were named -
                    // two to ten of them, of any types the host carries. Nothing
                    // is read here, so typing above rewrites this caption without
                    // building it.
                    Text()
                        .text(.multi($named, $width, $height)
                            .convert { "\($0): \(Int($1.rounded())) × \(Int($2.rounded()))" })
                    DebugInfoLabel()
                }
            }
        }

        /// One row: a caption, then the content in a stack of its own, so the
        /// reading taken inside the content is that stack's alone.
        private func row<Content: Views>(_ caption: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
            ZStack {
                VStack {
                    Text(caption)

                    VStack(content: content)
                }
            }
            .style(.card)
            .stroke(Palette.outline)
        }
        """#,
        "Cube3D": #"""
        // Sources/Samples/Interop/Cube3D.swift
        /// What color the cube is painted.
        ///
        /// A closed vocabulary, so it crosses as its member's number, and the host's
        /// registration is handed it back as a `CubeColor` rather than as that number.
        public enum CubeColor: Int32, CaseIterable, HostRepresentable {
            /// Teal.
            case teal = 0

            /// Amber.
            case amber = 1

            /// Violet.
            case violet = 2
        }

        /// The gallery's own cube, declared: its node type, the tier it wears,
        /// and its members, each with its value's type.
        public enum Cube3DContract: ElementContract {
            public static let nodeType: NodeType = "Gallery.Cube3D"
            public static let tiers: [any Contract.Type] = [ViewContract.self]

            /// How long the cube's edge is, as a share of the room the view is given,
            /// 0 through 1. A size HAS a half way, so a change travels and a walk of
            /// it is a cube that grows.
            public static let size = ElementProperty<Self, Double>("size")

            /// Which color the cube is painted. A vocabulary has no half way, so a
            /// change does not travel.
            public static let color = ElementProperty<Self, CubeColor>("color", travels: false)

            /// Whether the cube turns. Stopped, it holds the angle it had.
            public static let isSpinning = ElementProperty<Self, Bool>("isSpinning", travels: false)

            public static let members: [any ContractMember] = [size, color, isSpinning]
        }

        /// A cube drawn on the GPU by a control the application registered with its
        /// host, described here like a built-in one.
        ///
        /// Nothing about the drawing is described here and nothing about the
        /// description is drawn here: this side owns what the cube should be, and the
        /// host owns the frames that make it so.
        public struct Cube3D: ElementView {
            public var node = Node(contract: Cube3DContract.self)

            /// A cube at whatever size, color and motion its modifiers say.
            public init() {}

            /// How long the cube's edge is, as a share of the room the view is given,
            /// 0 through 1.
            public func size(_ value: Double) -> Self {
                setValue(Cube3DContract.size, value)
            }

            /// The same edge, walked by the host from a state.
            ///
            ///     @State private var size = 0.6
            ///
            ///     Cube3D().size($size)
            ///
            ///     Slider($size).minimum(0.2).maximum(1)
            ///
            /// The state is handed to the host, which carries the property from it, so
            /// the view writing this line is not a reader of it: a slider bound to the
            /// same state grows the cube on the host's own frames, and nothing here is
            /// built again for it.
            ///
            /// `.inOut`, because the host reports where a walk has got to, which is
            /// what `$size.journey.value` reads - so `$size.journey.move(to: 1)` grows
            /// the cube the way it moves any other walked value.
            public func size(_ state: Binding<Double>) -> Modified {
                setValue(Cube3DContract.size, on: state, mode: .inOut, kind: .property)
            }

            /// Which color the cube is painted.
            public func color(_ value: CubeColor) -> Self {
                setValue(Cube3DContract.color, value)
            }

            /// Whether the cube turns.
            public func isSpinning(_ value: Bool) -> Self {
                setValue(Cube3DContract.isSpinning, value)
            }

            /// The same, set by the host from a state as it stands: a switch bound to
            /// the state stops and starts the cube, and nothing here is built again.
            public func isSpinning(_ state: Binding<Bool>) -> Modified {
                setValue(Cube3DContract.isSpinning, on: state, mode: .out, kind: .plain)
            }
        }
        """#,
        "Cube3DSample": #"""
        // Sources/Samples/Animation/Cube3DSample.swift
        @State private var size = 0.6
        @State private var color = CubeColor.teal
        @State private var spinning = true

        var body: some View {
            VStack {
                DebugInfoLabel()

                Cube3D()
                    .size($size)
                    .color(color)
                    .isSpinning($spinning)
                    .horizontalAlignment(.center)

                Text()
                    .text($size.journey.convert { "Edge: \(Int($0.value * 100))% of the view" })

                Slider($size)
                    .minimum(0.2)
                    .maximum(1)

                Picker(CubeColor.allCases, selection: $color) { "\($0)".titled }
                    .placeholder("Color")

                Switch($spinning)
                    .text("Spin")
                    .horizontalAlignment(.center)
            }
        }
        """#,
        "DatePickerSample": #"""
        // Sources/Samples/DateTime/DatePickerSample.swift
        @State private var due = CalendarDate(year: 2026, month: 8, day: 2)
        @State private var chosen = ""
        @State private var picks = 0

        var body: some View {
            VStack {
                // `due` is printed below, so picking a day builds this closure; the
                // picker itself is handed the state.
                DebugInfoLabel()

                DatePicker($due)
                    .minimumDate(CalendarDate(year: 2020, month: 1, day: 1))
                    .maximumDate(CalendarDate(year: 2030, month: 12, day: 31))
                    .format(.long)
                    .onDateChanged { date in
                        chosen = date.text
                        picks += 1
                    }

                Text("Due \(due.text)")

                Text(picks == 0
                    ? "onDateChanged has not fired"
                    : "onDateChanged: \(chosen), \(picks) so far")

                // A day written from the TREE is not a pick: the field moves and
                // the count stays where it is.
                Button("Push it to New Year")
                    .horizontalAlignment(.center)
                    .onClicked { due = CalendarDate(year: 2027, month: 1, day: 1) }
            }
        }
        """#,
        "DeviceDisplaySample": #"""
        // Sources/Samples/Environment/DeviceDisplaySample.swift
        /// The main display, as the host measures it.
        @Environment(\.device) var device

        var body: some View {
            VStack {
                // The display is read here, so each change the host reports
                // builds this closure.
                DebugInfoLabel()

                Text("\(Int(device.display.width)) × \(Int(device.display.height)) px")
                    .fontWeight(.bold)

                Text(device.display.density > 0
                    ? "\(Int(device.display.width / device.display.density)) × "
                        + "\(Int(device.display.height / device.display.density)) pt at "
                        + "\(device.display.density)x"
                    : "density not said")

                Text("orientation · \(device.display.orientation)")
                Text("rotation · \(device.display.rotation)")
                Text(device.display.refreshRate > 0
                    ? "refresh · \(Int(device.display.refreshRate)) Hz"
                    : "refresh · not said")
            }
        }
        """#,
        "DeviceInfoSample": #"""
        // Sources/Samples/Environment/DeviceInfoSample.swift
        /// The machine's facts - the formFactor among them, which this gallery
        /// itself builds by.
        @Environment(\.device) var device

        /// The app's facts, from its own manifest.
        @Environment(\.application) var app

        var body: some View {
            VStack {
                // These facts stand still, so this closure stands at one build.
                DebugInfoLabel()

                Text("\(app.info.name) \(app.info.versionString) (\(app.info.buildString))")
                    .fontWeight(.bold)

                Text(app.info.packageName)

                Text("device · \(device.info.manufacturer) \(device.info.model)")
                Text("system · \(device.info.platform) \(device.info.versionString)")
                Text("formFactor · \(device.info.formFactor)")
                Text("virtual · \(device.info.isVirtual.map { $0 ? "yes" : "no" } ?? "not said")")
                Text("name · \(device.info.name.isEmpty ? "not said" : device.info.name)")
            }
        }
        """#,
        "DialogsSample": #"""
        // Sources/Samples/Navigation/DialogsSample.swift
        @Environment(\.window) private var window
        @State private var answer = "nothing asked yet"
        @State private var name = "Draft 1"

        /// What the draft can be done with.
        enum Share: CaseIterable {
            case mail, message, delete

            /// What each says on its button.
            var title: String {
                switch self {
                case .mail: "Mail"
                case .message: "Message"
                case .delete: "Delete"
                }
            }
        }

        var body: some View {
            VStack {
                // The answer is read here, so every dialog that closes builds
                // this closure.
                DebugInfoLabel()

                // One button, nothing to answer: the handler resumes when it is
                // dismissed, so the next line runs with the alert already gone.
                Button("Tell me something")
                    .onClicked(.ignoreWhileRunning) {
                        try await window.alert(
                            "Saved", message: "The draft is safe")
                        answer = "the alert was dismissed"
                    }

                // Ask, await, branch - in one place, which is what an act is for.
                // The cancel says the system's own word.
                Button("Ask me a question")
                    .onClicked(.ignoreWhileRunning) {
                        let ok = try await window.confirm(
                            "Delete draft?", message: "This cannot be undone", accept: "Delete")
                        answer = ok ? "Delete pressed" : "cancelled"
                    }

                // The answer is the action chosen, as a value - nil for the
                // cancel, or a sheet tapped away where the platform allows that.
                Button("Offer me choices")
                    .onClicked(.ignoreWhileRunning) {
                        let choice = try await window.chooseAction(
                            "Share via", among: Share.allCases, caption: \.title, destructive: .delete)
                        answer = choice.map { "\($0.title) chosen" } ?? "nothing chosen"
                    }

                // nil is CANCELLED; an accepted prompt with nothing typed comes
                // back as "" - an empty answer, which is still an answer.
                Button("Ask me to type")
                    .onClicked(.ignoreWhileRunning) {
                        let typed = try await window.prompt(
                            "Rename", message: "A new name for the draft",
                            placeholder: "Name", initialValue: name, maximumLength: 40)
                        if let typed { name = typed }
                        answer = typed.map { "renamed to '\($0)'" } ?? "cancelled"
                    }

                Text(answer)

                Text("the draft is called '\(name)'")
            }
        }
        """#,
        "DragAndDropSample": #"""
        // Sources/Samples/Gestures/DragAndDropSample.swift
        @State private var items = ["Alpha", "Beta", "Gamma"]
        @State private var basket: [String] = []
        @State private var over = false
        @State private var finished = "nothing dragged yet"

        var body: some View {
            VStack {
                // The basket, its light and what the last drag did are read here,
                // so a drop builds this closure.
                DebugInfoLabel()

                SectionTitle("Drag from here")

                HStack {
                    ForEach(items) { item in
                        ZStack {
                            Text(item)
                        }
                        .style(.card)
                        .stroke(Palette.outline)
                        .lineWidth(1)
                        // What travels is decided before the drag starts: a
                        // native drag session needs its payload at once.
                        .draggable(text: item)
                        // The view that was DRAGGED hears when its own drag ends,
                        // wherever it ended.
                        .onDragEnded { finished = "\(item): drop finished" }
                        .id(item)
                    }
                }

                Text(finished)

                SectionTitle("Drop here")

                ZStack {
                    VStack {
                        Text(over
                            ? "let go to drop it"
                            : (basket.isEmpty ? "nothing yet" : "\(basket.count) dropped"))

                        ForEach(Array(basket.enumerated()), id: \.offset) { pair in
                            Text(pair.element)
                        }
                    }
                }
                .style(.card)
                // Lit while something is over it and dark again once it leaves,
                // which is what the two events are for.
                .stroke(over ? Palette.accent : Palette.outline)
                .lineWidth(over ? 2 : 1)
                .onDragOver { over = true }
                .onDragLeave { over = false }
                // A drop is not a leave, so the light comes down here too. Words
                // longer than 1 KB are left out.
                .onDrop { text in
                    basket.append(text.utf8.count <= 1024 ? text : "left out: longer than 1 KB")
                    over = false
                }

                Button("Empty it")
                    .horizontalAlignment(.center)
                    .isEnabled(!basket.isEmpty)
                    .onClicked { basket = [] }
            }
        }
        """#,
        "DrivenReadingSample": #"""
        // Sources/Samples/Driven/DrivenReadingSample.swift
        /// The bar's width, driven - so both readings live here and neither costs
        /// a render.
        @State private var width = 60.0

        var body: some View {
            VStack {
                // NOTHING in this closure reads: the bar is a channel and both
                // readings are CONVERSIONS of it, worked out by the host on its own
                // frames. So this stays at one build while the numbers move on
                // every frame.
                DebugInfoLabel()

                // The bar: one driven property, and the host moves it.
                ZStack {
                    Text("")
                }
                .style(.card)
                .width($width)
                .height(28)
                .lineWidth(0)
                .horizontalAlignment(.start)

                // The two readings, off ONE journey: `destination` is where the
                // value is going and `value` where it has got to.
                Text()
                    .text($width.journey.convert {
                        "going to \(Int($0.destination)) — showing \(Int($0.value))"
                    })

                Text("how far apart the two readings are")

                // The SAME arithmetic drawn: the distance between where the value
                // is going and where it is. It is widest the moment a button is
                // pressed and nought when the bar arrives.
                ZStack {
                    Text("")
                }
                .style(.card)
                .width($width.journey.convert { abs($0.destination - $0.value) })
                .height(10)
                .lineWidth(0)
                .horizontalAlignment(.start)

                HStack {
                    Button("Grow")
                        .onClicked {
                            $width.journey.move(to: 300, .eased(.milliseconds(1600), .cubicOut))
                        }

                    Button("Shrink")
                        .onClicked {
                            $width.journey.move(to: 60, .eased(.milliseconds(1600), .cubicIn))
                        }

                    // Stopping leaves the value where it stands, and the
                    // destination is mirrored onto it - so both readings agree again.
                    Button("Stop")
                        .onClicked { $width.journey.stop() }
                }
            }
        }
        """#,
        "DrivenSample": #"""
        // Sources/Samples/Driven/DrivenSample.swift
        /// Which law the buttons send the marker under - ORDINARY state, read
        /// below so the caption can name it, which is what puts this page's build
        /// count next to a value that moves for nothing.
        @State private var slowly = false

        /// Where the marker sits - the value the HOST carries.
        @State private var offset = 0.0

        /// The rail's color, which the HOST carries with no engine at all.
        @State private var tint = Palette.outline

        /// How far the marker may travel - the rail's width less its own.
        private static let run = 240.0

        var body: some View {
            VStack {
                // WHAT THIS PAGE IS ABOUT, and it takes both halves to say it: the
                // marker crosses and the percentage counts up for no build at all,
                // while the caption below is described from `slowly` - so the only
                // thing that moves this reading is the switch, which it names.
                DebugInfoLabel()

                let law = slowly ? "1600 ms, cubicInOut" : "350 ms, cubicOut"

                ZStack {
                    Grid {
                        Rectangle()
                            .fill($tint)
                            .height(6)
                            .verticalAlignment(.center)

                        Rectangle()
                            .fill(Palette.brand)
                            .width(20)
                            .height(20)
                            .horizontalAlignment(.start)
                            .verticalAlignment(.center)
                            .translationX($offset)
                    }
                    .width(260)
                    .height(28)
                }
                .style(.card)
                .stroke(.transparent)
                .horizontalAlignment(.center)

                // A CONVERSION of the same driven value: the host works the words
                // out on its own frames, from where the marker HAS GOT TO, and
                // nothing here reads anything.
                Text()
                    .text($offset.journey.convert { "\(Int(($0.value / Self.run * 100).rounded()))%" })
                    .fontWeight(.bold)
                    .horizontalAlignment(.center)

                // Off ordinary state: described again each time the switch is
                // thrown.
                Text("Sent under \(law)")
                    .horizontalAlignment(.center)

                HStack {
                    button("Empty") { go(to: 0) }
                    button("Half") { go(to: 0.5) }
                    button("Full") { go(to: 1) }
                }
                .horizontalAlignment(.center)

                SwitchRow("Take the long way", $slowly)
            }
        }

        /// One place to be sent to, under whichever law the switch asks for.
        private func go(to place: Double) {
            let law: Motion = slowly ? .eased(.milliseconds(1600), .cubicInOut) : .eased(.milliseconds(350), .cubicOut)

            $offset.journey.motion = law
            offset = Self.run * place

            $tint.journey.motion = law
            tint = place > 0 ? Palette.accent : Palette.outline
        }

        /// One of the buttons, all of which look the same.
        private func button(_ caption: String, _ act: @escaping @MainActor () throws -> Void) -> Button {
            Button(caption)
                .onClicked(act)
        }
        """#,
        "EngineSample": #"""
        // Sources/Samples/Driven/EngineSample.swift
        /// The reading as it stood when Lap was last pressed - ORDINARY state, so
        /// the same reading that costs nothing driven costs a render here.
        @State private var lap = "-"

        /// What the clock says.
        @State private var reading = "0.0 s"

        /// What the button says.
        @State private var caption = "Start"

        /// Whether the clock is running - ordinary state that no view reads, so
        /// a write to it renders nothing; the engine FOLLOWS it, so a write to it
        /// wakes the engine.
        @State private var running = false   // followed by the engine, read by no view

        /// How long the clock has run, in milliseconds - the engine's own to
        /// count up, read by no view: the reading is worked out FROM it, so
        /// nothing outside this page ever needs the number itself.
        @State private var elapsed = 0.0   // the engine's own count

        var body: some View {
            VStack {
                // What says the clock below ticks without a render: nothing in
                // this closure reads the running time, so it stands at one build
                // while the digits change ten times a second. Lap is what says
                // the reading can move at all - it is read here.
                DebugInfoLabel()

                ZStack {
                    // Off a driven state: written ten times a second, never described.
                    Text()
                        .text($reading)
                        .fontWeight(.bold)
                        .horizontalAlignment(.center)
                }
                .style(.card)
                .stroke(.transparent)
                .horizontalAlignment(.center)

                // Off state: the same reading, described every time it lands.
                Text("Lap: \(lap)")
                    .horizontalAlignment(.center)

                HStack {
                    Button()
                        .text($caption)
                        .onClicked {
                            running.toggle()
                            caption = running ? "Stop" : "Start"
                        }

                    button("Lap") { lap = reading }

                    button("Reset") {
                        running = false
                        caption = "Start"
                        elapsed = 0
                        reading = "0.0 s"
                        // The one write here that IS described, and the one that
                        // costs this button its render.
                        lap = "-"
                    }
                }
                .horizontalAlignment(.center)
            }
            .engine(tracking: $running) { cycle in
                guard running else { return .wait }

                elapsed += cycle.elapsed

                let tenths = Int(elapsed / 100)
                reading = "\(tenths / 10).\(tenths % 10) s"

                return .again
            }
        }

        /// The buttons whose caption is their own rather than a driven state's.
        private func button(_ caption: String, _ act: @escaping @MainActor () throws -> Void) -> Button {
            Button(caption)
                .onClicked(act)
        }
        """#,
        "EnvironmentSample": #"""
        // Sources/Samples/Environment/EnvironmentSample.swift
        /// Who is signed in - the object a whole branch shares. Its properties are
        /// `@State`, so a write to one rebuilds exactly the views that READ it.
        @MainActor
        private final class Session {
            @State var name = "guest"
            @State var visits = 0
        }

        /// Reads the session - resolved by TYPE from the nearest `.environment` above,
        /// no initializer argument anywhere on the way down.
        private struct VisitBadge: View {
            @Environment var session: Session

            var body: some View {
                VStack {
                    // The session is read in THIS closure, so a write to it builds
                    // this closure and nothing above it.
                    DebugInfoLabel()

                    Text("\(session.name) - \(session.visits) visit(s)")
                }
            }
        }

        /// Writes through the environment: `session.$name` is the provided object's
        /// own state for the name, handed to the TextField whole - typing lands on it and
        /// rebuilds the badge, which reads `name`.
        private struct NameEditor: View {
            @Environment var session: Session

            var body: some View {
                TextField(session.$name)
                    .placeholder("Signed-in name")
            }
        }

        @State private var session = Session()
        @State private var preview = Session()

        var body: some View {
            VStack {
                // The provider hands a reference on and reads no property of it,
                // so a write in the object is none of this closure's business.
                DebugInfoLabel()

                VStack {
                    VisitBadge()

                    Button("Visit again")
                        .horizontalAlignment(.center)
                        .onClicked { session.visits += 1 }

                    NameEditor()
                }
                .environment(session)

                VisitBadge()
                    .environment(preview)
            }
        }
        """#,
        "Explanations": #"""
        // Sources/Samples/Navigation/PopoverSample.swift
        @State private var explained: String?

        var body: some View {
            HStack {
                Button("Sync").onClicked { explained = "Sync keeps your mail the same on every device." }
                Button("Backup").onClicked { explained = "Backup saves a copy of your mail every night." }
            }
            .popover(item: $explained) { words in
                Text(words).width(220).padding(16)
            }
        }
        """#,
        "FilesSample": #"""
        // Sources/Samples/Navigation/FilesSample.swift
        @Environment(\.window) private var window
        @Environment(\.application) private var application
        @State private var words = "Words to keep"
        @State private var saved: ChosenFile?
        @State private var answer = "nothing opened or saved yet"
        @State private var dropping = false

        var body: some View {
            VStack {
                TextEditor($words)
                    .height(96)

                // The contents go first; nil is a cancel.
                Button("Save…")
                    .onClicked(.ignoreWhileRunning) {
                        let text = FileType("Text", extensions: ["txt"])
                        saved = try await window.saveFile(Array(words.utf8), name: "Note", types: [text])
                        answer = saved.map { "saved as \($0.name)" } ?? "cancelled"
                    }

                // No file longer than 1 KB is read whole: one byte past it says it is longer.
                Button("Open…")
                    .onClicked(.ignoreWhileRunning) {
                        let text = FileType("Text", extensions: ["txt", "md"])
                        guard let file = try await window.openFile(types: [text]) else {
                            return answer = "cancelled"
                        }
                        let start = try await file.read(atMost: 1025)
                        guard start.count <= 1024 else { return answer = "\(file.name) is longer than 1 KB" }
                        words = String(decoding: start, as: UTF8.self)
                        answer = "opened \(file.name)"
                    }

                // The system opens it in the application it gives its kind.
                Button("Launch the saved file")
                    .isEnabled(saved != nil)
                    .onClicked(.ignoreWhileRunning) {
                        if let saved { try await saved.launch() }
                    }

                Button("Launch swift.org")
                    .onClicked(.ignoreWhileRunning) { try await application.launch("https://www.swift.org") }

                // A text file dragged from the system onto it is read into the editor.
                ZStack {
                    Text(dropping ? "let go to read it" : "Drop a text file here")
                }
                .stroke(dropping ? Palette.accent : Palette.outline)
                .lineWidth(dropping ? 2 : 1)
                .onDragOver { dropping = true }
                .onDragLeave { dropping = false }
                .onDrop(files: [FileType("Text", extensions: ["txt", "md"])], policy: .waitForPrevious) { files in
                    dropping = false
                    let start = try await files[0].read(atMost: 1025)
                    guard start.count <= 1024 else { return answer = "\(files[0].name) is longer than 1 KB" }
                    words = String(decoding: start, as: UTF8.self)
                    answer = "dropped \(files[0].name)"
                }

                Text(answer)
            }
        }
        """#,
        "FillSample": #"""
        // Sources/Samples/Layout/FillSample.swift
        /// Whether the room between the words is a space rather than a fill.
        @State private var spaced = false

        /// How many taps the clear fill heard.
        @State private var taps = 0

        var body: some View {
            VStack {
                SectionTitle("Offered or left")

                // Along a stack a fill is as long as it says: the one between the words says nothing, so it gets no
                // room and is gone; the one at the foot says 24 and stands 24 tall. A space pushes, taking the rest.
                VStack {
                    Text("Top")
                    if spaced {
                        Space()
                            .background(Palette.accent)
                            .shape(.roundedRectangle(10))
                    } else {
                        Fill(Palette.accent)
                            .shape(.roundedRectangle(10))
                    }
                    Text("Bottom")
                    Fill(Palette.brand)
                        .height(24)
                        .shape(.roundedRectangle(6))
                }
                .spacing(8)
                .height(160)

                Switch($spaced)
                    .text("A space, not a fill")

                SectionTitle("Across")

                // As wide as it says, as tall as its row offers.
                HStack {
                    Fill(Palette.accent)
                        .width(4)
                    Text("Take the room you are given.")
                        .fontAttributes(.italic)
                        .padding(horizontal: 0, vertical: 8)
                }
                .spacing(10)

                SectionTitle("Made of")

                // Each over a stripe of color, so what it lets through shows.
                Grid {
                    tile("Color", Fill(Palette.accent), over: .tomato).gridColumn(0)
                    tile("Gradient", Fill(Palette.identity), over: .gold).gridColumn(1)
                    tile("Blur", Fill(.blur(.regular)), over: .steelBlue).gridColumn(2)
                    tile("Glass", Fill(.glass(.regular)), over: .white).gridColumn(3)
                }
                .columns(.fill, .fill, .fill, .fill)
                .height(110)
                .shape(.roundedRectangle(14))
                .clipsContent(true)

                SectionTitle("For the hand")

                // Clear, only outlined, it still hears a tap anywhere on it.
                ZStack {
                    Text(taps == 0 ? "Tap anywhere here" : taps == 1 ? "Tapped once" : "Tapped \(taps) times")
                        .horizontalAlignment(.center)
                        .verticalAlignment(.center)
                    Fill()
                        .shape(.roundedRectangle(14))
                        .stroke(Palette.outline)
                        .lineWidth(1)
                        .onTapped { taps += 1 }
                }
                .height(80)
            }
            .spacing(12)
        }

        /// A rounded fill with its name in its middle, standing alike on every side in a stripe of `stripe`.
        private func tile(_ name: String, _ fill: Fill, over stripe: Color) -> ZStack {
            ZStack {
                Fill(stripe)
                fill
                    .shape(.roundedRectangle(10))
                    .margin(12)
                Text(name)
                    .fontSize(12)
                    .fontWeight(.bold)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
            }
        }
        """#,
        "FollowsAFinger": #"""
        // Sources/Samples/Shapes/CanvasSample.swift
        @State private var trail: [Point] = []

        // Where a finger went, drawn where it went: the canvas reports in
        // its own coordinates, which is what the instructions use.
        var body: some View {
            VStack {
                // The trail is read by the drawing, so every report the
                // finger makes builds this closure and draws again.
                DebugInfoLabel()

                // The outline is the canvas's own edge, and nothing is
                // drawn past it.
                Canvas {
                    Draw.strokeColor(Palette.outline)
                    Draw.lineWidth(1)
                    Draw.strokeRoundedRectangle(x: 1, y: 1, width: 298, height: 118, cornerRadius: 8)

                    Draw.fillColor(Palette.accent)
                    for point in trail {
                        Draw.fillEllipse(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                    }
                }
                .width(300)
                .height(120)
                .horizontalAlignment(.center)
                .onPressed { trail = [$0] }
                .onDragged { trail = Array((trail + [$0]).suffix(120)) }
                .onReleased { _ in }

                Button("Clear")
                    .horizontalAlignment(.center)
                    .isEnabled(!trail.isEmpty)
                    .onClicked { trail = [] }
            }
        }
        """#,
        "FollowsState": #"""
        // Sources/Samples/Shapes/CanvasSample.swift
        @State private var bars = [0.4, 0.75, 0.3, 0.95, 0.6]

        var body: some View {
            VStack {
                // The bars are read by the drawing below, so changing
                // one builds this closure - which is what redraws it.
                DebugInfoLabel()

                Canvas {
                    for (index, value) in bars.enumerated() {
                        let height = value * 90
                        let x = Double(index) * 44

                        Draw.fillColor(Palette.accent)
                        Draw.fillRoundedRectangle(
                            x: x, y: 100 - height, width: 32, height: height, cornerRadius: 4)

                        Draw.textColor(Palette.text)
                        Draw.fontSize(11)
                        Draw.text(
                            "\(Int(value * 100))", x: x, y: 104, width: 32, height: 14,
                            horizontalAlignment: .center)
                    }
                }
                .height(120)

                Button("Different numbers")
                    .horizontalAlignment(.center)
                    .onClicked { bars = bars.map { _ in Double.random(in: 0.15...1) } }
            }
        }
        """#,
        "FoundationProbeSample": #"""
        // Sources/Samples/DateTime/FoundationProbeSample.swift
        import Foundation

        #if canImport(Android)
        import Android
        #endif

        @State private var rows: [(String, String)] = []

        var body: some View {
            VStack {
                // The probe's answers are read here, so running it builds this
                // closure once.
                DebugInfoLabel()

                ForEach(rows, id: \.0) { row in
                    VStack {
                        Text(row.0)

                        Text(row.1)
                    }
                }
            }
            .onCreated {
                let hostZone = try await TimeZoneInfo.local()

                #if canImport(Android)
                // Android's tz database is packed in a format Foundation cannot
                // read, so the current zone comes up GMT. The TZ variable is read
                // before any detection, and ICU's own tzdata answers for the named
                // zone - the host says where the device is, once, before the first
                // TimeZone use.
                setenv("TZ", hostZone, 1)
                #endif

                var found: [(String, String)] = []
                found.append(("Host TimeZoneInfo.local()", hostZone))

                let now = Date()
                let zone = TimeZone.current
                found.append(("TimeZone.current",
                    "\(zone.identifier), \(offsetText(zone.secondsFromGMT(for: now)))"))

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = zone
                let parts = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second], from: now)
                found.append(("Calendar, local time",
                    "\(parts.year ?? 0)-\(pad(parts.month))-\(pad(parts.day)) "
                    + "\(pad(parts.hour)):\(pad(parts.minute)):\(pad(parts.second))"))

                let host = try await ClockTime.now()
                found.append(("Host ClockTime.now()", host.text))

                found.append(("ISO8601Format", now.ISO8601Format()))

                if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                    let t = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                    found.append(("Calendar, +1 day",
                        "\(t.year ?? 0)-\(pad(t.month))-\(pad(t.day))"))
                }

                let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))
                found.append(("Offset on 2026-01-15",
                    january.map { offsetText(zone.secondsFromGMT(for: $0)) } ?? "no date"))

                // Whether the tz DATABASE is readable at all, apart from whether
                // the current zone was detected - the difference between "zones do
                // not work" and "the host has to say which zone, once". The zone
                // asked for is the one the HOST named, not one written down here:
                // the question is the same wherever the machine is, and a literal
                // would only ask it about somebody else's city.
                if let named = TimeZone(identifier: hostZone) {
                    let winter = january.map { offsetText(named.secondsFromGMT(for: $0)) } ?? "no date"
                    found.append(("TimeZone(\"\(hostZone)\")",
                        "\(offsetText(named.secondsFromGMT(for: now))) now, \(winter) in January"))
                } else {
                    found.append(("TimeZone(\"\(hostZone)\")", "nil - the identifier is unknown here"))
                }

                found.append(("Locale.current", Locale.current.identifier))

                let json = (try? JSONEncoder().encode(["probe": 1])) ?? Data()
                found.append(("JSONEncoder", String(decoding: json, as: UTF8.self)))

                for row in found { print("FOUNDATION-PROBE \(row.0): \(row.1)") }
                rows = found
            }
        }

        private func pad(_ value: Int?) -> String {
            let v = value ?? 0
            return v < 10 && v >= 0 ? "0\(v)" : "\(v)"
        }

        private func offsetText(_ seconds: Int) -> String {
            let sign = seconds < 0 ? "-" : "+"
            let h = abs(seconds) / 3600
            let m = (abs(seconds) % 3600) / 60
            return "GMT\(sign)\(pad(h)):\(pad(m))"
        }
        """#,
        "Gallery.Looks": #"""
        // Sources/Gallery/Looks.swift
        /// What one surface of the gallery is made of - its bars, its window, its
        /// sidebar, its sidebar sliding over the page.
        enum SurfaceMaterial: String, CaseIterable {
            /// The platform's own.
            case platform

            /// Nothing: what stands behind shows through, sharp.
            case clear

            /// A blur: what stands behind shows through, blurred.
            case blur

            /// A blur in a light tint of the gallery's color.
            case tintedBlur

            /// The platform's glass: what stands behind bent and lit through it.
            case glass

            /// The platform's glass in a tint of the gallery's color.
            case tintedGlass

            /// The gallery's color.
            case color

            /// The gallery's gradient, violet into orange - offered for the bars.
            case gradient

            /// What the Appearance sample calls it.
            var name: String {
                switch self {
                case .platform: return "The platform's own"
                case .clear: return "Clear"
                case .blur: return "Blur"
                case .tintedBlur: return "Blur, tinted"
                case .glass: return "Glass"
                case .tintedGlass: return "Glass, tinted"
                case .color: return "Color"
                case .gradient: return "Gradient"
                }
            }

            /// The materials `surface` offers: the gradient on the bars alone.
            static func offered(on surface: GallerySurface) -> [SurfaceMaterial] {
                surface == .bar ? allCases : allCases.filter { $0 != .gradient }
            }

            /// Whether the surface shows a blur.
            var showsBlur: Bool {
                self == .blur || self == .tintedBlur
            }

            /// Whether the surface shows a color.
            var showsColor: Bool {
                self == .tintedBlur || self == .tintedGlass || self == .color
            }
        }

        /// One surface's look: what it is made of, in which color, how thick a blur.
        struct SurfaceLook: Equatable {
            var material: SurfaceMaterial
            var color: AccentChoice
            var blur: Blur

            /// The blurs offered, thinnest first.
            static let blurs: [Blur] = [.ultraThin, .thin, .regular, .thick, .ultraThick]

            /// The platform's own surface - the gallery's own color, or a thick
            /// blur, once one is chosen.
            static let platform = SurfaceLook(material: .platform, color: .gallery, blur: .thick)

            /// The gallery's own color for the part it paints.
            static let galleryOwn = SurfaceLook(material: .color, color: .gallery, blur: .thick)

            /// Bars that paint nothing: what stands behind them shows.
            static let clear = SurfaceLook(material: .clear, color: .gallery, blur: .thick)

            /// The words on a bar of this look: the brand's on the gallery's color
            /// where it carries none of the theme's, the theme's on anything else it
            /// paints or lets through; nil on the platform's own.
            var barWords: Color? {
                switch material {
                case .platform: return nil
                case .color: return color.carriesThemesWords ? Palette.text : Palette.onBrand
                case .gradient: return Palette.onBrand
                default: return Palette.text
                }
            }

            /// The material `surface` is: its blur where it is one, tinted in its
            /// color - the system's accent being `system` - where it is tinted, the
            /// color where it is one; nil for the platform's own.
            func material(system: Color, for surface: GallerySurface) -> Material? {
                switch material {
                case .platform: return nil
                case .clear: return .color(.transparent)
                case .blur: return .blur(blur)
                case .tintedBlur: return .blur(blur.tint(color.tint(system: system, for: surface)))
                case .glass: return .glass(.regular)
                case .tintedGlass: return .glass(.regular.tint(color.tint(system: system, for: surface)))
                case .color: return .color(color.color(system: system, for: surface))
                case .gradient: return .gradient(Palette.identity)
                }
            }
        }

        /// The look the gallery wears in one theme: its bars, and what its window, its
        /// sidebar and its sidebar sliding over the page are made of. Kept as one line
        /// of words, so a scene keeps a theme's whole look under one key.
        struct ThemeLook: Equatable, RawRepresentable {
            var bars: SurfaceLook
            var window: SurfaceLook
            var sidebar: SurfaceLook
            var sidebarOverlay: SurfaceLook

            init(bars: SurfaceLook, window: SurfaceLook, sidebar: SurfaceLook, sidebarOverlay: SurfaceLook) {
                (self.bars, self.window, self.sidebar, self.sidebarOverlay) = (bars, window, sidebar, sidebarOverlay)
            }

            /// The light theme's look the gallery opens in: clear bars, and the
            /// platform's own window and sidebar - on the Mac the sidebar the
            /// platform's glass.
            static var light: ThemeLook {
                #if APPKIT
                let sidebar = SurfaceLook(material: .glass, color: .gallery, blur: .thick)
                #else
                let sidebar = SurfaceLook.platform
                #endif
                return ThemeLook(bars: .clear, window: .platform, sidebar: sidebar, sidebarOverlay: .platform)
            }

            /// The dark theme's look the gallery opens in: on Windows a window of the
            /// desktop blurred in the gallery's violet, its sidebar letting it
            /// through, and over the page the page blurred in the same violet; on
            /// the Mac a thick blur of the desktop in the gallery's own color, made
            /// from that window, its sidebar the platform's glass in it; on the iPad
            /// and the iPhone those colors, the sidebar the same glass beside the
            /// page and over it; on the Web, GNOME and Android - which blur nothing
            /// behind a window - those colors, whole.
            static var dark: ThemeLook {
                #if WINUI
                let violet = SurfaceLook(material: .tintedBlur, color: .violet, blur: .thick)
                return ThemeLook(
                    bars: SurfaceLook(material: .platform, color: .violet, blur: .thick), window: violet, sidebar: .platform,
                    sidebarOverlay: violet)
                #elseif APPKIT
                let glass = SurfaceLook(material: .tintedGlass, color: .gallery, blur: .thick)
                return ThemeLook(
                    bars: .clear, window: SurfaceLook(material: .tintedBlur, color: .gallery, blur: .thick), sidebar: glass,
                    sidebarOverlay: glass)
                #elseif UIKIT
                let glass = SurfaceLook(material: .tintedGlass, color: .gallery, blur: .thick)
                return ThemeLook(bars: .clear, window: .galleryOwn, sidebar: glass, sidebarOverlay: glass)
                #else
                return ThemeLook(bars: .clear, window: .galleryOwn, sidebar: .galleryOwn, sidebarOverlay: .galleryOwn)
                #endif
            }

            /// The look as words: each surface's material, color and blur - the
            /// bars', the window's, the sidebar's beside the page and over it.
            var rawValue: String {
                [bars, window, sidebar, sidebarOverlay].flatMap { surface in
                    [surface.material.rawValue, surface.color.rawValue,
                     String(SurfaceLook.blurs.firstIndex(of: surface.blur) ?? 0)]
                }.joined(separator: " ")
            }

            /// The look its words say; nil for words another version wrote.
            init?(rawValue: String) {
                let words = rawValue.split(separator: " ").map(String.init)
                guard words.count == 12 else { return nil }
                var surfaces: [SurfaceLook] = []
                for at in stride(from: 0, to: 12, by: 3) {
                    guard let material = SurfaceMaterial(rawValue: words[at]), let color = AccentChoice(rawValue: words[at + 1]),
                          let blur = Int(words[at + 2]), SurfaceLook.blurs.indices.contains(blur)
                    else { return nil }
                    surfaces.append(SurfaceLook(material: material, color: color, blur: SurfaceLook.blurs[blur]))
                }
                self.init(bars: surfaces[0], window: surfaces[1], sidebar: surfaces[2], sidebarOverlay: surfaces[3])
            }
        }

        /// A theme's look as the user chose it: the gallery's own, or one composed in
        /// the Appearance sample. A scene keeps the CHOICE - the gallery's own is drawn
        /// afresh at every start, as this version of the gallery makes it, never kept
        /// as what it was when the scene was.
        enum LookChoice: Equatable, RawRepresentable, Codable {
            /// The look that suits the platform best: `ThemeLook.light` or `.dark`.
            case own

            /// A look the user put together.
            case composed(ThemeLook)

            /// The look the choice wears in a theme, `dark` or not.
            func look(dark: Bool) -> ThemeLook {
                switch self {
                case .own: return dark ? .dark : .light
                case .composed(let look): return look
                }
            }

            /// "own", or "composed" and the look's words.
            var rawValue: String {
                switch self {
                case .own: return "own"
                case .composed(let look): return "composed " + look.rawValue
                }
            }

            /// The choice its words say; nil for words another version wrote - a look
            /// kept whole - so the gallery starts in its own.
            init?(rawValue: String) {
                if rawValue == "own" {
                    self = .own
                } else if rawValue.hasPrefix("composed "), let look = ThemeLook(rawValue: String(rawValue.dropFirst(9))) {
                    self = .composed(look)
                } else {
                    return nil
                }
            }
        }

        // Sources/Styles/GalleryColors.swift
        /// A part of the gallery a color paints - each has a color of the gallery's
        /// own, made to sit with the platform's look.
        enum GallerySurface {
            case bar, window, sidebar, sidebarOverlay

            /// The gallery's own color for this part, in each theme: in the dark,
            /// the colors its Windows window wears in the gallery's violet acrylic -
            /// the window, the bar a breath lighter, the sidebar and the menu over the
            /// page as dark as a list of samples on it (`Palette.shade`).
            var own: Color {
                switch self {
                case .bar: Color(light: Color(hex: 0xEFEBFA), dark: Color(hex: 0x2E255A))
                case .window: Color(light: Color(hex: 0xF7F5FC), dark: Color(hex: 0x2A2154))
                case .sidebar: Color(light: Color(hex: 0xEEEBF6), dark: Color(hex: 0x221A43))
                case .sidebarOverlay: Color(light: Color(hex: 0xF7F5FC), dark: Color(hex: 0x221A43))
                }
            }
        }
        """#,
        "Gallery.SessionStyle": #"""
        // Sources/Gallery/SessionStyle.swift
        /// The kinds of window the galleries' scene opens beside its gallery windows -
        /// each a window of that scene. See `GalleryScene`.
        extension WindowType where Value == Void {
            /// The window that chooses the gallery's font.
            static let fonts = WindowType("gallery.fonts")

            /// The window that chooses the gallery's accent.
            static let colors = WindowType("gallery.colors")
        }

        extension WindowType where Value == Int {
            /// A window per swatch number - one kind, a window for each value.
            static let swatch = WindowType("gallery.swatch")
        }

        /// What the galleries' scene KEEPS with itself - handed back with it when the
        /// system restores the application's windows, so the galleries come back in the
        /// font and the color they were left in.
        extension SceneKey where Value == String {
            /// The font the gallery's preview is set in.
            static let font = SceneKey("gallery.font")
        }

        extension SceneKey where Value == LookChoice {
            /// The look chosen for the light theme and for the dark: the gallery's own,
            /// or one the user composed.
            static let lightLook = SceneKey("gallery.look.light")
            static let darkLook = SceneKey("gallery.look.dark")
        }

        /// A color a gallery wears - on its bars, or behind its pages, where its look
        /// asks for one.
        enum AccentChoice: String, CaseIterable {
            case gallery
            case system
            case violet
            case teal
            case coral
            case graphite

            /// The gallery's own colors, without the system's accent.
            static let own: [AccentChoice] = [.violet, .teal, .coral, .graphite]

            /// What the Colors window calls it.
            var name: String {
                switch self {
                case .gallery: return "The gallery's own"
                case .system: return "The system's accent"
                case .violet: return "Violet"
                case .teal: return "Teal"
                case .coral: return "Coral"
                case .graphite: return "Graphite"
                }
            }

            /// The color on `surface`, the system's accent being `system` - one in
            /// both themes but the gallery's own, which is made for each part and
            /// theme.
            func color(system: Color, for surface: GallerySurface) -> Color {
                switch self {
                case .gallery: return surface.own
                case .system: return system
                case .violet: return AppColors.violet
                case .teal: return Color(hex: 0x0F766E)
                case .coral: return Color(hex: 0xC2410C)
                case .graphite: return Color(hex: 0x374151)
                }
            }

            /// Whether words on the color are the theme's own rather than white: the
            /// gallery's own colors are as light as the theme.
            var carriesThemesWords: Bool { self == .gallery }

            /// The color laid over a blur - a seventh of an accent, the blur showing
            /// through it; most of the gallery's own, whose blur is its color.
            func tint(system: Color, for surface: GallerySurface) -> Color {
                color(system: system, for: surface).opacity(self == .gallery ? Self.ownTint : 0.15)
            }

            /// How much of the gallery's own color lies over a blur or glass: more on
            /// the iPad and the iPhone, whose glass is grayer, so that their sidebar
            /// wears the Mac's color.
            private static var ownTint: Double {
                #if UIKIT
                0.85
                #else
                0.7
                #endif
            }
        }

        /// What the galleries look like, and how their tool windows stand - stepping
        /// aside for another scene, floating on top.
        ///
        /// Held by the galleries' scene and handed to its gallery windows and to its
        /// Fonts and Colors windows, so the Fonts and Colors windows change every
        /// gallery window at once, with nothing passed between them.
        @MainActor
        final class SessionStyle {
            /// The font the preview is set in - empty for the platform's own.
            @State(sceneKey: .font) var font = ""

            /// The look chosen for each theme - the gallery's own, until the
            /// Appearance sample composes another.
            @State(sceneKey: .lightLook) var lightChoice = LookChoice.own
            @State(sceneKey: .darkLook) var darkChoice = LookChoice.own

            /// The look the gallery wears in the light theme; a look written here is
            /// the user's own composition.
            var lightLook: ThemeLook {
                get { lightChoice.look(dark: false) }
                set { lightChoice = .composed(newValue) }
            }

            /// The look the gallery wears in the dark theme; a look written here is
            /// the user's own composition.
            var darkLook: ThemeLook {
                get { darkChoice.look(dark: true) }
                set { darkChoice = .composed(newValue) }
            }

            /// The look the gallery wears in a theme, `dark` or not.
            func look(dark: Bool) -> ThemeLook {
                dark ? darkLook : lightLook
            }

            /// How the bars' buttons stand where the host draws them itself: on glass
            /// on the Web, the gallery's own look for them.
            @State var toolbarStyle = SessionStyle.ownToolbarStyle

            /// Whether the bars' buttons stand in the gallery's own look, where the
            /// host draws them itself (`AppStyles.sheet(barsInOwnLook:)`).
            @State var barsInOwnLook = false

            /// The gallery's own look for the bars' buttons: glass on the Web, the
            /// platform's own elsewhere.
            static var ownToolbarStyle: ToolbarStyle {
                #if WEB
                .glass
                #else
                .system
                #endif
            }

            /// Whether the Fonts and Colors windows hide while another scene is the
            /// one in front.
            @State var hidesTools = false

            /// Whether the Fonts and Colors windows float above the application's
            /// other windows rather than going under them.
            @State var floatsTools = false
        }
        """#,
        "GalleryApp": #"""
        // Sources/GalleryApp.swift
        /// The gallery application.
        ///
        /// An application is what every scene SHARES - here its styles. The galleries
        /// are one scene, its windows as many as the user opens: see
        /// Gallery/GalleryScene.swift.
        struct GalleryApp: Application {
            /// The application as it runs - where its styles go.
            @Environment(\.application) private var application

            /// What every gallery shares, written as the application is made.
            init() {
                // The styles a control of the gallery asks for by name. A color in a
                // style follows the theme by itself. See Styles/AppStyles.swift.
                application.styles = AppStyles.sheet

                // On GNOME the gallery opens in the dark theme, the look it wears
                // best there; the Appearance sample turns it back.
                #if GTK
                application.colorScheme = .dark
                #endif
            }

            /// The galleries - launch opens a gallery window, and *File ▸ New Window* one more; the scratchpads; and one
            /// About window for the whole application, in a scene of its own. See `ScenesSample`.
            var body: some Scene {
                GalleryScene()
                ScratchpadScene()
                AboutScene()
            }
        }
        """#,
        "GalleryContract": #"""
        // Sources/Samples/Interop/GalleryContract.swift
        /// The gallery's own acts and events - the ones with no control behind them.
        ///
        /// A host registers a function or a raise under each name, and this declares
        /// what each one takes, answers and carries, the way the library declares its
        /// own. The names are the APPLICATION's, so they are the same wherever it
        /// runs; what answers them is the host's.
        public enum GalleryContract: ApplicationTier {
            public static let name = "Gallery"

            /// Writes a line to the platform's own log, where its tools read it.
            public static let log = ElementAct<Self, String, Void>("Gallery.Log")

            /// The battery's level, 0 through 1, and whether it is charging.
            public static let batteryLevel = ElementAct<Self, Void, (Double, Bool)>("Gallery.BatteryLevel")

            /// Declared here and registered nowhere: calling it shows what an act no
            /// performer answers does.
            public static let nobody = ElementAct<Self, Void, Void>("Gallery.Nobody")

            /// The battery reported: its level and whether it is charging.
            public static let batteryChanged =
                ElementEvent<Self, (Double, Bool)>("Gallery.BatteryChanged")

            /// The network came or went: whether the internet is reachable.
            public static let connectivityChanged =
                ElementEvent<Self, Bool>("Gallery.ConnectivityChanged")

            public static let members: [any ContractMember] = [
                log, batteryLevel, nobody, batteryChanged, connectivityChanged,
            ]
        }
        """#,
        "GalleryLink": #"""
        // Sources/Gallery/GalleryLink.swift
        /// What a gallery link names: `stateui-gallery://sample/tap` - or, on the Web,
        /// the page's address ending `#sample/tap` - is the Tap sample.
        enum GalleryLink {
            /// The sample a link names; nil for a link of anything else.
            static func sample(in address: String) -> String? {
                let parts = address.split(separator: "/", omittingEmptySubsequences: false)
                guard let place = parts.lastIndex(where: { $0 == "sample" || $0.hasSuffix("#sample") }),
                      place + 1 < parts.count
                else { return nil }
                let id = parts[place + 1].prefix { $0.isLetter || $0.isNumber }
                return id.isEmpty ? nil : String(id)
            }

            /// The link to the sample `id`: the Gallery's own scheme, or a fragment of the page on the Web.
            static func sample(_ id: String) -> String {
                #if WEB
                "#sample/\(id)"
                #else
                "stateui-gallery://sample/\(id)"
                #endif
            }
        }
        """#,
        "GalleryScene": #"""
        // Sources/Gallery/GalleryScene.swift
        /// The galleries - a SCENE: as many gallery windows as the user opens, and
        /// the windows they open beside them, all sharing what the scene holds.
        ///
        /// What the scene holds is the gallery's LOOK (`SessionStyle` - the font and
        /// the accent its Fonts and Colors windows choose), handed to the gallery
        /// windows and to the Fonts and Colors windows: nothing is passed between the
        /// Colors window and the bars it paints.
        /// What one gallery window is doing - where it is, its bar, its log, its
        /// catalog - is that window's own: see Gallery/GalleryWindow.swift.
        struct GalleryScene: Scene {
            /// What every gallery window looks like - kept with the scene. See
            /// SessionStyle.swift.
            @State private var style = SessionStyle()

            /// The scene's windows: the gallery windows, which launch and *File ▸ New
            /// Window* open; its Fonts and Colors windows, which read the scene's
            /// look and may step aside while another scene is in front or float above
            /// the application's other windows; its inspector; and a swatch per number.
            var body: some Scene {
                let style = self.style

                WindowGroup { GalleryWindow(style: style) }

                Window(.fonts) { FontsPage() }
                    .hidesWhenInactive(style.hidesTools)
                    .floatsOnTop(style.floatsTools)
                    .environment(style)

                Window(.colors) { ColorsPage() }
                    .hidesWhenInactive(style.hidesTools)
                    .floatsOnTop(style.floatsTools)
                    .environment(style)

                Window(.debugInspector) { DebugInspector() }

                WindowGroup(.swatch) { number in SwatchPage(number: number) }
            }
        }
        """#,
        "GalleryViewSample": #"""
        // Sources/Samples/Collections/GalleryViewSample.swift
        /// Every card the gallery can hold - the gallery's groups, each its name
        /// and its picture as the home page shows it - dealt in this order.
        static let all: [Card] = [
            Card(name: "Fundamentals", art: "cat_fundamentals.png"),
            Card(name: "Driven values", art: "cat_driven.png"),
            Card(name: "Using state", art: "cat_state.png"),
            Card(name: "Animation", art: "cat_animation.png"),
            Card(name: "Controls", art: "cat_basicinput.png"),
            Card(name: "Text & typing", art: "cat_text.png"),
            Card(name: "Layout", art: "cat_layout.png"),
            Card(name: "Styles", art: "cat_styles.png"),
            Card(name: "Shapes", art: "cat_shapes.png"),
            Card(name: "Items and Cards", art: "cat_collections.png"),
            Card(name: "Gestures", art: "cat_gestures.png"),
            Card(name: "Media", art: "cat_media.png"),
        ]

        /// One card's face.
        struct Card: Hashable {
            let name: String
            let art: String
        }

        /// The four shapes, as the picker offers them.
        enum Shape: CaseIterable, Hashable {
            case wheel, fan, row, deck

            var arrangement: GalleryArrangement {
                switch self {
                case .wheel: .default
                case .fan: .fan
                case .row: .row
                case .deck: .deck
                }
            }

            var title: String {
                switch self {
                case .wheel: "Wheel"
                case .fan: "Fan"
                case .row: "Row"
                case .deck: "Deck"
                }
            }
        }

        @State private var cards = Array(Self.all.prefix(7))
        @State private var shape = Shape.wheel
        @State private var shown = 0
        @State private var shaded = true
        @State private var rightToLeft = false
        @State private var opened = "tap one"
        @State private var moves = 0

        var body: some View {
            // A GRID rather than a stack: the board takes whatever room is left
            // over, which a stack cannot give a child - and a gallery wants it all.
            Grid {
                Grid {
                    Rectangle()
                        .fill(Palette.raised)

                    // THE WHOLE CONTROL: the run made below - one card per item, each
                    // named by its name - and one word for the shape they stand in.
                    gallery
                        .arrangement(shape.arrangement)
                        .position($shown)
                        .onItemActivated { name in opened = "opened \(name)" }
                        // Another card in the middle, swiped or assigned.
                        .onPositionChanged { _ in moves += 1 }
                }
                // RIGHT TO LEFT the cards stand in the mirror, as a row of views
                // does, and the swipe that moves them on goes the other way.
                .layoutDirection(rightToLeft ? .rightToLeft : .inherited)
                .gridRow(0)
                // The cards stay ON the board: one mid-crossing between two shapes,
                // or turned far out in a small room, is cut at the board's edge
                // rather than painted over the page.
                .clipsContent(true)

                // A LIVE READING: the position binding is written as the run
                // moves - and the dots read the SAME state, which is the whole of
                // how the two controls are joined.
                VStack {
                    // INSIDE these braces, because that is where `shown`, `opened`
                    // and `moves` are read - the dots and the caption are written
                    // from them - so a swipe builds this closure as each card comes
                    // to the middle, not on every frame of the movement.
                    DebugInfoLabel()

                    PositionDots()
                        .count(cards.count)
                        .position(shown)
                        .dotColor(Palette.outline)
                        .currentDotColor(Palette.accent)
                        .horizontalAlignment(.center)

                    Text("\(cards[front].name) · card \(shown + 1) of \(cards.count) · \(opened) · moved \(moves)")
                }
                .gridRow(1)

                HStack {
                    // A CARD JOINS AT THE END, or comes in at the front, fading in
                    // where the shape puts it; the front card leaves at once and
                    // the others close up.
                    Button("Add").onClicked {
                        if let next { cards.append(next) }
                    }

                    Button("Insert").onClicked {
                        if let next { cards.insert(next, at: front) }
                    }

                    Button("Remove").onClicked {
                        guard cards.count > 1 else { return }
                        cards.remove(at: front)
                        // The last card gone, the one before it comes to the front.
                        shown = min(shown, cards.count - 1)
                    }
                }
                .horizontalAlignment(.center)
                .gridRow(2)

                HStack {
                    Button("Back")
                        .isEnabled(shown > 0)
                        .onClicked { shown -= 1 }

                    Button("Next")
                        .isEnabled(shown < cards.count - 1)
                        .onClicked { shown += 1 }
                }
                .horizontalAlignment(.center)
                .gridRow(3)

                HStack {
                    // THE SHAPE, one word: the cards travel to the new one.
                    Picker(Shape.allCases, selection: $shape) { $0.title }

                    SwitchRow("Shaded", $shaded)

                    SwitchRow("Right to left", $rightToLeft)
                }
                .horizontalAlignment(.center)
                .gridRow(4)
            }
            .rows(.fill, .auto, .auto, .auto, .auto)
        }

        /// The next card not in the gallery, if any is left.
        private var next: Card? {
            Self.all.first { !cards.contains($0) }
        }

        /// Where the card in front stands among the cards.
        private var front: Int {
            min(max(shown, 0), cards.count - 1)
        }

        /// The run, either way the switch is set - and the two are worth watching
        /// side by side. SHADED, a card going away is darkened by a view drawn
        /// over it and keeps a quarter of its fade, so what is under it stays
        /// mostly hidden; FADED, the same card goes transparent and the card
        /// behind it shows through, which on a wheel is the next card rather than
        /// the board.
        ///
        /// The shade wears the card's own corners, and that is why it is the
        /// application's to give: nothing in the library knows what shape a card
        /// has.
        private var gallery: GalleryView<[Card], String> {
            let run = GalleryView(cards, id: \.name) { card in
                // A picture and its name. Where the card stands and which way
                // it faces is the SHAPE's, and this knows nothing about it.
                face(card)
            }

            guard shaded else { return run }

            // THE FAR CARDS DARKEN RATHER THAN FADE. A faded card shows
            // whatever is behind it, which on a wheel is the next card - so
            // depth is a shade drawn OVER the card. It wears the card's own
            // corners, which is why the view is the application's to give.
            // A quarter of the fade is left beside it, unless `.fade(_:)` says
            // otherwise.
            return run.shade(
                Rectangle()
                    .fill(Color(hex: 0x000000)))
        }

        /// One card's face - a picture and its name, and nothing at all about where
        /// the card is or which way it faces. That is the gallery's, and keeping
        /// the two apart is what lets one run of cards wear four shapes.
        private func face(_ card: Card) -> some View {
            ZStack {
                Grid {
                    Image(ImageSource(card.art))
                        .contentMode(.fill)

                    Text(card.name)
                        .fontWeight(.bold)
                        .lineBreak(.tailTruncation)
                        .verticalAlignment(.end)
                }
                .clipsContent(true)
            }
            .style(.card)
            .lineWidth(0)
        }
        """#,
        "GalleryWindow": #"""
        // Sources/Gallery/GalleryWindow.swift
        /// One gallery window - launch opens the first, and *File ▸ New Window* one
        /// more. What a window is doing is its own: where it is (`Navigation` - the
        /// section, what is pushed and presented, whether the menu is open), what its
        /// bar says (`WindowBarState`), what it has said about its life (`WindowLog`)
        /// and the catalog of samples it shows. What it looks like is its scene's,
        /// handed to it: every gallery window wears the one look the Fonts and Colors
        /// windows choose.
        ///
        /// Each sample owns its own `@State`, declared on the sample itself - and since
        /// the catalog this window keeps carries the samples, that state survives for
        /// as long as the window does, pushes and pops included. Another gallery
        /// window keeps a catalog of its own.
        struct GalleryWindow: View {
            /// What every gallery window looks like - its scene's. See
            /// SessionStyle.swift.
            let style: SessionStyle

            /// Where this window is, and every move it can make. See
            /// Gallery/Navigation.swift.
            @State private var nav = Navigation()

            /// What this window's bar says - written by the Window bar sample.
            @State private var bar = WindowBarState()

            /// What this window has said about its life - its phase, watched by
            /// `WindowPhaseLog` and read by the Lifecycle sample.
            @State private var log = WindowLog()

            /// WHERE THE CATALOG IS KEPT, so that it is built once rather than on
            /// every render - a hundred samples, each holding the window's objects and
            /// bindings that go on reading through to its state.
            @State private var kept = KeptCatalog()

            var body: some View {
                let nav = self.nav
                let style = self.style
                let bar = self.bar
                let log = self.log

                return MainPage(
                    catalog: kept.catalog {
                        Catalog(nav: nav, style: style, bar: bar, log: log)
                    },
                    nav: nav,
                    style: style,
                    log: log,
                    bar: bar)
            }
        }
        """#,
        "GeometryReaderSample": #"""
        // Sources/Samples/Layout/GeometryReaderSample.swift
        @State private var slot = Rect(0, 0, 0, 0)
        @State private var window = Rect(0, 0, 0, 0)
        @State private var safe = Rect(0, 0, 0, 0)

        @State private var width = 220.0

        var body: some View {
            VStack {
                // `slot`, `window` and `safe` are read in these braces - the three
                // lines below print all of them - so every frame report builds
                // this closure, which is the whole cost of watching a frame.
                DebugInfoLabel()

                // THE PARENT, DRAWN in a gentle tint, because `slot` below is
                // measured against THIS box and the numbers say nothing until
                // there is something on the screen for them to be relative to.
                // It fills the page's width, so narrowing the panel walks its x
                // in towards the middle.
                VStack {
                    Text("the parent")

                    // The reader's content is built FROM the measurement, which
                    // is the reader's own @State. The three handlers write the
                    // page's states instead, and the three lines below print
                    // them - so a settled frame builds the reader AND the page.
                    GeometryReader { frame in
                        Text("\(Int(frame.width)) × \(Int(frame.height))")
                            .fontWeight(.bold)
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)
                    }
                    // Driven: the host carries the width, and no render
                    // describes it.
                    .width($width)
                    .height(120)
                    .horizontalAlignment(.center)
                    // Reporting is a modifier on ANY view - one handler per
                    // space. Nothing is measured unless something asks: a view
                    // without a handler is not even subscribed.
                    .onFrameChanged { slot = $0 }
                    .onFrameChanged(in: .global) { window = $0 }
                    .onFrameChanged(in: .safeArea) { safe = $0 }
                }

                Slider($width)
                    .minimum(140)
                    .maximum(340)

                // Where the panel sits, in three spaces. The first is against the
                // tinted box above, which is why that box is drawn at all.
                Text("in its parent · \(Int(slot.x)), \(Int(slot.y))")

                Text("in the window · \(Int(window.x)), \(Int(window.y))")

                Text("in the safe area · \(Int(safe.x)), \(Int(safe.y))")

                Button("Animate the width")
                    .horizontalAlignment(.center)
                    .onClicked {
                        // The width describes nothing: the host carries the width and
                        // the slider's thumb off the same state, and the frame reports
                        // say where the panel actually got to.
                        $width.journey.move(to: $width.journey.value < 240 ? 340 : 140)
                    }
            }
        }
        """#,
        "GridList": #"""
        // Sources/Samples/Collections/ItemsViewSample.swift
        @State private var opened: Int?

        static let hues: [Color] = [.tomato, .orange, .teal, .steelBlue, .purple, .firebrick]

        var body: some View {
            Grid {
                // Columns at least 100 wide: as many as the width holds.
                ItemsView(0..<120) { number in
                    Text("\(number)")
                        .fontWeight(.bold)
                        .height(72)
                        .background(Self.hues[number % Self.hues.count])
                }
                .itemsLayout(.grid(minimumItemWidth: 100, spacing: 8))
                .onItemActivated { opened = $0 }
                .gridRow(0)

                DebugInfoLabel()
                    .gridRow(1)

                Text(opened.map { "Tile \($0) opened." } ?? "Open a tile.")
                    .gridRow(1)
            }
            .rows(.fill, .auto)
        }
        """#,
        "GridPlacement": #"""
        // Sources/Samples/Layout/GridSample.swift
        @State private var wideSecondColumn = true

        var body: some View {
            VStack {
                // `wideSecondColumn` is read here, so flipping its switch builds
                // this closure - and the cells cross to their new places.
                DebugInfoLabel()

                Grid {
                    // One cell down the whole left side, beside two that stay in
                    // a row each.
                    GridCell(text: "Column 0, Rows 0 and 1", color: Color(hex: 0xE53935))
                        .gridRowSpan(2)

                    GridCell(text: "Column 1, Row 0", color: Color(hex: 0x1E88E5))
                        .gridColumn(1)

                    GridCell(text: "Column 1, Row 1", color: Color(hex: 0x8E24AA))
                        .gridRow(1)
                        .gridColumn(1)

                    GridCell(text: "Row 2, spanning both columns", color: Color(hex: 0xF4511E))
                        .gridRow(2)
                        .gridColumnSpan(2)
                }
                .rows(.fixed(64, count: 2), .auto)
                .columns(.fill, .proportional(wideSecondColumn ? 2 : 1))

                // Changing a definition patches the grid in place: the cells keep
                // their controls and only the column widths move.
                SwitchRow("Second column twice as wide", $wideSecondColumn)
                    .horizontalAlignment(.center)
            }
        }

        /// One colored cell, composed rather than built inline - and placed with
        /// `.gridRow`, `.gridColumn` and the spans like any other view.
        private struct GridCell: View {
            let text: String
            let color: Color

            var body: some View {
                Text(text)
            }
        }
        """#,
        "GroupedList": #"""
        // Sources/Samples/Collections/ItemsViewSample.swift
        @State private var counts = true

        struct Shelf {
            let name: String
            let items: [String]
        }

        static let shelves = [
            Shelf(name: "Fruit", items: ["Apple", "Pear", "Plum", "Cherry", "Quince", "Apricot"]),
            Shelf(name: "Vegetables", items: ["Leek", "Carrot", "Parsnip", "Beetroot", "Celery"]),
            Shelf(name: "Bakery", items: ["Rye loaf", "Bagel", "Croissant", "Pretzel"]),
            Shelf(name: "Dairy", items: ["Butter", "Kefir", "Cheddar", "Quark", "Cream", "Yoghurt"]),
            Shelf(name: "Pantry", items: ["Rice", "Lentils", "Flour", "Oats", "Honey", "Salt"]),
            Shelf(name: "Drinks", items: ["Water", "Tea", "Coffee", "Juice"]),
        ]

        var body: some View {
            Grid {
                SwitchRow("Counts", $counts)
                    .gridRow(0)

                // A group per shelf, named so two shelves may hold the same item.
                ItemsView(groups: Self.shelves.map { (shelf: Shelf) -> Section<String> in
                    let group = Section(shelf.items) { item in
                        Text(item)
                    }
                    .id(shelf.name)
                    .header(Text(shelf.name)
                        .fontWeight(.bold))

                    return counts
                        ? group.footer(Text("\(shelf.items.count) items"))
                        : group
                })
                .gridRow(1)

                DebugInfoLabel()
                    .gridRow(2)
                    .horizontalAlignment(.end)
            }
            .rows(.auto, .fill, .auto)
        }
        """#,
        "GrowingWords": #"""
        // Sources/Samples/Layout/LivingLayoutSample.swift
        @State private var long = false

        var body: some View {
            VStack {
                // The box travels to the width the new words take; they show as
                // it arrives, never broken on the way. Shorter words show at once.
                Button(long ? "Show every detail" : "Details")
                    .horizontalAlignment(.center)

                SwitchRow("Longer words", $long)
                    .horizontalAlignment(.center)
            }
        }
        """#,
        "HTTPRequestSample": #"""
        // Sources/Samples/Environment/HTTPRequestSample.swift
        @Environment(\.application) private var application
        @State private var said = "Ask for the weather"

        var body: some View {
            VStack {
                // What came back is read here, so an answer builds this closure.
                DebugInfoLabel()

                Button("Weather in Kraków")
                    .onClicked(.cancelPrevious) {
                        said = "Asking…"
                        do {
                            let response = try await application.send(HTTPRequest(
                                "https://api.open-meteo.com/v1/forecast?latitude=50.06&longitude=19.94"
                                    + "&current=temperature_2m,wind_speed_10m"))
                            // Any status is an answer: only no answer at all throws.
                            guard response.status == 200 else {
                                said = "The server answered \(response.status)"
                                return
                            }
                            let temperature = Self.number("temperature_2m", in: response.text)
                            let wind = Self.number("wind_speed_10m", in: response.text)
                            said = "\(temperature) °C, wind \(wind) km/h"
                        } catch let failure as StateUIError {
                            said = "No answer: \(failure.message)"
                        }
                    }
                    .horizontalAlignment(.center)

                Text(said)
            }
        }

        /// The number after `"name":` in the answer's `current` part - as much of JSON as two numbers need.
        private static func number(_ name: String, in json: String) -> String {
            let current = json.split(separator: "\"current\":").last ?? ""
            guard let found = current.firstRange(of: "\"\(name)\":") else { return "?" }
            return String(current[found.upperBound...].prefix { "-.0123456789".contains($0) })
        }
        """#,
        "HoldSample": #"""
        // Sources/Samples/Gestures/HoldSample.swift
        @State private var taps = 0
        @State private var holds = 0
        @State private var longHolds = 0

        var body: some View {
            VStack {
                // The counts are read here, so every tap and hold builds this closure.
                DebugInfoLabel()

                ZStack {
                    Text("Tap or hold this box")
                }
                .style(.card)
                .stroke(Palette.outline)
                .lineWidth(1)
                .onTapped { taps += 1 }
                .onHeld { holds += 1 }

                ZStack {
                    Text("Hold this one a second")
                }
                .style(.card)
                .stroke(Palette.outline)
                .lineWidth(1)
                .onHeld(minimum: .seconds(1)) { longHolds += 1 }

                Text("Tapped \(taps), held \(holds), held a second \(longHolds)")
            }
        }
        """#,
        "HomeScreenSample": #"""
        // Sources/Samples/MotionLayout/HomeScreenSample.swift
        /// One icon: its name, which is its identity, its glyph and its color.
        struct HomeIcon: Hashable {
            let name: String
            let glyph: Icon
            let color: Color
        }

        /// Every icon, board after board: where one stands in the order is where
        /// it stands on the screen.
        static let all: [HomeIcon] = {
            let glyphs: [(String, Icon)] = [
                ("Mail", .mail), ("Calendar", .calendar), ("Clock", .clock), ("Photos", .star),
                ("Music", .play), ("Contacts", .person), ("Settings", .settings), ("Health", .heart),
                ("Home", .home), ("Files", .copy), ("Notes", .edit), ("Search", .search),
                ("Share", .share), ("Cloud", .upload), ("Store", .download), ("Links", .link),
                ("Vault", .lock), ("Tips", .info), ("Alerts", .warning), ("Podcasts", .pause),
                ("Sync", .refresh), ("Tasks", .checkmark), ("Menu", .menu), ("More", .more),
                ("Map", .forward), ("News", .add), ("Books", .back), ("Weather", .up),
                ("Trash", .delete), ("Inbox", .down), ("Focus", .close), ("Budget", .remove),
                ("Friends", .person), ("Journal", .edit), ("Timer", .clock), ("Favorites", .star),
                ("Fitness", .heart), ("Videos", .play), ("Wallet", .lock), ("Backup", .upload),
                ("Reader", .info), ("Garden", .home), ("Chat", .mail), ("Agenda", .calendar),
                ("Remote", .settings), ("Shortcuts", .link), ("Albums", .copy), ("Compass", .forward),
            ]
            let colors: [Color] = [
                Color(hex: 0x7C3AED), Color(hex: 0x2563EB), Color(hex: 0x0D9488), Color(hex: 0xD97706),
                Color(hex: 0xDB2777), Color(hex: 0x4F46E5), Color(hex: 0x16A34A), Color(hex: 0xDC2626),
            ]
            return glyphs.enumerated().map { index, glyph in
                HomeIcon(name: glyph.0, glyph: glyph.1, color: colors[index % colors.count])
            }
        }()

        /// How many icons stand across a board and down it: as many as fit the
        /// room at an icon's own size - 84 by 96 - six at most each way.
        struct Fit: Equatable {
            var columns = 4
            var rows = 5

            var perBoard: Int { columns * rows }

            /// The fit of `room`.
            static func of(_ room: Rect) -> Fit {
                guard room.width > 0, room.height > 0 else { return Fit() }
                return Fit(columns: min(max(Int((room.width - 16) / 84), 1), 6),
                           rows: min(max(Int((room.height - 16) / 96), 1), 6))
            }

            /// The board of this grid that shows most of the icons `page` of
            /// `before` showed - the first of two that show as many - of `count`:
            /// a turned phone keeps its place among the icons.
            func board(showing page: Int, of before: Fit, count: Int) -> Int {
                let shown = page * before.perBoard ..< min((page + 1) * before.perBoard, count)
                var best = (board: 0, icons: 0)
                for board in 0..<max((count + perBoard - 1) / perBoard, 1) {
                    let here = board * perBoard ..< min((board + 1) * perBoard, count)
                    let icons = shown.clamped(to: here).count
                    if icons > best.icons { best = (board, icons) }
                }
                return best.board
            }
        }

        /// How the boards turn - and the dots with them: one state, one motion.
        static let turning = Motion.spring(response: .milliseconds(380), damping: 0.86)

        /// The icons, in order.
        @State private var icons = Self.all

        /// Which board is in front - handed on with `$`, never read in the body.
        @State private var board = 0.0

        /// The icon the hand holds, lifted: larger, so the hand knows it has it.
        @State private var lifted: String?

        /// The room the boards stand in, as the host feeds it - no body reads it -
        /// and the grid it fits, which the body reads: a new grid is a new
        /// description, and every icon travels to its new place.
        @State private var room = Rect.zero
        @State private var fit = Fit()

        var body: some View {
            let (count, fit) = (icons.count, self.fit)
            let boards = max((count + fit.perBoard - 1) / fit.perBoard, 1)

            return Grid {
                Grid {
                    // THE BOARDS: a unit of the parameters is the room's width, so a
                    // board is the room however wide it grows. Each board is a
                    // keyframe: the icons are placed once a board, and between
                    // two they go straight - as the arithmetic says they do.
                    MotionLayout(icons, id: \.name, parameters: $board) { icon in
                        // A VIEW OF ITS OWN: a new order builds no icon again,
                        // only the one lifted or let go.
                        HomeTile(icon: icon, lifted: lifted == icon.name)
                    } placements: { room, board in
                        (0..<count).map { Self.place($0, board, room, fit) }
                    }
                    .axis(
                        \.self, input: .pages(.horizontal), range: 0...Double(boards - 1), keyframes: .every(1),
                        snaps: .every(1))
                    // HELD, AN ICON LEAVES ITS BOARD for the hand: each move
                    // gives it the slot under the hand, and the others travel to
                    // make room; held still at an edge, the boards turn under it.
                    // Taken, it lifts, so the hand knows it has it; let go, it
                    // settles back.
                    .itemDrag(begins: .longPress)
                    .onItemDragged { drag in
                        switch drag.phase {
                        case .began:
                            lifted = drag.item.name
                        case .ended, .cancelled:
                            lifted = nil
                        default:
                            // The icon under the hand gives the held one its place.
                            if let over = drag.over, let place = icons.firstIndex(of: over) { move(drag.item, to: place) }
                            // At an edge, standing there or pushed against it fast, the board turns.
                            if drag.still >= .milliseconds(500) || Self.pushes(drag) {
                                turn(at: drag.at, in: drag.room, of: boards)
                            }
                        }
                    }
                    .motion(Self.turning)
                }
                .gridRow(0)
                .clipsContent(true)
                // THE GRID THE ROOM FITS: a turned phone or a window grown or
                // shrunk moves icons to other boards, or makes them larger.
                .frame($room)
                .engine(following: $room) { _ in fitted() }

                // THE DOTS wear the same parameters - one state, so one motion: they go
                // with the hand and with every throw, no body read of it.
                MotionLayout(Array(0..<boards), parameters: $board) { _ in
                    Rectangle()
                        .fill(Palette.text)
                } placements: { room, board in
                    (0..<boards).map { dot($0, of: boards, board, room) }
                }
                .motion(Self.turning)
                .height(16)
                .gridRow(1)
            }
            .rows(.fill, .auto)
        }

        /// The grid the room fits now, written where it changed - the board in
        /// front the one that shows most of what it showed, at once, as the
        /// icons travel to their new places.
        private func fitted() {
            let now = Fit.of(room)
            guard now != fit else { return }
            let showing = now.board(showing: Int(board.rounded()), of: fit, count: icons.count)
            fit = now
            if Double(showing) != board { $board.journey.snap(to: Double(showing)) }
        }

        /// `icon` taken out of its place and put at `slot`: a new order, which
        /// the others travel to.
        private func move(_ icon: HomeIcon, to slot: Int) {
            guard let from = icons.firstIndex(of: icon), from != slot else { return }
            icons.remove(at: from)
            icons.insert(icon, at: slot)
        }

        /// Whether the hand reached the edge it stands at going that way faster
        /// than 600 points a second.
        private static func pushes(_ drag: ItemDrag<HomeIcon>) -> Bool {
            drag.at.x > drag.room.width - 24 && drag.speed.x > 600 || drag.at.x < 24 && drag.speed.x < -600
        }

        /// The board on the side of the room `point` stands at the edge of, if
        /// there is one that way.
        private func turn(at point: Point, in room: Rect, of boards: Int) {
            let page = Int(board.rounded())
            if point.x > room.width - 24, page < boards - 1 { $board.journey.move(to: Double(page + 1)) }
            if point.x < 24, page > 0 { $board.journey.move(to: Double(page - 1)) }
        }

        /// Where the icon at `slot` stands: on its board, in its row and column
        /// of `fit`, the boards side by side a room's width apart - larger where
        /// the room gives a cell more than an icon's own size.
        static func place(_ slot: Int, _ board: Double, _ room: Rect, _ fit: Fit) -> Placement {
            let (page, cell) = slot.quotientAndRemainder(dividingBy: fit.perBoard)
            let width = (room.width - 16) / Double(fit.columns)
            let height = (room.height - 16) / Double(fit.rows)
            let x = (Double(page) - board) * room.width + 8 + Double(cell % fit.columns) * width
            let y = 8 + Double(cell / fit.columns) * height

            // The icon at its own size in the middle of its cell, made larger
            // about its middle as far as the cell lets it: drawn, it covers its
            // own cell and no other, so a press takes the icon under it.
            return Placement(
                Rect(x + (width - 84) / 2, y + (height - 96) / 2, 84, 96),
                transform: .scale(min(width / 84, height / 96)))
        }

        /// Where the dot of `page` stands under the boards: lit as its board comes
        /// in front.
        private func dot(_ page: Int, of pages: Int, _ board: Double, _ room: Rect) -> Placement {
            let x = room.width / 2 + (Double(page) - Double(pages - 1) / 2) * 16

            return Placement(
                Rect(x - 4, room.height / 2 - 4, 8, 8),
                opacity: 0.25 + 0.75 * max(1 - abs(board - Double(page)), 0))
        }

        /// One icon: its glyph on a light disc on a rounded square of its color -
        /// the glyph in the platform's own color, which shows on the disc in a
        /// light theme and a dark one alike - and its name under it; larger while
        /// the hand holds it.
        struct HomeTile: View {
            let icon: HomeIcon
            let lifted: Bool

            var body: some View {
                VStack {
                    ZStack {
                        Rectangle()
                            .fill(icon.color)

                        Rectangle()
                            .fill(.white)
                            .opacity(0.3)
                            .width(42)
                            .height(42)
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)

                        Image(.icon(icon.glyph))
                            .width(26)
                            .height(26)
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)
                    }
                    .width(60)
                    .height(60)
                    .horizontalAlignment(.center)

                    Text(icon.name)
                        .horizontalAlignment(.center)
                }
                .verticalAlignment(.center)
                // Lifted while the hand holds it, on a spring of its own that goes
                // a little past and back.
                .scale(lifted ? 1.18 : 1)
                .motion(.spring(response: .milliseconds(260), damping: 0.55), .transform)
            }
        }
        """#,
        "HostTimeSample": #"""
        // Sources/Samples/DateTime/HostTimeSample.swift
        @State private var zone = ""
        @State private var clocks: [(String, String)] = []
        @State private var season = ""

        /// A few zones a user will recognize, including one at half past the
        /// hour - Kolkata is +05:30, and an offset that crosses as whole minutes
        /// is what makes that ordinary rather than a special case.
        static let cities = [
            "UTC", "America/New_York", "Europe/Warsaw", "Asia/Kolkata", "Asia/Tokyo",
        ]

        var body: some View {
            VStack {
                // What the host answered is read here, so each ask builds this
                // closure again.
                DebugInfoLabel()

                Text("Here: \(zone.isEmpty ? "…" : zone)")
                    .fontWeight(.bold)

                Text(season)

                ForEach(clocks, id: \.0) { clock in
                    HStack {
                        Text(clock.0)
                            .horizontalAlignment(.start)

                        Text(clock.1)
                            .horizontalAlignment(.end)
                    }
                }

                Button("Read again")
                    .horizontalAlignment(.center)
                    .onClicked(.ignoreWhileRunning) { try await read() }
            }
            .onCreated { try await read() }
        }

        /// One reading: the zone, the host's clock, and each city seen from it.
        private func read() async throws {
            zone = try await TimeZoneInfo.local()

            let now = try await ClockTime.now()
            let here = try await TimeZoneInfo.utcOffset()
            let winter = try await TimeZoneInfo.utcOffset(
                on: CalendarDate(year: 2026, month: 1, day: 15))

            season = "Offset now \(offsetText(here)), on 15 January \(offsetText(winter))"

            var found: [(String, String)] = []
            for city in Self.cities {
                let there = try await TimeZoneInfo.utcOffset(of: city)
                found.append((city, "\(shifted(now, by: there - here).text)  \(offsetText(there))"))
            }

            clocks = found
        }

        /// The same time of day, seen from another zone: seconds since midnight plus
        /// the difference between the two offsets, wrapped into the day.
        private func shifted(_ time: ClockTime, by difference: Duration) -> ClockTime {
            let midnight = time.hour * 3600 + time.minute * 60 + time.second
            let moved = midnight + Int(difference.components.seconds)
            let day = (moved % 86400 + 86400) % 86400

            return ClockTime(hour: day / 3600, minute: (day % 3600) / 60, second: day % 60)
        }

        /// `UTC+05:30`, written by hand - a formatter is Foundation, and this sample is
        /// about not needing one.
        private func offsetText(_ offset: Duration) -> String {
            let minutes = Int(offset.components.seconds) / 60
            let sign = minutes < 0 ? "-" : "+"
            let hh = abs(minutes) / 60
            let mm = abs(minutes) % 60

            return "UTC\(sign)\(hh < 10 ? "0" : "")\(hh):\(mm < 10 ? "0" : "")\(mm)"
        }
        """#,
        "IconButtonSample": #"""
        // Sources/Samples/BasicInput/IconButtonSample.swift
        @State private var taps = 0
        @State private var pressed = false
        @State private var side = IconPosition.start
        @State private var gap = 8.0
        @State private var wide = false
        @State private var words = true

        static let sides: [IconPosition] = [.start, .top, .end, .bottom]

        var body: some View {
            VStack {
                // The count is read here, so a press builds this closure again.
                DebugInfoLabel()

                HStack {
                    // Its words name it to a screen reader; the picture stands alone.
                    Button("Media")
                        .icon(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                        .showsText(false)
                        .style(.iconButton)
                        .contentMode(.fit)
                        .width(64)
                        .height(64)
                        .stroke(Palette.outline)
                        .lineWidth(1)
                        .onClicked { taps += 1 }
                        .onPressed { pressed = true }
                        .onReleased { pressed = false }

                    Button("Layout")
                        .icon(ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"))
                        .showsText(false)
                        .style(.iconButton)
                        .contentMode(.fit)
                        .width(64)
                        .height(64)
                        .onClicked { taps += 1 }
                }
                .horizontalAlignment(.center)

                Text(pressed ? "Held down" : "Tapped \(taps) time\(taps == 1 ? "" : "s")")
                    .horizontalAlignment(.center)

                // Words and a picture: the picture on the side chosen, the gap
                // between them as the slider says - together, however wide.
                Button("Media")
                    .icon(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                    .showsText($words)
                    .iconPosition(side)
                    .iconSpacing(gap)
                    .horizontalAlignment(wide ? .fill : .center)
                    .onClicked { taps += 1 }

                Picker(Self.sides, selection: $side) { "\($0)".titled }
                    .placeholder("Picture")
                    .horizontalAlignment(.center)

                Slider($gap)
                    .minimum(0)
                    .maximum(24)

                SwitchRow("Full width", $wide)
                SwitchRow("Its words", $words)
            }
        }
        """#,
        "IconSample": #"""
        // Sources/Samples/Media/IconSample.swift
        /// The hue of the picture the application makes.
        @State private var hue = 0.6

        var body: some View {
            VStack {
                Grid {
                    ForEach(Array(Icon.allCases.enumerated()), id: \.offset) { place, icon in
                        VStack {
                            Image(.icon(icon))
                                .width(24)
                                .height(24)
                                .horizontalAlignment(.center)

                            Text("\(icon)")
                                .textStyle(.caption)
                        }
                        .gridColumn(place % 4)
                        .gridRow(place / 4)
                    }
                }
                .columns(.fill(count: 4))
                .rows(.auto(count: 8))

                SectionTitle("In the button's color")

                HStack {
                    Button("Share")
                        .icon(.icon(.share))

                    Button("Delete")
                        .icon(.icon(.delete))
                        .role(.destructive)

                    Button("Settings")
                        .icon(.icon(.settings))
                        .showsText(false)
                }

                SectionTitle("Made as bytes")

                HStack {
                    // Four pixels a point, shown as large as the icons above.
                    Image(ImageSource(bytes: MadePicture.rings(side: 96, hue: hue)))
                        .width(24)
                        .height(24)
                        .verticalAlignment(.center)

                    Button("Make another")
                        .onClicked { hue = (hue + 0.17).truncatingRemainder(dividingBy: 1) }
                        .verticalAlignment(.center)
                }
            }
        }
        """#,
        "IdentitySample": #"""
        // Sources/Samples/Fundamentals/IdentitySample.swift
        @State private var items = ["Alpha", "Beta", "Gamma"]
        @State private var nextItem = 1

        var body: some View {
            VStack {
                HStack {
                    Button("Add")
                        .onClicked {
                            items.append("Item \(nextItem)")
                            nextItem += 1
                        }

                    Button("Insert at the top")
                        .onClicked {
                            items.insert("Item \(nextItem)", at: 0)
                            nextItem += 1
                        }

                    Button("Rotate")
                        .isEnabled(items.count > 1)
                        .onClicked {
                            items = Array(items.dropFirst()) + [items[0]]
                        }
                }

                // Each row is identified by its ITEM - ForEach's rule, and the
                // reason a plain `for` does not compile here: known by position,
                // an inserted row would rewrite every row into the one below it.
                // A row may still write `.id()` of its own, and the author's wins.
                VStack {
                    // The list is described again on every change, and the rows
                    // keep their controls through it - which is what identity is.
                    DebugInfoLabel()

                    ForEach(items) { item in
                        IdentityRow(item: item, items: $items)                    
                    }
                }
            }
        }

        /// One row, with something worth keeping in it: what is typed lives in the
        /// control, not in the tree.
        private struct IdentityRow: View {
            let item: String
            @Binding var items: [String]

            var body: some View {
                HStack {
                    Text(item)
                        .width(90)
                        .verticalAlignment(.center)

                    TextField()
                        .placeholder("type here")
                        .horizontalAlignment(.fill)

                    Button("Remove")
                        .onClicked {
                            items = items.filter { $0 != item }
                        }
                }
            }
        }
        """#,
        "ImageSample": #"""
        // Sources/Samples/Media/ImageSample.swift
        var body: some View {
            VStack {
                HStack {
                    Image(ImageSource(light: "nav_home.png", dark: "nav_home_dark.png"))
                        .width(48)
                        .height(48)

                    Image(ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"))
                        .width(48)
                        .height(48)

                    Image(ImageSource(light: "nav_input.png", dark: "nav_input_dark.png"))
                        .width(48)
                        .height(48)

                    Image(ImageSource(light: "nav_shell.png", dark: "nav_shell_dark.png"))
                        .width(48)
                        .height(48)
                }
                .horizontalAlignment(.center)

                SectionTitle("Fit, fill or stretch")

                // The same square picture in the same wide box, so the only
                // difference between the three is the content mode.
                HStack {
                    VStack {
                        Image(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                            .contentMode(.fit)
                            .width(96)
                            .height(60)

                        Text(".contentMode(.fit)")
                    }

                    VStack {
                        Image(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                            .contentMode(.fill)
                            .width(96)
                            .height(60)

                        Text(".contentMode(.fill)")
                    }

                    VStack {
                        Image(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                            .contentMode(.stretch)
                            .width(96)
                            .height(60)

                        Text(".contentMode(.stretch)")
                    }
                }
                .horizontalAlignment(.center)

                SectionTitle("One per theme")

                // The same shape twice: one black file, and one file per theme. An
                // Image has no tint, so what changes is the SOURCE - the half in
                // force is picked as the image is built, and switching the system
                // theme builds that image again with the other file.
                HStack {
                    Image("nav_gestures.png")
                        .width(32)
                        .height(32)

                    Text("black artwork, always")
                        .verticalAlignment(.center)
                }

                HStack {
                    Image(ImageSource(light: "nav_gestures.png", dark: "nav_gestures_dark.png"))
                        .width(32)
                        .height(32)

                    Text("one per theme - switch the system between light and dark")
                        .verticalAlignment(.center)
                }
            }
        }
        """#,
        "InteropActsSample": #"""
        // Sources/Samples/Interop/InteropActsSample.swift
        @State private var line = "Hello from StateUI"
        @State private var status = "nothing asked yet"
        @State private var tenStars = false
        @Aim(RatingBar.self) private var stars

        var body: some View {
            VStack {
                DebugInfoLabel()

                TextField($line)

                Button("Write it to the system's log")
                    .onClicked(.ignoreWhileRunning) {
                        try await stateUICall(GalleryContract.log, line)
                        status = "logged"
                    }

                Button("Ask about the battery")
                    .onClicked(.ignoreWhileRunning) {
                        let (level, charging) = try await stateUICall(GalleryContract.batteryLevel)

                        // A desktop without a battery answers 0, so only a level
                        // above zero counts.
                        status = level <= 0
                            ? "this device does not say"
                            : "battery \(Int((level * 100).rounded()))%" + (charging ? ", charging" : "")
                    }

                Button("Call something nobody registered")
                    .onClicked(.ignoreWhileRunning) {
                        do {
                            try await stateUICall(GalleryContract.nobody)
                            status = "that should have thrown"
                        } catch {
                            status = "thrown: \(error)"
                        }
                    }

                RatingBar()
                    .maximum(tenStars ? 10 : 5)
                    .rating(4)
                    .horizontalAlignment(.center)
                    .aim(stars)

                SwitchRow("Ten stars", $tenStars)

                Button("Flash the bar")
                    .onClicked(.ignoreWhileRunning) {
                        try await stars.flash()
                        status = "flashed \(stars)"
                    }

                Text(status)
            }
        }
        """#,
        "InteropControlSample": #"""
        // Sources/Samples/Interop/InteropControlSample.swift
        @State private var signal = TrafficSignal.stop

        var body: some View {
            VStack {
                DebugInfoLabel()

                TrafficLight()
                    .signal(signal)
                    .onLampTapped { index in
                        signal = TrafficSignal(rawValue: Int32(index)) ?? signal
                    }
                    .horizontalAlignment(.center)

                Text("signal: \(signal)")

                Button("Advance")
                    .onClicked {
                        let all = TrafficSignal.allCases
                        signal = all[(all.firstIndex(of: signal)! + 1) % all.count]
                    }
            }
        }
        """#,
        "InteropEventsSample": #"""
        // Sources/Samples/Interop/InteropEventsSample.swift
        @State private var battery = "not heard yet"
        @State private var log: [String] = []

        var body: some View {
            VStack {
                DebugInfoLabel()

                Text("battery: \(battery)")

                Text(log.isEmpty
                    ? "Plug or unplug the power."
                    : log.suffix(4).joined(separator: "\n"))
            }
            // Heard while the page stands: subscribed as it is made, cancelled as it leaves.
            .onHostEvent(GalleryContract.batteryChanged) { level, charging in
                battery = "\(Int((level * 100).rounded()))%" + (charging ? ", charging" : "")
                log.append("\(log.count + 1). battery: \(battery)")
            }
        }
        """#,
        "KeyPressSample": #"""
        // Sources/Samples/BasicInput/KeyPressSample.swift
        @State private var query = ""
        @State private var row = 0

        var body: some View {
            VStack {
                Text("Type in the field: the arrows move through the list, and Escape empties the field.")

                VStack {
                    TextField($query)
                        .placeholder("Search")

                    Text(row == 0 ? "▸ Apples" : "Apples")
                    Text(row == 1 ? "▸ Bread" : "Bread")
                    Text(row == 2 ? "▸ Cheese" : "Cheese")
                }
                // The stack holds the field, so these keys are its while the field holds the keyboard. Page Up and
                // Page Down go to the ends; Tab goes down a row, and back up with Shift held.
                .onKeyPressed(.upArrow, .downArrow, .pageUp, .pageDown, .tab, .escape) { press in
                    switch press.key {
                    case .escape: query = ""
                    case .pageUp: row = 0
                    case .pageDown: row = 2
                    case .tab: row = min(2, max(0, row + (press.modifiers.contains(.shift) ? -1 : 1)))
                    default: row = min(2, max(0, row + (press.key == .upArrow ? -1 : 1)))
                    }
                }
            }
        }
        """#,
        "KeyboardSample": #"""
        // Sources/Samples/Text/KeyboardSample.swift
        @Environment(\.window) private var window
        @State private var name = ""
        @State private var note = ""
        @State private var said = ""

        @Aim(TextField.self) private var first

        var body: some View {
            VStack {
                // `said` is read here, so the answer below builds this closure.
                DebugInfoLabel()

                TextField($name)
                    .placeholder("Name")
                    .aim(first)

                TextField($note)
                    .placeholder("Note")

                HStack {
                    Button("Focus first")
                        .horizontalAlignment(.fill)
                        .onClicked(.ignoreWhileRunning) { try await first.focus() }

                    Button("Unfocus first")
                        .horizontalAlignment(.fill)
                        .onClicked(.ignoreWhileRunning) { try await first.unfocus() }
                }

                Button("Close keyboard")
                    .onClicked(.ignoreWhileRunning) {
                        said = try await window.hideOnScreenKeyboard()
                            ? "Focus released"
                            : "Nothing was focused"
                    }

                Text(said.isEmpty ? "Nothing said yet." : said)
            }
        }
        """#,
        "LayerCost": #"""
        // Sources/Samples/Fundamentals/TwoLayersSample.swift
        /// The value the two blocks show, one reading it and one handed it.
        @State private var counter = 0

        /// How many views stand in each block - the thing a rebuild describes.
        @State private var leaves = 100

        var body: some View {
            // The same two layers inside a subtree worth describing: `leaves`
            // little views, plus the counter. Each side times its OWN describe -
            // the clock is read at the top of the closure and again at the
            // bottom - so the number is what describing it cost.
            VStack {
                // In layer one the get is in the block's own closure, so a press
                // describes every leaf in it again, and its reading says how long
                // that took.
                HStack {
                    Button("+1")
                        .onClicked { counter += 1 }

                    // A choice of more than two, so a button that cycles them.
                    Button("Views: \(leaves)")
                        .onClicked { leaves = leaves == 25 ? 100 : leaves == 100 ? 400 : 25 }
                }
                .horizontalAlignment(.center)

                Text("Layer one · a get")

                Described(counter: $counter, leaves: leaves)

                Text("Layer two · a channel")

                Channelled(counter: $counter, leaves: leaves)
            }
        }

        /// The block wired to layer one: the number is read inside the closure, so a
        /// press describes every leaf again.
        private struct Described: View {
            /// Borrowed, and READ inside this view's own closure - which is what
            /// makes that closure the reader and this whole block the price.
            @Binding var counter: Int

            let leaves: Int

            var body: some View {
                VStack {
                    let began = ContinuousClock.now

                    // The leaves in rows of 25: a stack wraps nothing, so the rows do.
                    ForEach(Array(stride(from: 0, to: leaves, by: 25)), id: \.self) { row in
                        HStack {
                            ForEach(Array(row ..< min(row + 25, leaves)), id: \.self) { index in
                                Rectangle()
                                    .fill(Palette.outline)
                                    .width(7)
                                    .height(14)
                                    .id(index)
                            }
                        }
                    }

                    HStack {
                        Text("Counter \(counter)")
                            .fontWeight(.bold)

                        Text(took(began, leaves))
                            .height(15)

                        DebugInfoLabel()   // climbs on every press
                            .height(15)
                    }
                }
            }
        }

        /// The same block wired to layer two: the number rides a channel, so +1
        /// builds nothing here and its clock stands still.
        private struct Channelled: View {
            @Binding var counter: Int

            let leaves: Int

            var body: some View {
                VStack {
                    let began = ContinuousClock.now

                    // The leaves in rows of 25: a stack wraps nothing, so the rows do.
                    ForEach(Array(stride(from: 0, to: leaves, by: 25)), id: \.self) { row in
                        HStack {
                            ForEach(Array(row ..< min(row + 25, leaves)), id: \.self) { index in
                                Rectangle()
                                    .fill(Palette.outline)
                                    .width(7)
                                    .height(14)
                                    .id(index)
                            }
                        }
                    }

                    HStack {
                        Text($counter.convert { "Counter \($0)" })
                            .fontWeight(.bold)

                        Text(took(began, leaves))
                            .height(15)

                        DebugInfoLabel()   // stays at one on +1
                            .height(15)
                    }
                }
            }
        }

        /// How long describing this closure has taken so far, in microseconds.
        ///
        /// Read at the top of a closure and printed at the bottom of the same one, so
        /// what it measures is that closure's own work - the leaves above it included,
        /// since a `ForEach` builds its views where it is written.
        ///
        /// - Parameters:
        ///   - began: the clock at the top of the closure.
        ///   - views: how many views stand above the reading.
        /// - Returns: the sentence to print.
        private func took(_ began: ContinuousClock.Instant, _ views: Int) -> String {
            let spent = ContinuousClock.now - began
            let parts = spent.components
            let nanoseconds = parts.seconds * 1_000_000_000 + parts.attoseconds / 1_000_000_000

            return "\(views) views described in \(microseconds(nanoseconds)) µs"
        }

        /// Nanoseconds as microseconds, to one decimal - the unit a describe lands in.
        /// Written by hand, a formatter being Foundation's.
        ///
        /// - Parameter nanoseconds: what the clock answered.
        /// - Returns: the figure, without its unit.
        private func microseconds(_ nanoseconds: Int64) -> String {
            let tenths = (nanoseconds + 50) / 100

            return "\(tenths / 10).\(tenths % 10)"
        }
        """#,
        "LayerRows": #"""
        // Sources/Samples/Fundamentals/TwoLayersSample.swift
        /// The one value both rows show - held here, where it is shown.
        @State private var counter = 0

        var body: some View {
            // Each layer stands in a row of its own below, so each takes its
            // own reading.
            VStack {
                // Nothing here reads the count - a handler reads when it fires -
                // so this closure stands at one build however often you press.
                DebugInfoLabel()

                Button("+1")
                    .horizontalAlignment(.center)
                    .onClicked { counter += 1 }

                boxed("Layer one · a get") {
                    Text("Counter \(counter)")
                        .fontWeight(.bold)
                    DebugInfoLabel()   // climbs, "for counter"
                }

                boxed("Layer two · a channel") {
                    Text($counter.convert { "Counter \($0)" })
                        .fontWeight(.bold)
                    DebugInfoLabel()   // stays: "1 build, first time"
                }
            }
        }

        /// One captioned row, its content in a closure of its own - which is what
        /// makes the reading inside it that row's alone.
        private func boxed<Content: Views>(_ caption: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
            ZStack {
                VStack {
                    Text(caption)

                    VStack(content: content)
                }
            }
            .style(.card)
            .stroke(Palette.outline)
        }
        """#,
        "Layers": #"""
        // Sources/Samples/Layout/ZStackSample.swift
        @State private var redInFront = false

        var body: some View {
            VStack {
                // Left alone, the child written last is drawn on top; the higher
                // zIndex is nearer the front, and nothing moves.
                ZStack {
                    Rectangle()
                        .fill(Color(hex: 0xE53935))
                        .width(150)
                        .height(70)
                        .horizontalAlignment(.start)
                        .zIndex(redInFront ? 1 : 0)

                    Rectangle()
                        .fill(Color(hex: 0x1E88E5))
                        .width(150)
                        .height(70)
                        .horizontalAlignment(.end)
                        .zIndex(redInFront ? 0 : 1)
                }
                .height(70)
                .maximumWidth(240)
                .horizontalAlignment(.center)

                SwitchRow("Red in front", $redInFront)
                    .horizontalAlignment(.center)
            }
        }
        """#,
        "LayoutAxesSample": #"""
        // Sources/Samples/MotionLayout/LayoutAxesSample.swift
        /// THE PARAMETERS: five strips, each an axis of its own - which card stands in
        /// the middle of the strip.
        struct Strips: LayoutParameters {
            var free = 1.5
            var snapping = 1.0
            var endpoints = 0.0
            var round = 0.0
            var stepping = 0.0

            static var axes: [WritableKeyPath<Strips, Double>] {
                [\.free, \.snapping, \.endpoints, \.round, \.stepping]
            }
        }

        /// Each strip's declaration, shown over it.
        static let declarations = [
            "range: 0...3",
            "range: 0...3, snaps: [1, 2]",
            "range: 0...3, snaps: .endpoints",
            "range: 0...4, periodic: true",
            "range: 0...4, snaps: .every(1), periodic: true",
        ]

        /// The pictures on the cards: the gallery's groups'.
        static let pictures = [
            "cat_fundamentals.png", "cat_animation.png", "cat_layout.png", "cat_shapes.png",
            "cat_gestures.png", "cat_media.png", "cat_styles.png", "cat_text.png",
        ]

        /// What the layout places for each strip: its words, the frame in its
        /// middle a card rests in, and its four cards.
        enum Part: Hashable {
            case words(Int), frame(Int), card(Int, Int)
        }

        static let parts = declarations.indices.flatMap { strip in
            [Part.words(strip), .frame(strip)] + (0..<4).map { Part.card(strip, $0) }
        }

        /// Where the strips stand - handed on with `$`, never read in the body.
        @State private var strips = Strips()

        var body: some View {
            // ONE INPUT: the hand dragged across, carrying the cards with it...
            let hand = LayoutInput.scroll(.horizontal)

            return Grid {
                MotionLayout(Self.parts, parameters: $strips) { part in
                    view(part)
                } placements: { room, strips in
                    Self.parts.map { place($0, strips, room) }
                }
                // ...MOVES FIVE STRIPS, each resting its own way: anywhere between
                // its ends, coming back only from past one...
                .axis(\.free, input: hand, range: 0...3)
                // ...on a card - 1 or 2 - or on an end...
                .axis(\.snapping, input: hand, range: 0...3, snaps: [1, 2])
                // ...on an end alone: the first card or the last...
                .axis(\.endpoints, input: hand, range: 0...3, snaps: .endpoints)
                // ...round and round, anywhere - 4 is 0 a turn on...
                .axis(\.round, input: hand, range: 0...4, periodic: true)
                // ...and round and round, a card at a time.
                .axis(\.stepping, input: hand, range: 0...4, snaps: .every(1), periodic: true)
                .motion(.spring(response: .milliseconds(360), damping: 0.8))
            }
            .clipsContent(true)
        }

        /// The view for one part: words, a frame or a card.
        @ViewBuilder
        private func view(_ part: Part) -> some View {
            switch part {
            case .words(let strip):
                Text(Self.declarations[strip])
            case .frame:
                Rectangle()
                    .fill(Palette.field)
            case .card(let strip, let index):
                ZStack { Image(ImageSource(Self.pictures[(strip + index) % Self.pictures.count])).contentMode(.fill) }
                    .clipsContent(true)
            }
        }

        /// Where one part stands: a row a strip down the room, its words over it
        /// and its frame in its middle; each card as far from the middle as its
        /// strip's axis says - on a strip that comes round, the turn nearest the
        /// middle, fading out at the strip's ends.
        private func place(_ part: Part, _ strips: Strips, _ room: Rect) -> Placement {
            let row = min(room.height / 5, 104)
            let height = row - 34
            let width = height * 0.75
            let top = (room.height - 5 * row) / 2

            switch part {
            case .words(let strip):
                return Placement(Rect(16, top + Double(strip) * row + 4, room.width - 32, 16))
            case .frame(let strip):
                return Placement(Rect(
                    room.width / 2 - width / 2 - 4, top + Double(strip) * row + 20, width + 8, height + 8))
            case .card(let strip, let index):
                let along = Double(index) - strips[keyPath: Strips.axes[strip]]
                let comesRound = strip >= 3
                let step = comesRound ? along - ((along + 2) / 4).rounded(.down) * 4 : along

                return Placement(
                    Rect(room.width / 2 + step * (width + 10) - width / 2, top + Double(strip) * row + 24, width, height),
                    opacity: comesRound ? min(max((2 - abs(step)) * 2, 0), 1) : 1,
                    zIndex: 1)
            }
        }
        """#,
        "LayoutDirectionSample": #"""
        // Sources/Samples/Layout/LayoutDirectionSample.swift
        var body: some View {
            VStack {
                row("leftToRight", .leftToRight)
                row("rightToLeft", .rightToLeft)
                row("inherited", .inherited)
            }
        }

        /// One row laid out each way, with the value that produced it.
        private func row(_ caption: String, _ direction: LayoutDirection) -> some View {
            VStack {
                Text(caption)

                // Laid out the way `direction` says - at `.inherited`, the way the
                // view above it is.
                HStack {
                    Rectangle()
                        .fill(Palette.accent)
                        .width(60)
                        .height(20)

                    Text("First")
                    Text("Second")
                }
                .layoutDirection(direction)
            }
        }
        """#,
        "LayoutKeyframesSample": #"""
        // Sources/Samples/MotionLayout/LayoutKeyframesSample.swift
        import StateUIFoundation

        /// One card: its name, which is its identity, its color and its icon.
        struct Card {
            let name: String
            let color: Color
            let icon: Icon
        }

        /// The cards, dealt in this order.
        static let cards = [
            Card(name: "Mural", color: Color(hex: 0x7C3AED), icon: .star),
            Card(name: "Nebula", color: Color(hex: 0x2563EB), icon: .heart),
            Card(name: "Ridge", color: Color(hex: 0x0D9488), icon: .home),
            Card(name: "Bloom", color: Color(hex: 0xD97706), icon: .calendar),
            Card(name: "Tide", color: Color(hex: 0xDB2777), icon: .mail),
            Card(name: "Prism", color: Color(hex: 0x4F46E5), icon: .settings),
            Card(name: "Grove", color: Color(hex: 0x16A34A), icon: .person),
            Card(name: "Ember", color: Color(hex: 0xDC2626), icon: .play),
            Card(name: "Dune", color: Color(hex: 0xCA8A04), icon: .clock),
        ]

        /// Which layout stands: 0 the ring, 1 the grid - the one it opens on, in
        /// the middle - 2 the pile; handed on with `$`, never read in the body.
        @State private var arrangement = 1.0

        /// Whether the cards go between the layouts by a smooth curve rather than
        /// straight: read in the body.
        @State private var smooth = false

        /// Whether the hand moves through the layouts too, or the buttons alone.
        @State private var byHand = true

        var body: some View {
            Grid {
                Grid {
                    cards
                }
                .gridRow(0)
                .clipsContent(true)

                // A WRITE TRAVELS: from the ring to the pile, the cards pass the grid.
                HStack {
                    Button("Ring").onClicked { arrangement = 0 }
                    Button("Grid").onClicked { arrangement = 1 }
                    Button("Pile").onClicked { arrangement = 2 }
                }
                .horizontalAlignment(.center)
                .gridRow(1)

                SwitchRow("Smooth curve", $smooth)
                    .horizontalAlignment(.center)
                    .gridRow(2)

                SwitchRow("The hand moves it", $byHand)
                    .horizontalAlignment(.center)
                    .gridRow(3)
            }
            .rows(.fill, .auto, .auto, .auto)
        }

        /// The cards: one arithmetic, asked at the keyframes alone.
        private var cards: some View {
            MotionLayout(Self.cards, id: \.name, parameters: $arrangement) { card in
                face(card)
            } placements: { room, arrangement in
                // ASKED AT 0, 1 AND 2 ALONE, each answering a whole layout.
                [ring(room), grid(room), pile(room)][Int(arrangement)]
            }
            // THE HAND MOVES THROUGH THE THREE, resting on each - or, with no
            // input, the axis is keyframes alone and the buttons move it.
            .axis(
                \.self, input: byHand ? .scroll(.horizontal, pointsPerUnit: 260) : nil, range: 0...2,
                keyframes: .every(1), snaps: byHand ? .every(1) : nil)
            // BETWEEN THEM each card goes straight, or by a curve its neighbors
            // shape.
            .interpolation(smooth ? LayoutCurve.catmullRom : .linear)
            .motion(.eased(.milliseconds(700), .cubicInOut))
        }

        /// How large a card is in every layout - the size the grid's cells allow -
        /// so a layout changes its scale, never its size.
        private func size(in room: Rect) -> (width: Double, height: Double) {
            let width = min(room.width / 3 * 0.86, room.height / 3 * 0.86 / 1.4, 130)
            return (width, width * 1.4)
        }

        /// A RING, smaller, the first card at the top.
        private func ring(_ room: Rect) -> [Placement] {
            let (width, height) = size(in: room)
            let radius = min(room.width, room.height) / 2 - height * 0.62 / 2 - 8

            return Self.cards.indices.map { index in
                let angle = Double(index) / Double(Self.cards.count) * 2 * .pi
                return Placement(
                    Rect(
                        room.width / 2 + sin(angle) * radius - width / 2,
                        room.height / 2 - cos(angle) * radius - height / 2,
                        width, height),
                    transform: .scale(0.62))
            }
        }

        /// A GRID of three by three, filling the room.
        private func grid(_ room: Rect) -> [Placement] {
            let (width, height) = size(in: room)

            return Self.cards.indices.map { index in
                let (row, column) = index.quotientAndRemainder(dividingBy: 3)
                return Placement(Rect(
                    room.width / 3 * (Double(column) + 0.5) - width / 2,
                    room.height / 3 * (Double(row) + 0.5) - height / 2,
                    width, height))
            }
        }

        /// A PILE in the middle, each card turned a little, the last on top.
        private func pile(_ room: Rect) -> [Placement] {
            let (width, height) = size(in: room)

            return Self.cards.indices.map { index in
                let step = Double(index) - Double(Self.cards.count - 1) / 2
                return Placement(
                    Rect(room.width / 2 - width / 2 + step * 3, room.height / 2 - height / 2 - step * 2, width, height),
                    transform: .rotate(step * 4).scale(1.1),
                    zIndex: index)
            }
        }

        /// One card's face: its color, its icon on a disc, and its name.
        private func face(_ card: Card) -> some View {
            ZStack {
                Rectangle()
                    .fill(card.color)

                VStack {
                    ZStack {
                        Rectangle()
                            .fill(.white)
                            .opacity(0.3)

                        Image(.icon(card.icon))
                            .width(24)
                            .height(24)
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)
                    }
                    .width(44)
                    .height(44)
                    .horizontalAlignment(.center)

                    Text(card.name)
                        .fontWeight(.bold)
                        .horizontalAlignment(.center)
                }
                .verticalAlignment(.center)
            }
        }
        """#,
        "LayoutParametersSample": #"""
        // Sources/Samples/MotionLayout/LayoutParametersSample.swift
        /// THE PARAMETERS: two numbers, each moved on its own - the turn by the hand,
        /// the spread by the switch.
        struct Deal: LayoutParameters {
            /// Which card is at the front.
            var turn = 2.0

            /// How far the cards are fanned out: 0 a pile, 1 an arc.
            var spread = 0.0

            static var axes: [WritableKeyPath<Deal, Double>] { [\.turn, \.spread] }
        }

        /// One card: its name, its color and its icon.
        struct Card {
            let name: String
            let color: Color
            let icon: Icon
        }

        /// The cards, dealt in this order.
        static let cards = [
            Card(name: "Mural", color: Color(hex: 0x7C3AED), icon: .star),
            Card(name: "Nebula", color: Color(hex: 0x2563EB), icon: .heart),
            Card(name: "Ridge", color: Color(hex: 0x0D9488), icon: .home),
            Card(name: "Bloom", color: Color(hex: 0xD97706), icon: .calendar),
            Card(name: "Tide", color: Color(hex: 0xDB2777), icon: .mail),
        ]

        /// Where the run stands on both axes - handed on with `$`, never read in
        /// the body.
        @State private var deal = Deal()

        /// The switch's own value: what the body reads.
        @State private var fanned = false

        var body: some View {
            Grid {
                Grid {
                    cards
                }
                .gridRow(0)
                .clipsContent(true)

                SwitchRow(
                    "Fan out",
                    Binding(
                        get: { fanned },
                        set: { fanning in
                            fanned = fanning
                            // ONE AXIS WRITTEN: the spread travels there, and a
                            // turn under way goes on as it was.
                            deal.spread = fanning ? 1 : 0
                        }))
                .horizontalAlignment(.center)
                .gridRow(1)
            }
            .rows(.fill, .auto)
        }

        /// The cards, placed from both axes of the parameters.
        private var cards: some View {
            MotionLayout(Array(Self.cards.indices), parameters: $deal) { index in
                face(index)
            } placements: { room, deal in
                Self.cards.indices.map { place($0, deal, room) }
            }
            // THE HAND MOVES THE TURN ALONE, resting on a card; the spread has
            // no hand, so it is declared no axis.
            .axis(
                \.turn, input: .scroll(.horizontal, pointsPerUnit: 90),
                range: 0...Double(Self.cards.count - 1), snaps: .every(1))
            .motion(.eased(.milliseconds(600), .cubicOut))
        }

        /// Where one card stands: between a pile and an arc by the spread, the
        /// card at the front in the middle either way.
        private func place(_ index: Int, _ deal: Deal, _ room: Rect) -> Placement {
            let step = Double(index) - deal.turn
            let width = min(room.width * 0.36, room.height * 0.5, 150)
            let height = width * 1.4

            // A PILE leaves each card a few points behind the one in front; an ARC
            // sets it most of a card along, lower and turned with the curve.
            let pile = 1 - deal.spread
            let across = step * (10 * pile + width * 0.75 * deal.spread)
            let down = abs(step) * (-6 * pile + width * 0.12 * deal.spread)

            return Placement(
                Rect(room.width / 2 - width / 2 + across, room.height / 2 - height / 2 + down, width, height),
                transform: .rotate(step * 10 * deal.spread).scale(1 - min(abs(step), 3) * 0.06),
                zIndex: 100 - Int(min(abs(step), 9) * 10))
        }

        /// One card's face: its color, its icon on a disc, and its name.
        private func face(_ index: Int) -> some View {
            let card = Self.cards[index]

            return ZStack {
                Rectangle()
                    .fill(card.color)

                VStack {
                    ZStack {
                        Rectangle()
                            .fill(.white)
                            .opacity(0.3)

                        Image(.icon(card.icon))
                            .width(31)
                            .height(31)
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)
                    }
                    .width(56)
                    .height(56)
                    .horizontalAlignment(.center)

                    Text(card.name)
                        .fontWeight(.bold)
                        .horizontalAlignment(.center)
                }
                .verticalAlignment(.center)
            }
        }
        """#,
        "LifecycleSample": #"""
        // Sources/Samples/Windows/LifecycleSample.swift
        /// The window's log, kept by its gallery window. It is written by `MainPage`
        /// as the window is made and by `WindowPhaseLog` as its phase moves - see
        /// WindowLog.swift - and this sample only reads it.
        let log: WindowLog

        var body: some View {
            VStack {
                Text("What the window has said so far, newest last:")

                VStack {
                    DebugInfoLabel()

                    if log.events.isEmpty {
                        Text("nothing yet - switch away and back")
                    }

                    ForEach(log.events) { row in
                        Text(row)
                    }
                }
            }
        }
        """#,
        "LifetimeSample": #"""
        // Sources/Samples/Fundamentals/LifetimeSample.swift
        /// Whether the card is in the tree at all.
        @State private var shown = true

        /// The card's identity - a new one is a new card.
        @State private var identity = 1

        /// How often the page was built again on purpose, which carries the card,
        /// built with the same inputs, and creates nothing.
        @State private var builds = 0

        /// What the cards have said, oldest first.
        @State private var log: [String] = []

        var body: some View {
            VStack {
                // The switch and both buttons build this closure again. Build this
                // again changes nothing the card is built with, so it carries the
                // card and creates nothing.
                DebugInfoLabel()

                SwitchRow("Show the card", $shown)

                HStack {
                    Button("A new card")
                        .onClicked { identity += 1 }

                    Button("Build this again · \(builds)")
                        .onClicked { builds += 1 }
                }

                if shown {
                    // A new identity is a new card: the one on screen is
                    // destroyed, and this one created.
                    LifetimeCard(number: identity, log: $log)
                        .id(identity)
                }

                VStack {
                    if log.isEmpty {
                        Text("nothing yet")
                    }

                    ForEach(Array(log.suffix(6))) { line in
                        Text(line)
                    }
                }
            }
        }

        /// A card that says when it comes and goes, counting its own taps.
        private struct LifetimeCard: View {
            let number: Int
            @Binding var log: [String]
            @State private var taps = 0

            var body: some View {
                // A card, not one more button: taller, and an outline alone.
                Button("Card \(number) · tapped \(taps)")
                    .stroke(Palette.accent)
                    .lineWidth(1.5)
                    .horizontalAlignment(.center)
                    .onClicked { taps += 1 }
                    // Once, as the render that brings the card in has walked the
                    // tree - its state and its environment are there to use.
                    .onCreated {
                        log.append("\(log.count + 1) · card \(number) created")
                    }
                    // Once, as the render that leaves it out has walked the tree -
                    // and its state still answers, which is what saving needs.
                    .onDestroying {
                        log.append("\(log.count + 1) · card \(number) destroying, tapped \(taps)")
                    }
            }
        }
        """#,
        "LightTableSample": #"""
        // Sources/Samples/MotionLayout/LightTableSample.swift
        /// THE PARAMETERS: which photo the table is centered on, across and down, how
        /// near it stands, and how far the photos are turned - a turn a unit.
        struct Table: LayoutParameters {
            var x = 1.0
            var y = 1.0
            var zoom = 0.45
            var turn = 0.0

            static var axes: [WritableKeyPath<Table, Double>] { [\.x, \.y, \.zoom, \.turn] }
        }

        /// The photos, three by three: the gallery's groups' pictures.
        static let photos = [
            "cat_fundamentals.png", "cat_driven.png", "cat_state.png",
            "cat_animation.png", "cat_basicinput.png", "cat_text.png",
            "cat_layout.png", "cat_styles.png", "cat_shapes.png",
        ]

        /// Where the table stands on every axis - handed on with `$`, never read
        /// in the body.
        @State private var table = Table()

        /// Whether the table rests on a photo and the photos on a quarter turn:
        /// read in the body, so the switch declares the axes again.
        @State private var snaps = true

        var body: some View {
            Grid {
                Grid {
                    photosOnTheTable
                }
                .gridRow(0)
                .clipsContent(true)

                SwitchRow(
                    "Snap",
                    Binding(
                        get: { snaps },
                        set: { snapping in
                            snaps = snapping
                            // SNAPPING AGAIN, the table travels to the photo and
                            // the quarter turn nearest where it was left.
                            if snapping {
                                table.x = table.x.rounded()
                                table.y = table.y.rounded()
                                table.turn = (table.turn * 4).rounded() / 4
                            }
                        }))
                .horizontalAlignment(.center)
                .gridRow(1)

                // THE PROGRAM MOVES ONE COORDINATE: the zoom travels, the pan and
                // the turn stay as they stand - no model of its own for each.
                Button("Closer").onClicked { table.zoom = 1 }
                    .horizontalAlignment(.center)
                    .gridRow(2)
            }
            .rows(.fill, .auto, .auto)
        }

        /// The photos, placed from every axis of the table.
        private var photosOnTheTable: some View {
            MotionLayout(Self.photos, parameters: $table) { photo in
                ZStack { Image(ImageSource(photo)).contentMode(.fill) }
                    .clipsContent(true)
            } placements: { room, table in
                Self.photos.indices.map { place($0, table, room) }
            }
            // ONE FINGER OR TWO MOVE THE TABLE every way - one axis scrolled
            // across, one down - resting on a photo, or, not snapping, anywhere...
            .axis(\.x, input: .scroll(.horizontal), range: 0...2, snaps: snaps ? .every(1) : nil)
            .axis(\.y, input: .scroll(.vertical), range: 0...2, snaps: snaps ? .every(1) : nil)
            // ...while TWO SPREAD it anywhere from the whole table to one photo,
            // coming back only from past either end...
            .axis(\.zoom, input: .magnification, range: 0.45...1)
            // ...and TURN the photos a quarter at a time, or freely, round and
            // round.
            .axis(
                \.turn, input: .rotation(degreesPerUnit: 360), range: 0...1, snaps: snaps ? .every(0.25) : nil,
                periodic: true)
            .motion(.spring(response: .milliseconds(420), damping: 0.82))
        }

        /// Where the photo at `index` lies: its square of the table, a photo's
        /// width and a gap apart, the photo the table is centered on in the middle
        /// of the room - all as near as the table stands, the whole table in the
        /// room at its farthest - turned in its place.
        private func place(_ index: Int, _ table: Table, _ room: Rect) -> Placement {
            let side = min(room.width, room.height) * 0.65 * table.zoom
            let pitch = side * 1.12
            let (row, column) = index.quotientAndRemainder(dividingBy: 3)
            let x = room.width / 2 + (Double(column) - table.x) * pitch
            let y = room.height / 2 + (Double(row) - table.y) * pitch

            return Placement(
                Rect(x - side / 2, y - side / 2, side, side),
                transform: .rotate(table.turn * 360))
        }
        """#,
        "LinkSample": #"""
        // Sources/Samples/BasicInput/LinkSample.swift
        @State private var page = "https://www.swift.org"
        @State private var opened = 0
        @State private var enabled = true

        static let pages = ["https://www.swift.org", "https://developer.apple.com", "https://developer.android.com"]

        var body: some View {
            VStack {
                Link("Swift's home page", destination: "https://www.swift.org")
                    .isEnabled(enabled)
                    .onClicked { opened += 1 }

                Link("Write to us", destination: "mailto:hello@example.com")
                    .isEnabled(enabled)
                    .onClicked { opened += 1 }

                // The address is carried from the state: choosing another page
                // changes where the link leads, with no render of this view.
                Link("The page chosen below", destination: $page)
                    .isEnabled(enabled)
                    .onClicked { opened += 1 }

                Picker(Self.pages, selection: $page) { $0 }
                    .placeholder("Page")

                Text("Opened \(opened) time\(opened == 1 ? "" : "s")")

                SwitchRow("Enabled", $enabled)
            }
        }
        """#,
        "LinksSample": #"""
        // Sources/Samples/Windows/LinksSample.swift
        /// Where this window is, and the links it was given.
        let nav: Navigation

        var body: some View {
            // Read here, so every link this window is given builds this page again.
            let given = nav.links

            return VStack {
                DebugInfoLabel()

                Link("Open the Tap sample", destination: GalleryLink.sample("tap"))
                    .horizontalAlignment(.center)

                SectionTitle("Given to this window")
                if given.isEmpty {
                    Text("No link yet.")
                }
                ForEach(Array(given.suffix(5).enumerated()), id: \.offset) { item in
                    Text(item.element)
                }
            }
        }
        """#,
        "LivingLayoutSample": #"""
        // Sources/Samples/Layout/LivingLayoutSample.swift
        @State private var rows = ["Alpha", "Bravo", "Charlie"]
        @State private var next = 4
        @State private var wide = false

        static let names = ["Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India"]

        var body: some View {
            // NOTHING HERE SAYS "ANIMATE". Where a child sits is worked out by the
            // layout, and the host animates it from the old place to the new
            // one, so an insert slides everything under it down.
            VStack {
                // `wide` is read in THESE braces - `.columns` below asks
                // it - so widening the grid builds this closure. What the rows do
                // is counted by the reading inside their own stack.
                DebugInfoLabel()

                Text("A stack")
                    .tracking(1)

                VStack {
                    // INSIDE these braces, because that is where `rows` is read:
                    // Add, Remove and Shuffle build this closure, and the views
                    // left standing keep their controls.
                    DebugInfoLabel()

                    ForEach(rows, id: \.self) { name in
                        ZStack {
                            Text(name)
                                .verticalAlignment(.center)
                        }
                        .style(.card)
                        .lineWidth(0)
                        .height(40)
                    }
                }

                HStack {
                    Button("Add").onClicked {
                        rows.insert(Self.names[next % Self.names.count], at: 0)
                        next += 1
                    }

                    Button("Remove").onClicked {
                        if !rows.isEmpty { rows.removeLast() }
                    }

                    Button("Shuffle").onClicked { rows.shuffle() }
                }

                Text("A grid, its columns changing width")
                    .tracking(1)

                // A grid whose column widths change: every child travels to its
                // new place, because a placement is a placement whoever worked it
                // out.
                Grid {
                    cell("one", Palette.brand, at: 0)
                    cell("two", Palette.accent, at: 1)
                    cell("three", Palette.brand, at: 2, faded: true)
                }
                .columns(
                    wide ? .proportional(3) : .proportional(1),
                    .proportional(1),
                    wide ? .proportional(1) : .proportional(3))
                .height(52)

                Button("Widen the other end").onClicked { wide.toggle() }
            }
        }

        private func cell(
            _ text: String, _ color: Color, at column: Int, faded: Bool = false
        ) -> some View {
            ZStack {
                Text(text)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
            }
            .style(.card)
            .opacity(faded ? 0.55 : 1)
            .lineWidth(0)
            .gridColumn(column)
        }
        """#,
        "LoadingList": #"""
        // Sources/Samples/Collections/LoadingItemsSample.swift
        @State private var count = 30
        @State private var loading = false

        var body: some View {
            Grid {
                HStack {
                    Button("Start over")
                        .isEnabled(count > 30)
                        .onClicked { count = 30 }

                    Text(loading ? "Loading" : "\(count) items")
                        .verticalAlignment(.center)
                }
                .gridRow(0)

                DebugInfoLabel()
                    .gridRow(0)

                ItemsView(0..<count) { number in
                    Text("Item \(number + 1)")
                }
                // Within five items of the end, thirty more - one load at a time:
                // reaching the end again while one runs lets that go.
                .onEndReached(within: 5, policy: .ignoreWhileRunning) {
                    guard count < 300 else { return }

                    loading = true
                    try await Task.sleep(for: .milliseconds(400))
                    count += 30
                    loading = false
                }
                .gridRow(1)
            }
            .rows(.auto, .fill)
        }
        """#,
        "LocaleInfoSample": #"""
        // Sources/Samples/Environment/LocaleInfoSample.swift
        /// The locale, as the host reports it.
        @Environment(\.locale) var locale

        var body: some View {
            VStack {
                // The locale is read here, so a change to it builds this
                // closure.
                DebugInfoLabel()

                Text(locale.name.isEmpty ? "the host has not said" : locale.name)
                    .fontWeight(.bold)

                Text("language · \(locale.language)")
                Text("region · \(locale.region.isEmpty ? "none" : locale.region)")
                Text("zone · \(locale.timeZone)")
                Text("clock · \(locale.uses24HourClock ? "24-hour" : "12-hour")")
                Text("week starts · \(locale.firstDayOfWeek)")
                Text(locale.isMetric ? "metric" : "not metric")
            }
        }
        """#,
        "LocalizationSample": #"""
        // Sources/Samples/Environment/Localization/LocalizationSample.swift
        @State private var localization = Localization(
            ReportCatalog.self, language: .fixed(.polish), formatLocale: .fixed("pl-PL"))
        @State private var count = 22.0
        private let prepared = CalendarDate(year: 2026, month: 10, day: 11)
        private let recent = [
            FileItem(name: "Plan.pdf", modified: CalendarDate(year: 2026, month: 9, day: 30)),
            FileItem(name: "Budżet.xlsx", modified: CalendarDate(year: 2026, month: 10, day: 2)),
            FileItem(name: "Notes.txt", modified: CalendarDate(year: 2026, month: 10, day: 9)),
        ]

        var body: some View {
            VStack {
                HStack {
                    Button("English")
                        .onClicked {
                            localization.language = .fixed(.english)
                            localization.formatLocale = .fixed("en-US")
                        }
                    Button("Polski")
                        .onClicked {
                            localization.language = .fixed(.polish)
                            localization.formatLocale = .fixed("pl-PL")
                        }
                }

                HStack {
                    Stepper($count)
                        .minimum(0)
                        .maximum(30)
                    Text("\(Int(count))")
                }

                ReportView(fileCount: Int(count), recent: recent, prepared: prepared)
                    .environment(localization)

                Text("Side by side")
                    .fontWeight(.bold)
                Grid {
                    ReportView(fileCount: Int(count), recent: recent, prepared: prepared)
                        .environment(localization.speaking(.english))
                    ReportView(fileCount: Int(count), recent: recent, prepared: prepared)
                        .environment(localization.speaking(.polish))
                        .gridColumn(1)
                }
                .columns(.fill, .fill)
            }
        }

        // Sources/Samples/Environment/Localization/ReportCatalog.swift
        /// The languages the folder report is written in.
        enum ReportLanguage: LocaleTag, CaseIterable {
            case english = "en"
            case polish = "pl"
        }

        /// The report's languages, and the one it falls back to - nothing else, so it never grows.
        enum ReportCatalog: LocalizationCatalog {
            static let defaultLanguage = ReportLanguage.english
        }

        // Sources/Samples/Environment/Localization/ReportEnglish.swift
        extension ReportResources {
            static let english = ReportResources(
                heading: "Folder report",
                prepared: Message { day, context in
                    "Prepared on \(context.date(day, style: .long))"
                },
                fileCount: Message { count, context in
                    let number = context.number(count)
                    return context.plural(count,
                        one: "The folder holds \(number) file.",
                        other: "The folder holds \(number) files.")
                },
                recent: "Recently changed",
                footer: "Generated by Files",
                headingStyle: TextStyleSpec(size: 20, lineHeight: 1.15))
        }

        // Sources/Samples/Environment/Localization/ReportPolish.swift
        extension ReportResources {
            static let polish = ReportResources(
                heading: "Raport folderu",
                prepared: Message { day, context in
                    "Sporządzono \(context.date(day, style: .long))"
                },
                fileCount: Message { count, context in
                    let number = context.number(count)
                    return context.plural(count,
                        one: "Folder zawiera \(number) plik.",
                        few: "Folder zawiera \(number) pliki.",
                        many: "Folder zawiera \(number) plików.",
                        other: "Folder zawiera \(number) pliku.")
                },
                recent: "Ostatnio zmienione",
                footer: "Wygenerowano w aplikacji Pliki",
                headingStyle: TextStyleSpec(size: 20, lineHeight: 1.15))
        }

        // Sources/Samples/Environment/Localization/ReportResources.swift
        /// A base typeface: its size and its line height. The user's text size still scales it.
        struct TextStyleSpec {
            let size: Double
            let lineHeight: Double
        }

        /// What the folder report says - the document's own words, a part of its own.
        struct ReportResources: LocalizedResources {
            typealias Catalog = ReportCatalog

            let heading: String
            let prepared: Message<CalendarDate>
            let fileCount: Message<Int>
            let recent: String
            let footer: String
            let headingStyle: TextStyleSpec

            static func resources(for language: ReportLanguage) -> ReportResources {
                switch language {
                case .english: .english
                case .polish: .polish
                }
            }
        }

        // Sources/Samples/Environment/Localization/ReportView.swift
        /// A file the folder holds: data, so it reads the same in every language.
        struct FileItem: Hashable {
            let name: String
            let modified: CalendarDate
        }

        /// The document: every word, plural form and date in it follows the nearest localization.
        struct ReportView: View {
            @Environment private var res: ReportResources
            @Environment private var localization: Localization<ReportCatalog>
            let fileCount: Int
            let recent: [FileItem]
            let prepared: CalendarDate

            var body: some View {
                VStack {
                    Text(res.heading)
                        .fontSize(res.headingStyle.size)
                        .lineHeight(res.headingStyle.lineHeight)
                        .fontWeight(.bold)
                    Text(localization.text(res.prepared, prepared))
                    Text(localization.text(res.fileCount, fileCount))

                    Text(res.recent)
                        .fontWeight(.bold)
                    ForEach(recent) { file in
                        VStack {
                            Text(file.name)
                            Text(localization.date(file.modified, style: .medium))
                        }
                    }

                    Text(res.footer)
                }
            }
        }
        """#,
        "LongList": #"""
        // Sources/Samples/Collections/ItemsViewSample.swift
        @State private var numbers = Array(0..<1_000)
        @State private var chosen: Int?

        var body: some View {
            Grid {
                // Every row one place down, or one place up: the list moves each
                // row it shows, and the choice goes with its row.
                HStack {
                    Button("Rotate +1")
                        .onClicked { numbers.insert(numbers.removeLast(), at: 0) }

                    Button("Rotate −1")
                        .onClicked { numbers.append(numbers.removeFirst()) }
                }
                .horizontalAlignment(.center)
                .gridRow(0)

                // One view per item, the item its identity - built as the
                // platform's own list shows it, never before.
                ItemsView(numbers) { number in
                    HStack {
                        Text("\(number)")
                            .width(90)
                            .verticalAlignment(.center)

                        Text("\(number * number)")
                            .verticalAlignment(.center)
                    }
                }
                .header(Text("N and N², a thousand times")
                    .fontWeight(.bold))
                .footer(Text("That is all of them."))
                .selection($chosen)
                .gridRow(1)

                // Built again only for the choice: scrolling builds rows, never
                // the page.
                DebugInfoLabel()
                    .gridRow(2)

                Text(chosen.map { "Row \($0) is chosen." } ?? "Tap a row.")
                    .gridRow(2)
            }
            .rows(.auto, .fill, .auto)
        }
        """#,
        "MailFilters": #"""
        // Sources/Samples/Navigation/PopoverSample.swift
        @State private var filtering = false
        @State private var unreadOnly = false
        @State private var flaggedOnly = false

        var body: some View {
            VStack {
                Button("Filters")
                    .horizontalAlignment(.start)
                    .onClicked { filtering = true }
                    .popover(isPresented: $filtering) {
                        VStack {
                            Switch($unreadOnly).text("Unread only")
                            Switch($flaggedOnly).text("Flagged only")
                            Button("Done").onClicked { filtering = false }
                        }
                    }

                Text(filtering ? "The popover shows" : "The popover is closed")
            }
            .horizontalAlignment(.start)
        }
        """#,
        "MailList": #"""
        // Sources/Samples/Collections/ItemActionsSample.swift
        @State private var mail = ["Lunch on Friday?", "Your order shipped", "Weekly notes", "Old news"]
        @State private var archived = 0

        var body: some View {
            Grid {
                Text("\(archived) archived")
                    .gridRow(0)

                ItemsView(mail, id: \.self) { message in
                    Text(message)
                        // The item's actions, written once: a swipe where the platform swipes a list's items.
                        .contextMenu {
                            MenuItem("Archive").onClicked {
                                mail.removeAll { $0 == message }
                                archived += 1
                            }
                            MenuItem("Delete").role(.destructive).onClicked { mail.removeAll { $0 == message } }
                        }
                }
                .gridRow(1)
            }
            .rows(.auto, .fill)
        }
        """#,
        "MainPage.bar": #"""
        // Sources/Gallery/MainPage.swift
        // The gallery's own actions, declared once over every page of the
        // detail - the part a split view's own stand in unless they say
        // another - together on one background: a page's own stand nearer
        // the title, and these keep their place at the edge. Each wears an
        // icon, which keeps its size on the bar steady; its caption stays
        // for accessibility and for bars that show words.
        .toolbar {
            ToolbarGroup {
                ToolbarButton.inspector(window)
                    .text("Inspector")
                    .icon(ImageSource(light: "nav_inspect.png", dark: "nav_inspect_dark.png"))

                if !nav.showing(.home) {
                    ToolbarButton.home(nav)
                }
            }

            // The menu's own: over the sidebar, and at the detail's start
            // while the sidebar is hidden.
            if bar.showsSurprise {
                ToolbarButton("Surprise me")
                    .icon(ImageSource(light: "nav_surprise.png", dark: "nav_surprise_dark.png"))
                    .placement(.sidebar)
                    .onClicked { nav.surprise(from: catalog, on: device) }
            }
        }
        """#,
        "MainPage.created": #"""
        // Sources/Gallery/MainPage.swift
        // The window's name and its size: `width` and `height` are its size
        // as it opens, the minimum how small the user may drag it before the
        // layout stops making sense - and no maximum, so maximized it fills
        // the largest screen. On a phone or a
        // tablet the system sizes the window and these go unused - and the
        // gallery writes no `x` or `y` on purpose: pinning an app to the same
        // corner of the screen at every launch is worse than letting the
        // platform place it.
        .onCreated {
            window.title = "StateUI Gallery"
            window.width = 1100
            window.height = 800
            dress(window)
            window.minimumWidth = 700
            window.minimumHeight = 500
            window.isMaximizable = true
            window.isMinimizable = true

            log.note("created")
        }
        // The Appearance sample changes the look while the window stands.
        .onChanged(style.look(dark: false)) { dress(window) }
        .onChanged(style.look(dark: true)) { dress(window) }
        .onChanged(application.info.accentColor) { dress(window) }
        """#,
        "MainPage.detail": #"""
        // Sources/Gallery/MainPage.swift
        /// The other half of the split view: the section, arranged the way that section
        /// wants to be.
        ///
        /// Almost always a STACK - a `NavigationStack` over the path, with the
        /// section's own page underneath. The tabs demonstration is the exception,
        /// and it is the reason this is a function rather than one expression: a
        /// `TabView` is a page like any other, so a section may simply be one -
        /// and a stack may sit inside one of its tabs.
        @ViewBuilder
        func detail() -> some View {
            if case .tabs = nav.section {
                tabs()
            } else {
                NavigationStack(nav.$path) {
                    root()
                } destination: { route in
                    page(for: route, path: nav.$path)
                }
            }
        }
        """#,
        "MainPage.links": #"""
        // Sources/Gallery/MainPage.swift
        // A link the application is asked to open, given to this window: the
        // window shows the sample it names - its own navigation, as every
        // gallery window moves on its own.
        .onLinkOpened { nav.follow(link: $0, in: catalog) }
        """#,
        "MainPage.look": #"""
        // Sources/Gallery/MainPage.swift
        /// What a surface of the gallery is made of, a material for each theme as
        /// its looks say - the platform's own in a theme whose look leaves it.
        private func surface(_ part: KeyPath<ThemeLook, SurfaceLook>, _ painted: GallerySurface) -> Material {
            let system = application.info.accentColor
            return Material(
                light: style.look(dark: false)[keyPath: part].material(system: system, for: painted),
                dark: style.look(dark: true)[keyPath: part].material(system: system, for: painted))
        }

        /// Dresses `window` as the gallery's looks say, one for each theme: what it
        /// is made of behind its pages - the platform's own where both leave it.
        private func dress(_ window: WindowSession) {
            let unsaid = style.look(dark: false).window.material == .platform
                && style.look(dark: true).window.material == .platform
            window.background = unsaid ? nil : surface(\.window, .window)
        }
        """#,
        "MainPage.modal": #"""
        // Sources/Gallery/MainPage.swift
        // What is over all of it: a page presented over the split view,
        // the stack and the bars alike - while the state says so, the
        // user's dismissal writing it false.
        .sheet(isPresented: nav.$presentsPage) {
            ModalPage(shown: nav.$presentsPage, depth: 1)
        }
        """#,
        "MainPage.overlays": #"""
        // Sources/Gallery/MainPage.swift
        // The window's notice, over every page while the gallery says so.
        .overlays {
            if nav.windowNotice {
                WindowNotice(words: "Over every page", shown: nav.$windowNotice)
            }
        }
        """#,
        "MainPage.split": #"""
        // Sources/Gallery/MainPage.swift
        SplitView(nav.$menuOpen) {
            MenuPage(
                catalog: catalog,
                nav: nav,
                log: log,
                listsHiddenRow: nav.listsHiddenRow)
        } detail: {
            detail()
        }
        // What the sidebar stands on beside the page and sliding over it,
        // in each theme, as the gallery's looks say.
        .sidebarBackground(surface(\.sidebar, .sidebar))
        .sidebarOverlayBackground(surface(\.sidebarOverlay, .sidebarOverlay))
        // Where the platform places it for the room: a choice closes it
        // over the page and leaves it open beside it.
        .sidebarOverlays(nav.$menuOverlays)
        // Whether the bar offers the menu's button - the Split view
        // sample's switch takes it away.
        .showsSidebarToggle(nav.$showsMenuButton)
        """#,
        "MainPage.tabs": #"""
        // Sources/Gallery/MainPage.swift
        /// The one section that is not a stack: a `TabView` over a list of the
        /// author's own enum, with a stack inside its `.stack` tab.
        func tabs() -> some View {
            TabView(nav.tabs, selection: nav.$tab) { which in
                switch which {
                case .stack:
                    NavigationStack(nav.$tabsPath) {
                        TabsPage(nav: nav, path: nav.$tabsPath)
                    } destination: { route in
                        page(for: route, path: nav.$tabsPath)
                    }
                    // A tab's caption and picture are what its page says, and this
                    // tab's page is the stack rather than the page inside it - so
                    // they are written on the stack.
                    .title("Stack")
                    .icon(ImageSource(light: "tab_bar.png", dark: "tab_bar_dark.png"))

                case .second:
                    SecondTabPage(nav: nav)

                case .extra(let number):
                    TabsExtraPage(nav: nav, number: number)
                }
            }
        }
        """#,
        "MapSample": #"""
        // Sources/Samples/Media/MapSample.swift
        @State private var said = "tap the map, a pin, or its details"

        @Aim(Map.self) private var map
        @State private var kind = MapType.standard
        @State private var traffic = false
        @State private var showsMe = false
        @State private var locked = false

        /// The places the map marks.
        private static let places = [
            Place(name: "Wawel Castle", address: "Wawel 5", type: .place, latitude: 50.0540, longitude: 19.9354),
            Place(name: "Main Market Square", address: "Main Market Square 1/3", type: .searchResult,
                  latitude: 50.0617, longitude: 19.9373),
        ]

        /// A place on the map: its name, where it stands, and what it is.
        private struct Place {
            let name: String
            let address: String
            let type: MarkerType
            let latitude: Double
            let longitude: Double
        }

        var body: some View {
            VStack {
                // What the map last said is read here, so every tap on it builds
                // this closure.
                DebugInfoLabel()

                HStack {
                    Button("Old Town")
                        .onClicked(.cancelPrevious) {
                            try await map.moveToRegion(
                                MapRegion(center: Location(latitude: 50.0617, longitude: 19.9373), radiusMeters: 1500))
                        }

                    Button("Poland")
                        .onClicked(.cancelPrevious) {
                            try await map.moveToRegion(
                                MapRegion(center: Location(latitude: 52.1, longitude: 19.4), radiusMeters: 350_000))
                        }

                    // What it DRAWS, cycled so all three can be seen.
                    Button(kind == .standard ? "Street" : kind == .satellite ? "Satellite" : "Hybrid")
                        .onClicked {
                            kind =
                                kind == .standard
                                ? .satellite
                                : kind == .satellite ? .hybrid : .standard
                        }
                }
                .horizontalAlignment(.center)

                HStack {
                    SwitchRow("Traffic", $traffic)

                    SwitchRow("Show me", $showsMe)
                }
                .horizontalAlignment(.center)

                // Zoom and drag both off at once, which is what "locked" means to
                // a user.
                SwitchRow("Locked", $locked)
                    .horizontalAlignment(.center)

                // The opening region is the INITIALIZER's, not an `.onCreated` act:
                // written here it is kept until the platform's map has connected,
                // while an act can land an instant too early and be overwritten
                // by the map's own opening view.
                Map(region: MapRegion(center: Location(latitude: 50.0617, longitude: 19.9373), radiusMeters: 1500))
                    .aim(map)
                    // What the map draws, and whether the user may move it.
                    .mapType(kind)
                    .showsTraffic(traffic)
                    .showsUserLocation(showsMe)
                    .isZoomEnabled(!locked)
                    .isScrollEnabled(!locked)
                    .markers {
                        // Each place its own marker by its name, so a place put
                        // before the others leaves them themselves.
                        Self.places.map { place in
                            Marker(at: Location(latitude: place.latitude, longitude: place.longitude))
                                .id(place.name)
                                .label(place.name)
                                .subtitle(place.address)
                                // What the marker stands for, which is what decides
                                // the icon the platform draws for it.
                                .type(place.type)
                                .onSelected { said = "pin: \(place.name)" }
                                .onDetailsClicked { said = "details: \(place.name)" }
                        }
                    }
                    .onMapClicked { location in
                        said = "map: \(rounded(location.latitude)), \(rounded(location.longitude))"
                    }
                    .height(300)

                Text(said)
            }
        }

        /// Four decimal places - about eleven meters - so a tapped point reads as
        /// a coordinate rather than a river of digits.
        private func rounded(_ degrees: Double) -> Double {
            (degrees * 10_000).rounded() / 10_000
        }
        """#,
        "MaterialsSample": #"""
        // Sources/Samples/Styles/MaterialsSample.swift
        /// Which of the blurs the blurred panel wears.
        @State private var thickness = Blur.regular

        /// Whether the blur wears the gallery's color as a tint.
        @State private var tinted = false

        /// Whether the glass is the clearer kind.
        @State private var clear = false

        /// Whether the glass answers the touch and the pointer.
        @State private var interactive = false

        /// The color the last panel walks to and back - a color's channel.
        @State private var wash = Palette.accent

        /// The blurs on offer, thinnest first.
        private static let blurs: [(name: String, blur: Blur)] = [
            ("Ultra thin", .ultraThin), ("Thin", .thin), ("Regular", .regular), ("Thick", .thick),
            ("Ultra thick", .ultraThick),
        ]

        var body: some View {
            let chosen = thickness
            let blur = tinted ? chosen.tint(Palette.accent.opacity(0.25)) : chosen
            let glass = (clear ? Glass.clear : .regular).isInteractive(interactive)

            return VStack {
                ZStack {
                    // Stripes of color behind the panels: what each lets through shows on them.
                    Grid {
                        Fill(.tomato)
                            .gridColumn(0)
                        Fill(.gold)
                            .gridColumn(1)
                        Fill(.steelBlue)
                            .gridColumn(2)
                        Fill(.white)
                            .gridColumn(3)
                        Fill(Palette.accent)
                            .gridColumn(4)
                    }
                    .columns(.fill, .fill, .fill, .fill, .fill)

                    Grid {
                        panel("Color", .color(Palette.accent)).gridRow(0).gridColumn(0)
                        panel("Gradient", .gradient(Palette.identity)).gridRow(0).gridColumn(1)
                        panel("Blur", .blur(blur)).gridRow(1).gridColumn(0)
                        panel("Glass", .glass(glass)).gridRow(1).gridColumn(1)
                        // A blur in the dark theme, and nearly white in the light one.
                        panel("Light and dark", Material(light: .color(Color.white.opacity(0.85)), dark: .blur(.regular)))
                            .gridRow(2).gridColumn(0)
                        // A color's channel: the host walks the color, and no view is built again.
                        words("A color's channel")
                            .height(76)
                            .gridRow(2).gridColumn(1)
                    }
                    .columns(.fill, .fill)
                }
                .clipsContent(true)

                Picker(Self.blurs.map(\.blur), selection: $thickness) { blur in
                    Self.blurs.first { $0.blur == blur }?.name ?? ""
                }
                SwitchRow("Tinted blur", $tinted)
                SwitchRow("Clear glass", $clear)
                SwitchRow("Glass answers the touch", $interactive)
                Button("Change the color")
                    .horizontalAlignment(.center)
                    .onClicked { wash = wash == Palette.accent ? Palette.brand : Palette.accent }
            }
        }

        /// A panel of `material`, named.
        private func panel(_ name: String, _ material: Material) -> ZStack {
            words(name)
                .height(76)
        }

        /// A panel's name, in its middle.
        private func words(_ name: String) -> ZStack {
            ZStack {
                Text(name)
                    .fontWeight(.bold)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
            }
        }
        """#,
        "MenuBarSample": #"""
        // Sources/Samples/Navigation/MenuBarSample.swift
        @State private var saved = 0
        @State private var exported = 0

        /// Whether this page saves: its File menu then holds Save.
        @State private var pageSaves = false

        /// Whether this page adds a menu of its own.
        @State private var ownMenu = false

        /// Words to edit through the Edit menu's own entries.
        @State private var note = "Edit me"

        var body: some View {
            VStack {
                // The counts are read here, so every entry that acts builds
                // this closure.
                DebugInfoLabel()

                Text("Saved \(saved) time(s), exported \(exported)")

                Text("Open the File menu - on Android, in the bar's overflow; on GNOME, in its main menu.")

                switchRow($pageSaves, "This page saves", id: "menubar.pageSaves")
                switchRow($ownMenu, "A menu of its own", id: "menubar.ownMenu")

                Text("Select words here, then Cut, Copy, Paste or Undo from Edit.")

                TextField($note)
            }
            // File, joined by its identity with the platform's own where it has
            // one: this page's entries are a section of their own.
            .menuBar {
                Menu("File") {
                    if pageSaves {
                        MenuItem("Save")
                            .id("save")
                            .onClicked { saved += 1 }
                    }

                    MenuItem("Export…")
                        .id("export")
                        .onClicked { exported += 1 }
                }
                .id(StandardMenu.file)

                // Edit holds the platform's own entries, acting on the field the
                // user typed into; Clear stands after them, this page's own.
                Menu("Edit") {
                    MenuItem("Clear")
                        .id("clear")
                        .onClicked { note = "" }
                }
                .id(StandardMenu.edit)

                if ownMenu {
                    Menu("Sample") {
                        MenuItem("Save twice")
                            .onClicked { saved += 2 }
                    }
                    .id("sample")
                }
            }
        }

        /// A switch and what it says, told apart for scripts by `id`.
        private func switchRow(_ value: Binding<Bool>, _ words: String, id: String) -> some View {
            Switch(value)
                .text(words)
        }
        """#,
        "MenuPage": #"""
        // Sources/Gallery/MenuPage.swift
        /// The gallery's sidebar - and it is an ordinary page.
        ///
        /// That is the whole point of it. Some rows and a line at the bottom. A row
        /// is a view with a tap on it that writes state. There is no menu vocabulary
        /// to learn: what can go in the pane is whatever can go on a page, and what a
        /// row does is whatever a handler can do.
        ///
        /// Its title and picture name the gallery where the platform's chrome names
        /// an application over the sidebar.
        struct MenuPage: View {
            /// The gallery's mark beside its name: none on Windows, where a mark on the
            /// title bar reads as a button; the violet one on Android's sidebar bar,
            /// which stands on the theme's light or dark ground.
            private static var mark: ImageSource {
                #if WINUI
                ""
                #elseif ANDROID
                ImageSource(light: "stateui_mark_violet.png", dark: "stateui_mark_violet_dark.png")
                #else
                "stateui_mark.png"
                #endif
            }


            /// Everything the gallery shows - the rows are one per group.
            let catalog: Catalog

            /// Where the gallery is, so a row can move it and know whether it is the
            /// row the user is on.
            let nav: Navigation

            /// What the window has said about its life - written by the
            /// `WindowPhaseLog` this page holds, as the window's phase moves.
            let log: WindowLog

            /// Whether the row that is hidden by default is listed - the Split view sample
            /// writes it, and here it is an `if` around the row.
            let listsHiddenRow: Bool

            /// The device's facts: which samples Surprise me draws from, and the line
            /// at the bottom.
            @Environment(\.device) private var device

            var body: some View {
                // The rows run under the bars, the first and the last stopping clear
                // of them.
                Grid {
                    ScrollView {
                        rows
                    }
                }
                .ignoresSafeArea(.all)
                .title("StateUI")
                .icon(Self.mark)
                // The line about what this is stands at the menu's foot, and the rows
                // scroll under it.
                .bottomBar {
                    ZStack {
                        footer
                        WindowPhaseLog(log: log)
                    }
                }
            }

            /// Home, one row per group, the row that is not always listed, and the one
            /// row that goes nowhere fixed: it opens a sample chosen at random.
            private var rows: some View {
                VStack {
                    MenuRow("Home") { nav.open(.home) }
                        .icon(ImageSource(light: "nav_home.png", dark: "nav_home_dark.png"))
                        .chosen(nav.showing(.home))

                    // One row per group, built from the catalog - so a new group is a
                    // line there rather than a change here.
                    ForEach(catalog.groups, id: \.route) { group in
                        MenuRow(group.title) { nav.openGroup(group.route) }
                            .icon(group.icon)
                            .chosen(nav.showingGroup(group.route))
                    }

                    // A row the menu lists only when it is told to. The page behind it
                    // is reachable either way - `.hidden` is a value, and a value nobody
                    // drew a row for is still a value. The list being a view, the answer
                    // is an `if`.
                    if listsHiddenRow {
                        MenuRow("Not in the list") { nav.open(.hidden) }
                            .icon(ImageSource(light: "nav_hidden.png", dark: "nav_hidden_dark.png"))
                            .chosen(nav.showing(.hidden))
                    }

                    // A row with no fixed place to go: it pushes a sample chosen at
                    // random. It needs no type of its own: the same view, with a
                    // different handler.
                    MenuRow("Surprise me") { nav.surprise(from: catalog, on: device) }
                        .icon(ImageSource(light: "nav_surprise.png", dark: "nav_surprise_dark.png"))
                }
                // Clear of the pane's edges, so the chosen row's fill stands inside it.
            }

            /// What is underneath: the platform compiled in, the formFactor the host
            /// answered before the first render, and the StateUI release it is built on.
            private var footer: some View {
                Text("native: \(stateUIPlatform()) · \(device.info.formFactor)\nStateUI \(stateUIVersion())")
                    #if UIKIT
                    // Above the home indicator's strip, which stands under it: none
                    // of its own beneath.
                    .padding(start: 12, top: 6, end: 12, bottom: 0)
                    #else
                    .padding(horizontal: 12, vertical: 6)
                    #endif
            }
        }
        """#,
        "ModalPage": #"""
        // Sources/Samples/Navigation/ModalPage.swift
        /// A page presented OVER everything - the bars, the menu and the stack alike.
        ///
        /// A sheet has no bar of its own, so it carries its own way out; a stack
        /// presented in a sheet brings its bar. Each sheet stands on the button
        /// presenting it, by a state of its own.
        struct ModalPage: View {
            /// Whether this page stands presented: Close writes it false.
            @Binding var shown: Bool

            /// How many sheets stand, this one included.
            let depth: Int

            /// Whether another page stands over this one, and whether a stack does.
            @State private var presentsAnother = false
            @State private var presentsStack = false

            var body: some View {
                VStack {
                    SectionTitle("Over everything")

                    Text("Native modal page")
                        .fontWeight(.bold)

                    Text("Present a stack: its bar comes with it.")

                    Button("Close")
                        .horizontalAlignment(.center)
                        .onClicked { shown = false }

                    Button("Present another")
                        .horizontalAlignment(.center)
                        .onClicked { presentsAnother = true }
                        .sheet(isPresented: $presentsAnother) {
                            ModalPage(shown: $presentsAnother, depth: depth + 1)
                        }

                    Button("Present a stack")
                        .horizontalAlignment(.center)
                        .onClicked { presentsStack = true }
                        .sheet(isPresented: $presentsStack) {
                            StackSheet(shown: $presentsStack)
                        }

                    Text("Depth: \(depth)")
                }
                .verticalAlignment(.center)
            }
        }

        /// A stack presented in a sheet: the bar over its pages is the stack's own, its close button the page's to offer.
        struct StackSheet: View {
            @Binding var shown: Bool
            @State private var path: [Int] = []
            @State private var offersClose = true

            var body: some View {
                NavigationStack($path) {
                    VStack {
                        Switch($offersClose).text("Close button")
                        Button("Push").onClicked { path.append(path.count + 1) }
                        Button("Close").onClicked { shown = false }
                    }
                    .galleryPage("In a stack")
                    .showsCloseButton(offersClose)
                } destination: { number in
                    Text("Page \(number)")
                        .galleryPage("Pushed")
                }
            }
        }
        """#,
        "ModalSample": #"""
        // Sources/Samples/Navigation/ModalSample.swift
        let nav: Navigation

        var body: some View {
            VStack {
                DebugInfoLabel()

                Button("Present native modal")
                    .horizontalAlignment(.center)
                    .onClicked { nav.presentsPage = true }

                Text(nav.presentsPage ? "Presented" : "Nothing presented")
            }
        }
        """#,
        "MotionLayoutSample": #"""
        // Sources/Samples/MotionLayout/MotionLayoutSample.swift
        import StateUIFoundation

        /// The cards: the gallery's groups, each its name and its picture as the
        /// home page shows it.
        static let cards: [Card] = [
            Card(name: "Layout", art: "cat_layout.png"),
            Card(name: "Motion Layout", art: "cat_motionlayout.png"),
            Card(name: "Styles", art: "cat_styles.png"),
            Card(name: "Shapes", art: "cat_shapes.png"),
            Card(name: "Media", art: "cat_media.png"),
            Card(name: "Navigation", art: "cat_navigation.png"),
            Card(name: "Date & time", art: "cat_datetime.png"),
            Card(name: "Fundamentals", art: "cat_fundamentals.png"),
            Card(name: "Animation", art: "cat_animation.png"),
            Card(name: "Gestures", art: "cat_gestures.png"),
        ]

        /// One card's face.
        struct Card {
            let name: String
            let art: String
        }

        /// What the ring places: every card, and a dot for each at the board's
        /// foot - one arithmetic for both, so the dots move with the cards.
        enum Piece: Hashable {
            case card(Int)
            case dot(Int)
        }

        static let pieces = cards.indices.map(Piece.card) + cards.indices.map(Piece.dot)

        /// How big the place a card stands in is - what the ring is worked out
        /// from - and how big the card is drawn in it.
        static let width = 176.0
        static let height = 248.0
        static let card = 0.8

        /// How far the eye stands from the ring's front, in radii: the nearer it
        /// stands, the smaller a card at the back is drawn.
        static let eye = 1.6

        /// How far below the horizon the front card stands, in card heights: the
        /// higher the eye above the ring, the more of the far cards it sees.
        static let above = 1.9

        /// How tall the whole ring stands, in card heights: the back card's top to
        /// the front card's foot.
        static var ringHeight: Double { above - back * (above - 1) }

        /// How big the card at the back is drawn, against the one at the front.
        static var back: Double { eye / (eye + 2) }

        /// HOW A THROW GOES ON - any motion: how far a throw carries, and the
        /// curve it slows on.
        enum Throwing: CaseIterable, Hashable {
            case easeOut, glide, spring, bounce, short

            var motion: Motion {
                switch self {
                case .easeOut: .eased(.milliseconds(400), .cubicOut)
                case .glide: .eased(.milliseconds(300), .sineOut)
                case .spring: .spring(response: .milliseconds(400), damping: 0.8)
                case .bounce: .eased(.milliseconds(600), .backOut)
                case .short: .eased(.milliseconds(200), .cubicOut)
                }
            }

            var title: String {
                switch self {
                case .easeOut: "Ease out"
                case .glide: "Glide"
                case .spring: "Spring"
                case .bounce: "Bounce"
                case .short: "Short"
                }
            }
        }

        /// Which of them the ring is thrown by.
        @State private var throwing = Throwing.easeOut

        /// Whether the board is laid out right to left, and whether the ring
        /// turns with it or keeps the shape its arithmetic writes.
        @State private var rightToLeft = false
        @State private var mirrored = true

        /// Whether each card follows its place as a body, lagging as the ring
        /// turns and swaying back onto it.
        @State private var swaying = true

        /// Whether the ring grows as it turns - the cards flung outward, as a
        /// weight on a string is - read by the arithmetic below, never the body.
        @State private var flungOut = true

        /// The card the ring last came to rest on - every card and the ring
        /// still - told once each rest.
        @State private var rested = MotionLayoutSample.cards.count / 2

        /// WHICH CARD IS AT THE FRONT - the parameters, two-way: `Back` and `Next`
        /// write it and the ring travels there; the hand names the card it passes
        /// and the one it comes to rest on. It starts on the middle card, and it
        /// has no end: a turn on, it is the same card again.
        @State private var turn = Double(MotionLayoutSample.cards.count / 2)

        /// The device - a phone's cards carry their names alone, smaller.
        @Environment(\.device) private var device

        var body: some View {
            // A GRID rather than a stack: the board takes whatever room is left
            // over, which a stack cannot give a child - and a ring wants it all.
            Grid {
                Grid {
                    // THE CARDS, and what moves them - the whole of the example.
                    ring

                    // The ring turns for no build at all: the label says so, at
                    // the board's top corner.
                    DebugInfoLabel()
                        .horizontalAlignment(.end)
                        .verticalAlignment(.start)
                }
                .layoutDirection(rightToLeft ? .rightToLeft : .inherited)
                .gridRow(0)
                // The cards stay ON the board: one turned far out in a small room
                // is cut at the board's edge rather than painted over the page.
                .clipsContent(true)

                // WHERE THE RING CAME TO REST, told once it is still.
                Text("At rest on \(Self.cards[rested].name)")
                    .horizontalAlignment(.center)
                    .gridRow(1)

                HStack {
                    Button("Back")
                        .onClicked { move(-1) }

                    Button("Next")
                        .onClicked { move(1) }

                }
                .horizontalAlignment(.center)
                .gridRow(2)

                Picker(Throwing.allCases, selection: $throwing) { $0.title }
                    .horizontalAlignment(.center)
                    .gridRow(3)

                HStack {
                    SwitchRow("Right to left", $rightToLeft)

                    SwitchRow("Mirrored", $mirrored)

                    SwitchRow("Cards sway", $swaying)

                    SwitchRow("Flung outward", $flungOut)
                }
                // On a narrow screen the switches go on onto further lines, each
                // line in the middle.
                .wraps(true)
                .lineAlignment(.center)
                .horizontalAlignment(.center)
                .gridRow(4)
            }
            .rows(.fill, .auto, .auto, .auto, .auto)
        }

        /// The ring of cards and its dots, placed by the arithmetic below.
        private var ring: some View {
            MotionLayout(Self.pieces, parameters: $turn) { piece in
                switch piece {
                case .card(let index):
                    // A BODY FOLLOWING ITS PLACE: carried by the ring, the card lags
                    // behind as it turns, swings past where the turn stops and
                    // settles back onto its place.
                    if swaying {
                        face(Self.cards[index])
                            .followsLayout(.spring(response: .milliseconds(420), damping: 0.55))
                    } else {
                        face(Self.cards[index])
                    }
                case .dot:
                    Rectangle()
                        .fill(Palette.text)
                }
            } placements: { room, turn in
                // THE WHOLE LAYOUT, run on the display's own frames whenever the
                // room or the parameters have moved, with no view built.
                // FLUNG OUTWARD, the ring grows with how fast it turns.
                let flung = flungOut ? min(abs($turn.journey.velocity) * 0.05, 0.35) : 0
                return Self.cards.indices.map { place($0, turn, room, flung: flung) }
                    + Self.cards.indices.map { dot($0, turn, room) }
            }
            // THE HAND OVER THE CARDS: a finger or a pointer dragged, a trackpad's
            // two fingers and a wheel all turn the ring, carrying the card in
            // front with them, and let go with speed it goes on to the card
            // nearest where the throw would end. It rests on a card, never
            // between two - and comes round, a turn of the range bringing every
            // card back.
            .axis(\.self, input: .scroll(.horizontal), range: 0...Double(Self.cards.count), snaps: .every(1), periodic: true)
            .throwMotion(throwing.motion)
            // WHAT `shade` IN THE ARITHMETIC BELOW IS WORN BY: one view, drawn
            // over every card, wearing the card's own corners - which is why it is
            // the application's to give and not the library's to draw.
            .shade(
                Rectangle()
                    .fill(Color(hex: 0x000000)))
            .motion(.eased(.milliseconds(300), .cubicOut))
            // AT REST - the ring and every card still - it says where, once.
            .onSettled { turned in
                let count = Self.cards.count
                rested = ((Int(turned.rounded()) % count) + count) % count
            }
            // RIGHT TO LEFT, MIRRORED: the ring turns about the board's middle,
            // the arithmetic above still written left to right, and the hand turns
            // it the mirror's way. Not mirrored, it keeps the shape it is written in.
            .mirrorsRightToLeft(mirrored)
        }

        /// A card either way, from a button: the ring travels there, and the
        /// arithmetic follows it frame by frame - past the last card to the first.
        private func move(_ by: Int) {
            turn += Double(by)
        }

        /// One card's face - a picture and its name, and nothing at all about where
        /// the card is or which way it faces. That is the placement's, and keeping
        /// the two apart is what lets one run of cards be turned into any shape.
        private func face(_ card: Card) -> some View {
            let phone = device.info.formFactor == .phone

            return ZStack {
                Grid {
                    Image(ImageSource(card.art))
                        .contentMode(.fill)

                    VStack {
                        // ONE LINE, whatever the card's width: a caption that
                        // wrapped would change the picture's height with it.
                        Text(card.name)
                            .fontWeight(.bold)
                            .lineBreak(.tailTruncation)

                        // A phone's small card carries its name alone.
                        if !phone {
                            Text("Placed by arithmetic")
                                .opacity(0.8)
                                .lineBreak(.tailTruncation)
                        }
                    }
                    // A dark strip under the words, so a caption reads over a
                    // picture of any color.
                    .verticalAlignment(.end)
                }
                // THE PICTURE IS CUT AT THE CARD'S EDGE: a picture told to FILL
                // the card is cut at its own room - the Web's reaches two points
                // past it - so the grid holding it - a layout, with edges to cut
                // at - cuts it there.
                .clipsContent(true)
            }
            .style(.card)
            .lineWidth(0)
        }

        /// How big the cards are in THIS room, as a multiple of the size above -
        /// what every distance below scales with.
        ///
        /// BOTH AXES: the ring spread to either side takes the room's width, and
        /// the ring seen from above - the back card's top to the front card's foot
        /// - its height above the dots; the smaller of the two answers, so a
        /// window grown taller draws a bigger ring and a phone on its side -
        /// plenty of width, almost no height - is answered by the height.
        private func fit(in room: Rect) -> Double {
            max(
                min(
                    1.375,
                    (room.width * 0.4 - 6) / Self.width,
                    (room.height - 46) / (Self.height * Self.ringHeight)),
                0.1)
        }

        /// A RING IN SPACE, turned to `at` - the cards standing upright on a
        /// circle that lies flat, seen from in front and above, the chosen card
        /// nearest the eye. The whole of the layout.
        private func place(_ index: Int, _ at: Double, _ room: Rect, flung: Double = 0) -> Placement {
            let count = Self.cards.count
            let fit = fit(in: room)
            let step = Double(index) - at
            let angle = step / Double(max(count, 1)) * 2 * .pi
            let wide = Self.width * fit
            let tall = Self.height * fit

            // PERSPECTIVE: how big a card is drawn - 1 at the front, under half at
            // the back - which also says how near the middle it stands and how far
            // below the horizon its foot is.
            let drawn = Self.eye / (Self.eye + 1 - cos(angle))

            // The circle as wide as the room lets the cards spread, and the horizon
            // where the whole ring - the back card's top to the front card's foot -
            // stands in the middle of the room above the dots.
            let radius = min(wide * 1.75, (room.width / 2 - 8 - wide * 0.33) / 0.65)
            let horizon = (room.height - 30 - tall * Self.ringHeight) / 2 - tall * Self.back * (Self.above - 1)
            // Flung outward, every card farther from the ring's middle - across,
            // and nearer or farther from the eye.
            let across = room.width / 2 + sin(angle) * radius * drawn * (1 + flung)
            let foot = horizon + tall * Self.above * (1 + (drawn - 1) * (1 + flung))

            // THE CARD AT ITS OWN SIZE, a little smaller than its place, standing
            // on the ring where its place does.
            let (cardWide, cardTall) = (wide * Self.card, tall * Self.card)

            return Placement(
                // Scaled about its middle to how big it is drawn - its words scale
                // with it rather than wrapping anew.
                Rect(across - cardWide / 2, foot - cardTall * drawn / 2 - cardTall / 2, cardWide, cardTall),
                transform: .scale(drawn),
                // THE FAR CARDS DARKEN. `shade` is the opacity of the view the
                // layout was given by `.shade(_:)` - nothing at all without one -
                // and here it is how far back the card stands. A FADE would show
                // the card behind it, which on a ring is every other card.
                shade: min((1 - drawn) * 1.1, 0.55),
                // The nearer card is drawn over the farther one.
                zIndex: Int(cos(angle) * 1000))
        }

        /// One dot at the board's foot, saying which card is at the front by a
        /// fade - over every card.
        private func dot(_ index: Int, _ at: Double, _ room: Rect) -> Placement {
            let count = Self.cards.count

            return Placement(
                Rect(
                    room.width / 2 + (Double(index) - Double(count - 1) / 2) * 13 - 3,
                    room.height - 16,
                    6,
                    6),
                // THE RING COMES ROUND: how far a card is from the front is taken
                // the short way, a turn on or back.
                opacity: 0.25 + 0.75 * chosen((Double(index) - at).remainder(dividingBy: Double(count))),
                zIndex: 2000)
        }

        /// How much of "the chosen one" a card is: 1 at the front, nothing a card
        /// away, and part way between while the ring is moving - which is what
        /// makes the emphasis cross over rather than jump.
        private func chosen(_ step: Double) -> Double {
            max(0, 1 - abs(step))
        }

        """#,
        "MotionSample": #"""
        // Sources/Samples/Animation/MotionSample.swift
        static let laws = ["Eased 200ms", "Spring", "Long and slow", "None"]

        static func law(_ index: Int) -> Motion {
            switch index {
            case 1: .spring(response: .milliseconds(320))
            case 2: .eased(.milliseconds(900), .sineInOut)
            case 3: .none
            default: .standard
            }
        }

        @State private var law = 2
        @State private var wide = false
        @State private var warm = false
        @State(motion: .spring(response: .milliseconds(320))) private var reach = 120.0

        var body: some View {
            // NOTHING HERE SAYS "ANIMATE". A value that changes is a setpoint: the
            // tree says where the panel is going and the host carries it there.
            VStack {
                // The panels are described from `wide`, `warm` and `law`, read
                // here, so a press builds this closure once and the host walks
                // the rest.
                DebugInfoLabel()

                Text("A change that travels")
                    .tracking(1)

                panel(travels: true)

                Text("The same, told to stay still")
                    .tracking(1)

                panel(travels: false)

                Text("The same, holding only its size still")
                    .tracking(1)

                sized()

                HStack {
                    Button("Size").onClicked { wide.toggle() }
                    Button("Color").onClicked { warm.toggle() }
                    Button(Self.laws[law]).onClicked { law = (law + 1) % Self.laws.count }
                }

                Text("A move's own law, then the value's")
                    .tracking(1)

                Rectangle()
                    .fill(Palette.brand)
                    .width($reach)
                    .height(24)
                    .horizontalAlignment(.start)

                HStack {
                    // The law given here is this move's alone...
                    Button("Slow move").onClicked {
                        $reach.journey.move(to: 300, .eased(.milliseconds(2000), .sineInOut))
                    }
                    // ...and a plain write travels on the value's own spring.
                    Button("Back").onClicked { reach = 120 }
                }
            }
        }

        /// One panel, either traveling at the chosen law or arriving at once.
        private func panel(travels: Bool) -> some View {
            // `.motion` is per view: the chosen law, or `.none` to arrive at once.
            Rectangle()
                .fill(warm ? Palette.accent : Palette.brand)
                .width(wide ? 300 : 120)
                .height(wide ? 110 : 56)
                .horizontalAlignment(.start)
                .motion(travels ? Self.law(law) : .none)
        }

        /// The same panel with a RULE: everything travels except its size, which
        /// `.size` takes to be its width and its height - its corners are its
        /// shape, and travel with the rest.
        private func sized() -> some View {
            Rectangle()
                .fill(warm ? Palette.accent : Palette.brand)
                .width(wide ? 300 : 120)
                .height(wide ? 110 : 56)
                .horizontalAlignment(.start)
                .motion(Self.law(law))
                .motion(.none, .size)
        }
        """#,
        "MultiWindowSample": #"""
        // Sources/Samples/Windows/MultiWindowSample.swift
        /// The look every gallery window wears, which the Fonts and Colors
        /// windows change.
        let style: SessionStyle

        /// The galleries' scene as it runs: its windows, and closing it whole.
        @Environment(\.scene) private var scene

        /// The application as it runs - which opens a window in the scene
        /// declaring it.
        @Environment(\.application) private var application

        /// What the last button answered: the window it opened or closed, or what
        /// it was refused with.
        @State private var said = "Nothing asked yet."

        var body: some View {
            VStack {
                preview

                SectionTitle("The scene's windows")

                HStack {
                    opens("Fonts", .fonts)
                    opens("Colors", .colors)
                }
                .horizontalAlignment(.center)

                HStack {
                    closes("Close fonts", .fonts)
                    closes("Close colors", .colors)
                }
                .horizontalAlignment(.center)

                VStack {
                    DebugInfoLabel()

                    Text(said)

                    Text("Windows in this scene: \(scene.windows.count)")

                    Text(scene.windows.map { $0.title ?? "untitled" }.joined(separator: " · "))
                }

                SwitchRow("Hide them behind another scene", style.$hidesTools)
                SwitchRow("Keep them on top", style.$floatsTools)

                SectionTitle("A window per value")

                HStack {
                    swatch(1)
                    swatch(2)
                    swatch(3)
                }
                .horizontalAlignment(.center)

                Button("Close swatch 2")
                    .horizontalAlignment(.center)
                    .onClicked(.ignoreWhileRunning) { await closeSwatch(2) }

                SectionTitle("More gallery windows")

                Button("New gallery window")
                    .horizontalAlignment(.center)
                    .onClicked(.ignoreWhileRunning) { await openAnother() }

                Button("Close every gallery window")
                    .horizontalAlignment(.center)
                    .onClicked(.ignoreWhileRunning) { await closeThis() }
            }
        }

        /// A line in the scene's font and accent - what its two windows change.
        private var preview: some View {
            let line = Text("The quick brown fox jumps over the lazy dog.")
                .textColor(style.look(dark: application.info.colorScheme == .dark).bars.color.color(system: application.info.accentColor, for: .bar))

            return style.font.isEmpty ? line : line.fontFamily(style.font)
        }

        /// The button that opens one of the scene's windows.
        private func opens(_ caption: String, _ type: WindowType<Void>) -> some View {
            Button(caption)
                .onClicked(.ignoreWhileRunning) { await open(type, caption) }
        }

        /// The button that closes it.
        private func closes(_ caption: String, _ type: WindowType<Void>) -> some View {
            Button(caption)
                .onClicked(.ignoreWhileRunning) { await close(type, caption) }
        }

        /// Opens a window of the scene, and says what came of it.
        private func open(_ type: WindowType<Void>, _ caption: String) async {
            do {
                try await application.openWindow(type)
                said = "\(caption): opened."
            } catch WindowError.alreadyOpen {
                said = "\(caption): WindowError.alreadyOpen - it is open already."
            } catch {
                said = "\(caption): \(error)"
            }
        }

        /// Closes one, and says what came of it.
        private func close(_ type: WindowType<Void>, _ caption: String) async {
            do {
                try await application.closeWindow(type)
                said = "\(caption): closed."
            } catch WindowError.notOpen {
                said = "\(caption): WindowError.notOpen - it is not open."
            } catch {
                said = "\(caption): \(error)"
            }
        }

        /// Opens one more gallery window, as *File ▸ New Window* does.
        private func openAnother() async {
            do {
                try await application.openWindow()
                said = "Another gallery window is open."
            } catch {
                said = "Another gallery window: \(error)"
            }
        }

        /// The button that opens one swatch's window.
        private func swatch(_ number: Int) -> some View {
            Button("Swatch \(number)")
                .onClicked(.ignoreWhileRunning) { await openSwatch(number) }
        }

        /// Opens a swatch's window, and says what came of it.
        private func openSwatch(_ number: Int) async {
            do {
                try await application.openWindow(.swatch, value: number)
                said = "Swatch \(number): opened."
            } catch WindowError.alreadyOpen {
                said = "Swatch \(number): WindowError.alreadyOpen - it is open already."
            } catch {
                said = "Swatch \(number): \(error)"
            }
        }

        /// Closes one, and says what came of it.
        private func closeSwatch(_ number: Int) async {
            do {
                try await application.closeWindow(.swatch, value: number)
                said = "Swatch \(number): closed."
            } catch WindowError.notOpen {
                said = "Swatch \(number): WindowError.notOpen - it is not open."
            } catch {
                said = "Swatch \(number): \(error)"
            }
        }

        /// Ends the scene - every gallery window and every window beside them.
        private func closeThis() async {
            do {
                try await scene.close()
            } catch {
                said = "The scene: \(error)"
            }
        }
        """#,
        "Navigation.sheets": #"""
        // Sources/Gallery/Navigation.swift
        /// Whether a page stands presented over all of it - the bars included,
        /// which is the whole difference from `push`. The user dismissing it
        /// writes false, the way a back gesture shortens a path.
        @State var presentsPage = false
        """#,
        "NavigationSample": #"""
        // Sources/Samples/Navigation/NavigationSample.swift
        /// Where the gallery is. Borrowed, not held: this sample can move the
        /// application and READ where it is, and it cannot keep a stale copy of
        /// either.
        let nav: Navigation

        @State private var arrivals = 0

        var body: some View {
            VStack {
                DebugInfoLabel()

                Button("Push a page")
                    .horizontalAlignment(.center)
                    .onClicked { nav.push(.level(1)) }

                // No act, no await, no question asked of the host: the answer is
                // the state this page is reading.
                Text(here)

                Button("Go home, and count the visit")
                    .horizontalAlignment(.center)
                    .onClicked {
                        nav.home()
                        arrivals += 1
                    }

                Text("Arrived home \(arrivals) time(s)")

                Button("Empty the stack")
                    .horizontalAlignment(.center)
                    .onClicked { nav.path = [] }
            }
        }

        /// Where the user is, in words - the section and how deep above it.
        ///
        /// Read from the same state the arrangement is built from, which is the
        /// whole point: there is one answer and it cannot drift from the screen.
        private var here: String {
            let place = switch nav.section {
            case .home: "home"
            case .hidden: "the unlisted page"
            case .tabs: "the tabs"
            }

            return nav.path.isEmpty
                ? "\(place), nothing pushed"
                : "\(place) + \(nav.path.count): \(nav.path.map { "\($0)" }.joined(separator: " › "))"
        }
        """#,
        "NextFieldSample": #"""
        // Sources/Samples/Text/NextFieldSample.swift
        @State private var name = ""
        @State private var street = ""
        @State private var city = ""
        @State private var sent = false

        var body: some View {
            VStack {
                Text("Type a name and press Return: each field hands the keyboard to the next.")

                TextField($name)
                    .placeholder("Name")
                    .submitLabel(.next)

                Grid {
                    TextField($street)
                        .placeholder("Street")
                        .submitLabel(.next)

                    TextField($city)
                        .placeholder("City")
                        .submitLabel(.send)
                        .onSubmitted { sent = true }
                        .gridColumn(1)
                }
                .columns(.fill, .fill)

                Text(sent ? "Sent to \(name), \(street), \(city)" : "Not sent yet")
            }
        }
        """#,
        "OffsetStrips": #"""
        // Sources/Samples/Layout/ScrollViewSample.swift
        /// Forty numbered lines - the same strip in all three columns below, so the
        /// only difference on the screen is what the offset costs.
        @MainActor
        private func numberedLines() -> ScrollView {
            ScrollView {
                VStack {
                    ForEach(1...40) { line in
                        Text("Line \(line)")
                    }
                }
            }
        }

        /// The heading over one column.
        ///
        /// - Parameter text: what this column is.
        /// - Returns: the words, styled.
        @MainActor
        private func columnTitle(_ text: String) -> Text {
            Text(text)
                .fontWeight(.bold)
        }

        /// The spelling that makes a column what it is, under its reading.
        ///
        /// - Parameter text: the line of code this column is about.
        /// - Returns: the words, in the code face.
        @MainActor
        private func spelling(_ text: String) -> Text {
            Text(text)
        }

        /// THE OFFSET DESCRIBED: the reading is a get in these braces, so this view is
        /// the reader and is built again on every report the strip makes.
        private struct DescribedOffset: View {
            /// Where the strip is - the state declared beside the buttons that move
            /// all three strips, handed down: the scroller gets it, and the label
            /// below reads it.
            @Binding var offset: Point

            var body: some View {
                Grid {
                    columnTitle("DESCRIBED")

                    numberedLines()
                        .scrollOffset($offset)
                        .gridRow(1)

                    // THE GET. Reading the offset here is what makes this Grid its
                    // reader, and a render is what every single report then costs.
                    Text("\(Int($offset.journey.value.y)) down")
                        .gridRow(2)

                    DebugInfoLabel()
                        .horizontalAlignment(.center)
                        .gridRow(3)

                    spelling("a get in these braces")
                        .gridRow(4)
                }
                .rows(.auto, .fill, .auto, .auto, .auto)
            }
        }

        /// THE SAME GET, OFF A SAMPLE: the scroller writes a state of its own, as the
        /// column before does, and this column shows a READING of it taken at most ten
        /// times a second - so the number is as right whenever it is read, and the
        /// count climbs no faster than that.
        private struct PacedOffset: View {
            /// Handed to the scroller, as the column before.
            @Binding var offset: Point

            /// Where the value had got to when the reading was taken. An ordinary
            /// state, so the get below is a get like any other.
            let shown: Point

            var body: some View {
                Grid {
                    columnTitle("ON A CADENCE")

                    numberedLines()
                        .scrollOffset($offset)
                        .gridRow(1)

                    // The same get as the column before, over the SAMPLE rather than
                    // over the scroller's own state. The number is right the moment
                    // the reading was taken; what the window holds back is how often
                    // one is taken.
                    Text("\(Int(shown.y)) down")
                        .gridRow(2)

                    DebugInfoLabel()
                        .horizontalAlignment(.center)
                        .gridRow(3)

                    spelling(".samples($offset, into: $shown, .every(.milliseconds(100)))")
                        .gridRow(4)
                }
                .rows(.auto, .fill, .auto, .auto, .auto)
            }
        }

        /// THE OFFSET THROUGH A CHANNEL: nothing here reads it. The words are a
        /// conversion the host works out on its own frames, so the number keeps up
        /// with the finger and this view is never built again.
        private struct DrivenOffset: View {
            /// Handed to the scroller and to the conversion, and read by nobody.
            @Binding var offset: Point

            var body: some View {
                Grid {
                    columnTitle("A CHANNEL")

                    numberedLines()
                        .scrollOffset($offset)
                        .gridRow(1)

                    // NO GET. The conversion is a second state the host writes from
                    // the first, so the reading moves without a view being built -
                    // and it reads `value`, where the offset IS, so it follows a
                    // glide frame by frame rather than jumping to where it is going.
                    Text($offset.journey.convert { "\(Int($0.value.y)) down" })
                        .gridRow(2)

                    DebugInfoLabel()
                        .horizontalAlignment(.center)
                        .gridRow(3)

                    spelling("$offset.journey.convert { … }")
                        .gridRow(4)
                }
                .rows(.auto, .fill, .auto, .auto, .auto)
            }
        }

        /// One state per strip, and the three roads the columns are about: a get,
        /// a get on a cadence, and a value nothing reads. THE DECLARATIONS ARE
        /// IDENTICAL - what differs is what each column asks for and how it reads
        /// - and the buttons below write all three.
        @State private var described = Point.zero

        @State private var paced = Point.zero

        /// What the middle column shows: a reading of `paced`, taken at most ten
        /// times a second. An ordinary state, rebuilt from by an ordinary get.
        @State private var pacedShown = Point.zero

        @State private var driven = Point.zero

        var body: some View {
            Grid {
                // THREE IDENTICAL STRIPS over three states. What differs is where
                // each column's reading comes from, and the count under it is
                // what that costs - drag them and watch.
                Grid {
                    DescribedOffset(offset: $described)

                    // THE READING IS ASKED FOR WHERE IT IS SHOWN, and it is a
                    // reading of where the value HAS GOT TO - which the state
                    // itself never says, standing at its destination.
                    PacedOffset(offset: $paced, shown: pacedShown)
                        .samples($paced, into: $pacedShown, .every(.milliseconds(100)))
                        .gridColumn(1)

                    DrivenOffset(offset: $driven)
                        .gridColumn(2)
                }
                .columns(.fill, .fill, .fill)
                .gridRow(0)

                HStack {
                    Button("Top")
                        .onClicked(.cancelPrevious) { try await move(to: 0) }

                    Button("Line 9")
                        .onClicked(.cancelPrevious) { try await move(to: 240) }
                }
                .horizontalAlignment(.center)
                .gridRow(1)
            }
            .rows(.fill, .auto)
        }

        /// Puts all three strips at the same offset, one after another.
        ///
        /// A journey is awaited and answers when the glide has FINISHED, so the
        /// three strips move in turn rather than together - which is what `await`
        /// on a journey's `move(to:)` means, said on the screen.
        ///
        /// - Parameter y: how far down each strip is sent.
        private func move(to y: Double) async throws {
            for strip in [$described, $paced, $driven] {
                try await strip.journey.move(to: Point(0, y), .eased(.milliseconds(300), .cubicOut)).arrived()
            }
        }
        """#,
        "OnChangedSample": #"""
        // Sources/Samples/State/OnChangedSample.swift
        @State private var celsius = 20.0
        @State private var log: [String] = []
        @State private var fired = 0

        var body: some View {
            VStack {
                // THIS closure reads `celsius`, so every report from the slider
                // builds it again - which is what a get on a dragged value costs.
                DebugInfoLabel()

                Text("\(Int(celsius)) °C")
                    .fontWeight(.bold)
                    .horizontalAlignment(.center)

                Slider($celsius)
                    .minimum(-10)
                    .maximum(40)

                // Watches WHOLE degrees, so dragging fires once per whole degree
                // rather than once per pixel. It does not fire when the page
                // appears - a view arriving is not a value changing.
                VStack {
                    ForEach(log.reversed()) { line in
                        Text(line)
                            .id(line)
                    }
                }
                .motion(.none)
                .onChanged(Int(celsius)) { old, new in
                    fired += 1
                    let arrow = new > old ? "warmer" : "colder"
                    log.append("\(old) -> \(new) °C, \(arrow) (#\(fired))")
                    if log.count > 6 { log.removeFirst() }
                }

            }
        }
        """#,
        "OutlineSample": #"""
        // Sources/Samples/Layout/OutlineSample.swift
        @State private var clips = true

        var body: some View {
            VStack {
                VStack {
                    Text("A column")
                        .fontSize(15)
                    Text("rounded, with a hairline")
                        .fontSize(13)
                        .textColor(Palette.subtle)
                }
                .spacing(2)
                .padding(16)
                .stroke(Palette.outline)
                .lineWidth(1)
                .shape(.roundedRectangle(12))

                HStack {
                    Text("A row,")
                        .fontSize(15)
                    Text("square and thicker")
                        .fontSize(15)
                }
                .spacing(6)
                .padding(16)
                .stroke(Palette.accent)
                .lineWidth(3)
                .shape(.rectangle)

                // Its ends round whole however wide it stands.
                HStack {
                    Text("A capsule, as wide as its row")
                        .fontSize(15)
                }
                .padding(horizontal: 20, vertical: 10)
                .stroke(Palette.accent)
                .lineWidth(2)
                .shape(.capsule)

                ZStack {
                    Text("An ellipse")
                        .fontSize(15)
                        .horizontalAlignment(.center)
                        .verticalAlignment(.center)
                }
                .padding(24)
                .stroke(Palette.accent)
                .shape(.ellipse)

                // The box fills the ZStack; its corners are cut only while the
                // ZStack clips what it holds.
                ZStack {
                    Rectangle()
                        .fill(Palette.accent)
                }
                .shape(.roundedRectangle(24))
                .clipsContent(clips)
                .height(60)

                SwitchRow("Cut what it holds", $clips)
            }
            .spacing(12)
        }
        """#,
        "OwnGates": #"""
        // Sources/Samples/State/GateSample.swift
        /// How many runs began, and how many came to their end.
        struct Tally: Equatable {
            var started = 0
            var finished = 0
        }

        @State private var ignored = Tally()
        @State private var cancelled = Tally()
        @State private var waited = Tally()
        @State private var unheld = Tally()

        var body: some View {
            VStack {
                Text("Press each button three times, quickly.")

                row("Ignore while running", ignored)
                    .onClicked(.ignoreWhileRunning) {
                        ignored.started += 1
                        try await Task.sleep(for: .milliseconds(1500))
                        ignored.finished += 1
                    }

                // The run a press cancels ends at its sleep: what it would write
                // after is never written.
                row("Cancel previous", cancelled)
                    .onClicked(.cancelPrevious) {
                        cancelled.started += 1
                        try await Task.sleep(for: .milliseconds(1500))
                        cancelled.finished += 1
                    }

                row("Wait for previous", waited)
                    .onClicked(.waitForPrevious) {
                        waited.started += 1
                        try await Task.sleep(for: .milliseconds(1500))
                        waited.finished += 1
                    }

                row("Run concurrently", unheld)
                    .onClicked(.runConcurrently) {
                        unheld.started += 1
                        try await Task.sleep(for: .milliseconds(1500))
                        unheld.finished += 1
                    }
            }
        }

        /// One button, and what its runs did so far.
        private func row(_ caption: String, _ tally: Tally) -> Button {
            Button("\(caption) - started \(tally.started), finished \(tally.finished)")
        }
        """#,
        "PacedStateSample": #"""
        // Sources/Samples/State/PacedStateSample.swift
        /// What the host walks. A write puts the DESTINATION on it at once, and
        /// the host walks the control there on its own frames.
        @State private var fade = 1.0

        /// The reading the third column shows: where the value had got to when the
        /// sample was taken. An ordinary state, so an ordinary get reads it.
        @State private var shown = 1.0

        var body: some View {
            // One walked value, shown three ways.
            VStack {
                // A CONVERTER. The words are worked out from the destination as
                // it is written, and the host wears them, so nothing here is
                // described again - this count stands still for the whole walk.
                VStack {
                    DebugInfoLabel()

                    Text($fade.convert { "going to \(Int($0 * 100))%" })
                }

                // THE JOURNEY. This closure reads where the value IS, and the host
                // writes that lane every frame - so it is built again on every one
                // of them, printing a number that moves because the value does.
                VStack {
                    DebugInfoLabel()

                    Text("at \(Int($fade.journey.value * 100))%")
                }

                // A READING, ten times a second, into an ordinary state. Same
                // number, at most ten builds a second.
                VStack {
                    DebugInfoLabel()

                    Text("at \(Int(shown * 100))%")
                }
                .samples($fade, into: $shown, .every(.milliseconds(100)))

                Rectangle()
                    .fill(Palette.accent)
                    .height(60)
                    .opacity($fade)

                HStack {
                    Button("Fade")
                        .onClicked { $fade.journey.move(to: 0.1, .eased(.milliseconds(2000), .cubicOut)) }

                    Button("Back")
                        .onClicked { $fade.journey.move(to: 1, .eased(.milliseconds(2000), .cubicOut)) }
                }
                .horizontalAlignment(.center)
            }
        }
        """#,
        "Palette.sample": #"""
        // Sources/Styles/Palette.swift
        static let accent = Color(light: AppColors.violet, dark: AppColors.violetLight)

        static let onAccent = Color(light: AppColors.white, dark: AppColors.white)

        static let subtle = Color(light: Color(hex: 0x000000, opacity: 0.55), dark: Color(hex: 0xFFFFFF, opacity: 0.55))

        static let disabled = Color(light: Color(hex: 0x000000, opacity: 0.25), dark: Color(hex: 0xFFFFFF, opacity: 0.25))

        static let outline = Color(light: Color(hex: 0x000000, opacity: 0.12), dark: Color(hex: 0xFFFFFF, opacity: 0.12))

        static let danger = Color(light: AppColors.red, dark: AppColors.redLight)

        /// What such an action stands on: its red let faintly through.
        static let dangerWash = Color(light: Color(hex: 0xD92D20, opacity: 0.12), dark: Color(hex: 0xFF8A80, opacity: 0.2))
        """#,
        "PanSample": #"""
        // Sources/Samples/Gestures/PanSample.swift
        /// Where the box was left. Ordinary state, read by the handlers alone: it
        /// changes once per gesture, and no view is built for it.
        @State private var panX = 0.0
        @State private var panY = 0.0

        /// Whether the reading written on every report is a SNAP.
        @State private var snaps = true

        /// What the box does as it is let go: stays, springs home, or glides on
        /// - the last two at the hand's speed.
        @State private var letting = "Stays"
        static let lettings = ["Stays", "Springs home", "Glides on"]

        /// Where the box IS, driven - the host reads the translation off these on
        /// its own frames, so a drag costs the arithmetic and no renders at all.
        @State private var liveX = 0.0
        @State private var liveY = 0.0

        var body: some View {
            VStack {
                // The box is moved by DRIVEN states, so a drag builds nothing: the
                // reading below is a CONVERSION of the same two, and the switch is
                // handed its state - this stands at one build.
                DebugInfoLabel()

                // A fixed box for it to move inside, so the layout does not follow
                // the view about.
                ZStack {
                    Rectangle()
                        .fill(Palette.accent)
                        .width(64)
                        .height(64)
                        .horizontalAlignment(.center)
                        .verticalAlignment(.center)
                        // DRIVEN, both of them: the host reads the translation off
                        // the state every frame, and no report renders anything.
                        .translationX($liveX)
                        .translationY($liveY)
                        .onPanUpdated { update in
                            switch update.phase {
                            case .changed:
                                follow(panX + update.totalX, panY + update.totalY)
                            case .ended where letting == "Springs home":
                                // The hand's speed is the box's as it lets go: it
                                // goes on that way, and the spring brings it home.
                                (panX, panY) = (0, 0)
                                $liveX.journey.velocity = update.velocityX
                                $liveY.journey.velocity = update.velocityY
                                $liveX.journey.move(to: 0, .spring(response: .milliseconds(600), damping: 0.5))
                                $liveY.journey.move(to: 0, .spring(response: .milliseconds(600), damping: 0.5))
                            case .ended where letting == "Glides on":
                                // It glides on from the hand's speed to where that
                                // throw carries it, kept inside the box.
                                let glide = Motion.glide(longest: .milliseconds(900))
                                $liveX.journey.velocity = update.velocityX
                                $liveY.journey.velocity = update.velocityY
                                panX = min(max($liveX.journey.reach(glide), -140), 140)
                                panY = min(max($liveY.journey.reach(glide), -60), 60)
                                $liveX.journey.move(to: panX, glide)
                                $liveY.journey.move(to: panY, glide)
                            case .ended:
                                panX = $liveX.journey.value
                                panY = $liveY.journey.value
                            case .cancelled:
                                follow(panX, panY)
                            case .began:
                                break
                            }
                        }
                }
                .style(.card)
                .stroke(Palette.outline)
                .lineWidth(1)
                .height(200)

                // Two states into one conversion: the host works the words out
                // from where the box HAS GOT TO, on its own frames.
                Text()
                    .text(.multi($liveX.journey, $liveY.journey).convert { x, y in
                        "Moved \(Int(x.value)), \(Int(y.value))"
                    })

                SwitchRow("The drag snaps", $snaps)
                // What the box does as the hand lets it go.
                Picker(Self.lettings, selection: $letting) { $0 }
                    .presentation(.segmented)

                Button("Put it back")
                    .horizontalAlignment(.center)
                    // A SETPOINT, so the box TRAVELS home from wherever it was
                    // left - the same two states, written the other way.
                    .onClicked {
                        panX = 0
                        panY = 0
                        liveX = 0
                        liveY = 0
                    }
            }

        }

        /// The box under the finger.
        ///
        /// A READING WRITTEN ON EVERY REPORT IS A SNAP, and the snap is
        /// `$liveX.journey.snap(to:)` - here, going nowhere, standing still.
        /// Writing `$liveX.journey.value` alone would move the box and leave the
        /// destination where it was, so `Put it back` would have nothing to
        /// change. The state itself is where it is GOING, so writing THAT on every
        /// report starts a fresh little journey the next report interrupts, which
        /// is the lag the switch is here to show.
        private func follow(_ x: Double, _ y: Double) {
            if snaps {
                // HERE, GOING NOWHERE, STANDING STILL - all three, so that
                // `Put it back` has a destination to change.
                $liveX.journey.snap(to: x)
                $liveY.journey.snap(to: y)
            } else {
                liveX = x
                liveY = y
            }
        }
        """#,
        "PersistentStateSample": #"""
        // Sources/Samples/State/PersistentStateSample.swift
        /// How dark the gallery's own demonstration paints - kept as the text it is
        /// spelled with, which is what makes conformance one line.
        enum Shade: String, PersistentValue {
            case quiet
            case bold
        }

        extension PersistentKey where Value == Int {
            /// How many times the user has pressed the button, ever.
            static let visits = PersistentKey("dev.stateui.gallery.visits")
        }

        extension PersistentKey where Value == String {
            /// What the user is called.
            static let who = PersistentKey("dev.stateui.gallery.who")
        }

        extension PersistentKey where Value == Shade {
            /// Whether the panel below paints loudly.
            static let shade = PersistentKey("dev.stateui.gallery.shade")
        }

        @State(persistentKey: .visits) private var visits = 0
        @State(persistentKey: .who) private var who = ""
        @State(persistentKey: .shade) private var shade = Shade.quiet

        var body: some View {
            VStack {
                // Every one of the three kept values is read here, so this is what
                // a write rebuilds - and the reading names which one it was for.
                DebugInfoLabel()

                Text("Pressed \(visits) times, ever")

                HStack {
                    Button("Press")
                        .onClicked { visits += 1 }

                    Button("Start over")
                        .isEnabled(visits != 0)
                        .onClicked { visits = 0 }
                }
                .horizontalAlignment(.center)

                TextField($who)
                    .placeholder("Your name")

                Text(who.isEmpty ? "Welcome back" : "Welcome back, \(who)")

                // A key whose value is an enum - kept as the word it is spelled
                // with, so anything else that opens the store can read it.
                Switch(shade == .bold)
                    .text("Bold shade")
                    .onToggled { on in shade = on ? .bold : .quiet }

                Rectangle()
                    .fill(shade == .bold ? Palette.accent : Palette.well)
                    .height(48)
            }
        }
        """#,
        "PickList": #"""
        // Sources/Samples/Collections/ChoosingItemsSample.swift
        @State private var chosen: Set<Int> = []
        @Aim(ItemsView<Int>.self) private var list

        var body: some View {
            Grid {
                HStack {
                    Button("Top")
                        .onClicked(.cancelPrevious) { try await list.scrollTo(0, anchor: .start) }

                    Button("Row 500")
                        .onClicked(.cancelPrevious) { try await list.scrollTo(500, anchor: .start) }

                    Button("Clear")
                        .isEnabled(!chosen.isEmpty)
                        .onClicked { chosen = [] }
                }
                .horizontalAlignment(.center)
                .gridRow(0)

                // A Set binding: as many chosen as the user likes.
                ItemsView(0..<1_000) { number in
                    Text("Row \(number)")
                }
                .selection($chosen)
                .aim(list)
                .gridRow(1)

                DebugInfoLabel()
                    .gridRow(2)

                Text("\(chosen.count) chosen")
                    .gridRow(2)
            }
            .rows(.auto, .fill, .auto)
        }
        """#,
        "PickerSample": #"""
        // Sources/Samples/BasicInput/PickerSample.swift
        /// The values on offer.
        enum Size: CaseIterable, Equatable {
            case small, medium, large
        }

        /// The value chosen, nil while none is.
        @State private var size: Size? = .medium
        @State private var opened = 0
        @State private var showing = false

        /// The device, by its name: whether its platform opens a list at the program's asking.
        @Environment(\.device) private var device

        var body: some View {
            VStack {
                // The choice and the count are read here, so a pick builds this
                // closure - and a write of OURS raises no event at all.
                DebugInfoLabel()

                Picker(Size.allCases, selection: $size) { "\($0)".titled }
                    .placeholder("Size")
                    // Both ways, so a button elsewhere can open the list and the
                    // user's closing writes it back. The event answers the user
                    // and the platform - never this side's own write.
                    .isOpen($showing)
                    .onOpened { opened += 1 }

                // Only where the platform opens a list at the program's asking.
                if device.honors(PickerContract.isOpen) {
                    Button("Open the list")
                        .onClicked { showing = true }
                        .horizontalAlignment(.center)
                }

                // The same choice, offered as segments and as radio buttons.
                Picker(Size.allCases, selection: $size) { "\($0)".titled }
                    .presentation(.segmented)

                Picker(Size.allCases, selection: $size) { "\($0)".titled }
                    .presentation(.radio)

                Text(size.map { "Chosen: \($0)" } ?? "Nothing chosen")

                Text("Opened \(opened)x")
            }
        }
        """#,
        "PinchSample": #"""
        // Sources/Samples/Gestures/PinchSample.swift
        @State private var pinch = 1.0
        @State private var pinchedFrom = 1.0
        @State private var turn = 0.0
        @State private var turnedFrom = 0.0
        @State private var reports = 0

        var body: some View {
            VStack {
                // The scale, the angle and the report count are read here, so every
                // report the fingers make builds this closure.
                DebugInfoLabel()

                // The recognizer is on the ZStack; the rectangle inside it is what
                // moves. Putting both on one view is what stops a pinch after its
                // first report - see the notes.
                ZStack {
                    Rectangle()
                        .fill(Palette.accent)
                        .width(80)
                        .height(80)
                        .horizontalAlignment(.center)
                        .verticalAlignment(.center)
                        .scale(pinch)
                        .rotation(turn)
                }
                .style(.card)
                .stroke(Palette.outline)
                .lineWidth(1)
                .height(220)
                .onPinchUpdated { update in
                    reports += 1

                    // The spread since the pinch began scales the size it had
                    // then.
                    if update.phase == .began { pinchedFrom = pinch }
                    pinch = max(0.5, min(3, pinchedFrom * update.scale))
                }
                .onRotationUpdated { update in
                    reports += 1

                    // The angle since the fingers began turns the view from where
                    // it stood then.
                    if update.phase == .began { turnedFrom = turn }
                    turn = turnedFrom + update.angle
                }

                // Per cent rather than a formatted double: String(format:) is
                // Foundation, which this sample does not import.
                //
                // The count is here on purpose: a pinch that reports once is a pinch
                // that has been interrupted, and the number says so at a glance.
                Text("Scale \(Int(pinch * 100))%, turned \(Int(turn))° - \(reports) report(s)")

                Button("Back as it was")
                    .horizontalAlignment(.center)
                    .onClicked {
                        pinch = 1
                        turn = 0
                        reports = 0
                    }
            }
        }
        """#,
        "PlatformSupportSample": #"""
        // Sources/Samples/Environment/PlatformSupportSample.swift
        /// The device, by its name: what its platform honors is its host's.
        @Environment(\.device) var device

        var body: some View {
            VStack {
                supported("Opening a picker's list", device.honors(PickerContract.isOpen))
                supported("Hearing a picker's list open", device.honors(PickerContract.opened))
                supported("A tooltip", device.honors(VisualElementContract.tooltip))
                supported("A picture beside a menu's entry", device.honors(MenuItemElementContract.icon))
            }
        }

        /// One member, and whether this platform honors it.
        private func supported(_ words: String, _ honored: Bool) -> some View {
            HStack {
                Text(words)

                Space()

                Text(honored ? "honored" : "not here")
            }
        }
        """#,
        "PointerSample": #"""
        // Sources/Samples/Gestures/PointerSample.swift
        @State private var pointer = Point(x: 0, y: 0)
        @State private var hovering = false
        @State private var pressing = false
        @State private var last = "nothing yet"

        var body: some View {
            ZStack {
                VStack {
                    // Where the pointer is is read here, so every move builds this
                    // closure - which is what a get on a per-report value costs.
                    DebugInfoLabel()

                    Text(hovering
                        ? "at \(Int(pointer.x)), \(Int(pointer.y))"
                        : "move a pointer over this box")

                    // Which of the five arrived last. Pressed and released say
                    // where they happened; entered and exited carry no position at
                    // all, and moved's is the line above.
                    Text("last: \(last)")
                }
            }
            .style(.card)
            // The box reacts, so its look is part of what it says: the outline is
            // the hover, the fill is the button held down.
            .stroke(hovering ? Palette.accent : Palette.outline)
            .lineWidth(hovering ? 2 : 1)
            .onPointerEntered { hovering = true; last = "entered" }
            // The position is in the VIEW's own coordinates, not the window's.
            .onPointerMoved { point in
                pointer = point
                last = "moved"
            }
            .onPointerPressed { point in
                pressing = true
                last = "pressed at \(Int(point.x)), \(Int(point.y))"
            }
            .onPointerReleased { point in
                pressing = false
                last = "released at \(Int(point.x)), \(Int(point.y))"
            }
            // A button held down and taken out of the box can send exited with no
            // release after it, so the fill comes down here too.
            .onPointerExited { hovering = false; pressing = false; last = "exited" }
        }
        """#,
        "PollSample": #"""
        // Sources/Samples/DateTime/PollSample.swift
        /// One tick, then stopped - and the tick starts the next round when its
        /// work is done. So the gap is measured from where the work ENDED, and two
        /// rounds can never overlap however long one takes.
        @State private var poll = Ticker(every: .seconds(2), isRepeating: false)

        @State private var status = "Not started"
        @State private var rounds = 0
        @State private var checking = false

        var body: some View {
            VStack {
                // What the poll last answered is read here, so this closure is
                // built as each check begins and again as it answers.
                DebugInfoLabel()

                Text(status)
                    .fontWeight(.bold)

                Text("\(rounds) round(s)")

                Spinner(checking)
                    .height(28)

                Button(poll.isRunning || checking ? "Stop" : "Start")
                    .horizontalAlignment(.center)
                    .onClicked {
                        if poll.isRunning || checking {
                            poll.stop()
                            checking = false
                            status = "Stopped"
                            return
                        }

                        status = "Waiting"
                        poll.start()
                    }
            }
            .onCreated {
                // Set here rather than in the initializer: the closure reaches this
                // view's @State and the ticker itself, neither of which exists yet
                // while the property that holds the ticker is being initialized.
                poll.onTick = {
                    checking = true
                    status = "Checking"

                    // Work of unknown length, on a task of its own - what a real
                    // check would be. The ticker is already stopped by now, which
                    // is what makes starting it again below the next round rather
                    // than a second one alongside this.
                    let answer = await Task.detached {
                        try? await Task.sleep(for: .milliseconds(1200))
                        return "All good"
                    }.value

                    // Stopped while it checked: the answer comes to nothing.
                    guard checking else { return }

                    rounds += 1
                    checking = false
                    status = "\(answer) - next check in 2s"

                    poll.start()
                }
            }
            // The tick reaches this view's states, the ticker among them, so it holds
            // them: leaving the page is stopping it, a check under way included.
            .onDestroying {
                poll.stop()
                checking = false
            }
        }
        """#,
        "PositionDotsSample": #"""
        // Sources/Samples/Collections/PositionDotsSample.swift
        @State private var step = 0
        @State private var cap = 5.0

        private static let steps = ["Describe", "Diff", "Send", "Render"]

        var body: some View {
            VStack {
                // `step` and `cap` are read here, so each press of Back, Next or
                // the stepper builds this closure once.
                DebugInfoLabel()

                Text(Self.steps[step])
                    .fontWeight(.bold)

                PositionDots()
                    .count(Self.steps.count)
                    .position(step)
                    .dotColor(Palette.outline)
                    .currentDotColor(Palette.accent)
                    .horizontalAlignment(.center)

                PositionDots()
                    .count(Self.steps.count)
                    .position(step)
                    .dotShape(.square)
                    .dotSize(10)
                    .dotColor(Palette.outline)
                    .currentDotColor(Palette.accent)
                    .horizontalAlignment(.center)

                HStack {
                    Button("Back")
                        .isEnabled(step > 0)
                        .onClicked { step -= 1 }

                    Button("Next")
                        .isEnabled(step < Self.steps.count - 1)
                        .onClicked { step += 1 }
                }
                .horizontalAlignment(.center)

                // Twelve items twice, at two caps. `maximumVisible` is a ceiling
                // on the DOTS and not on the items: `count` is twelve in both
                // rows, and the stepper takes the second row's dots away one at a
                // time.
                Text("Twelve items, maximumVisible(12)")
                    .horizontalAlignment(.center)

                PositionDots()
                    .count(12)
                    .position(step)
                    .maximumVisible(12)
                    .dotColor(Palette.outline)
                    .currentDotColor(Palette.accent)
                    .horizontalAlignment(.center)

                Text("The same twelve, maximumVisible(\(Int(cap)))")
                    .horizontalAlignment(.center)

                PositionDots()
                    .count(12)
                    .position(step)
                    .maximumVisible(Int(cap))
                    .dotColor(Palette.outline)
                    .currentDotColor(Palette.accent)
                    .horizontalAlignment(.center)

                Stepper($cap)
                    .minimum(4)
                    .maximum(12)
                    .horizontalAlignment(.center)

                // One item twice. `hidesForSinglePage` is true by default: the
                // left-hand one says so and draws NOTHING at all - a lone dot says
                // nothing about where the user is - and the right-hand one turns
                // it off and draws its dot.
                HStack {
                    VStack {
                        Text("hidesForSinglePage(true)")

                        PositionDots()
                            .count(1)
                            .position(0)
                            .hidesForSinglePage(true)
                            .dotColor(Palette.outline)
                            .currentDotColor(Palette.accent)
                            .horizontalAlignment(.center)
                    }

                    VStack {
                        Text("hidesForSinglePage(false)")

                        PositionDots()
                            .count(1)
                            .position(0)
                            .hidesForSinglePage(false)
                            .dotColor(Palette.outline)
                            .currentDotColor(Palette.accent)
                            .horizontalAlignment(.center)
                    }
                }
                .horizontalAlignment(.center)
            }
        }
        """#,
        "ProgressBarSample": #"""
        // Sources/Samples/BasicInput/ProgressBarSample.swift
        @State private var done = 3.0

        var body: some View {
            VStack {
                // How far along is read here, so every step builds this closure.
                DebugInfoLabel()

                Text("Step \(Int(done)) of \(Int(steps))")

                // A FRACTION, not a count: the division happens here, in Swift,
                // because that is where the numbers are.
                ProgressBar(done / steps)
                    .height(8)

                Stepper($done)
                    .minimum(0)
                    .maximum(steps)
                    .step(1)
                    .horizontalAlignment(.center)

                SectionTitle("The same property, as a modifier")

                // A bar built empty carries no value at all, so `.progress` is
                // how one reaches it. This one shows what is LEFT, so the two
                // move opposite ways.
                ProgressBar()
                    .progress(1 - done / steps)
                    .height(8)

            }
        }

        /// How many steps the imaginary job has.
        private var steps: Double { 5 }
        """#,
        "PropertyReadsSample": #"""
        // Sources/Samples/State/PropertyReadsSample.swift
        /// Two properties of one model, read in two different closures.
        ///
        /// The point of the sample is which closure is built again: each property is
        /// a `@State` of its own, so a write to `visits` reaches the closures that
        /// read `visits` and nobody else.
        @MainActor
        private final class Profile {
            @State var name = ""
            @State var visits = 0
        }

        @State private var profile = Profile()

        var body: some View {
            // THE OUTER CLOSURE READS NEITHER PROPERTY, so no write builds it
            // again and nothing below is carried along. Each block answers for
            // itself.
            VStack {
                VStack {
                    Button("Another visit")
                        .horizontalAlignment(.center)
                        .onClicked { profile.visits += 1 }
                }

                VStack {
                    DebugInfoLabel()

                    Text("visits: \(profile.visits)")
                }

                VStack {
                    TextField(profile.$name)
                        .placeholder("Type a name")
                }

                VStack {
                    DebugInfoLabel()

                    Text("name: \(profile.name.isEmpty ? "-" : profile.name)")
                        .lineBreak(.tailTruncation)
                }
            }
        }
        """#,
        "RatingBar.flash": #"""
        // Sources/Samples/Interop/RatingBar.swift
        /// An act of the bar's contract, aimed at one bar.
        ///
        /// `call` puts the control's identity in argument 0, and the host half turns
        /// it back into the control it made. Two bars on one page each answer to
        /// their own aim.
        extension Aim where Target == RatingBar {
            /// Flashes the bar this aim is on.
            public func flash() async throws {
                try await call(RatingBarContract.flash)
            }
        }
        """#,
        "ReaderSample": #"""
        // Sources/Samples/Fundamentals/ReaderSample.swift
        /// The one value this page is about. Nothing in this view's own braces
        /// reads it: every get is inside a row, so a write builds the closures that
        /// read it and nothing around them.
        @State private var value = 0.3   // the one value

        /// A state no view reads, lent to a child as `$pulses`: written by a
        /// button, followed by the child's engine, and never rendered.
        @State private var pulses = 0   // read by no view, followed by an engine

        var body: some View {
            // This stack reads nothing: each numbered row below is a closure of
            // its own, with its own reading.
            VStack {
                // THE WRITERS. A slider handed $value reads nothing at build; a
                // handler reads when it fires, not at build. Neither is a reader.
                Slider($value)
                    .minimum(0)
                    .maximum(1)

                HStack {
                    button("+10%") { value = min(1, value + 0.1) }
                    button("Pulse") { pulses += 1 }
                }
                .horizontalAlignment(.center)

                // 1. A STATE BY BINDING: the child's engine follows `pulses` through
                //    the binding it was handed. Pulse wakes the engine, which writes
                //    a driven text - no render on either side.
                Pulsed(pulses: $pulses)

                row("2 · a get in this row's braces") {
                    Text("value · \(percent(value))")
                    DebugInfoLabel()   // climbs: "N builds, for value"
                }

                row("3 · a binding alone") {
                    Slider($value)
                        .minimum(0)
                        .maximum(1)
                    DebugInfoLabel()   // stays: "1 build, first time"
                }

                row("4 · a converted text") {
                    Text()
                        .text($value.convert { percent($0) })
                    DebugInfoLabel()
                }

                row("5 · a get in a nested container") {
                    Text("outside the braces: " + BuildCount.of(debugInfo()))
                    ZStack {
                        VStack {
                            Text("inside: \(percent(value))")
                            DebugInfoLabel()
                        }
                    }
                    .style(.card)
                    .stroke(Palette.outline)
                }

                // 6. A CHILD that reads the value it borrowed: the child is the
                //    reader, its count climbs, and this view's does not.
                Reading(value: $value)

                // 7. A CHILD that only hands the binding on: never built again.
                Holding(value: $value)
            }
        }

        /// One row: a caption, then the content in a stack of its own - so the
        /// reading taken inside the content is that stack's and nobody else's,
        /// and the caption around it is never built again.
        private func row<Content: Views>(_ caption: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
            ZStack {
                VStack {
                    Text(caption)

                    VStack(content: content)
                }
            }
            .style(.card)
            .stroke(Palette.outline)
        }

        /// Whole percent, written by hand - a formatter is Foundation.
        private func percent(_ value: Double) -> String {
            "\(Int((value * 100).rounded()))%"
        }

        /// One of the buttons, all of which look the same.
        private func button(_ caption: String, _ act: @escaping @MainActor () throws -> Void) -> Button {
            Button(caption)
                .onClicked(act)
        }

        /// A child that READS the value it borrowed: a reader, built again on every
        /// write, and it says so.
        private struct Reading: View {
            @Binding var value: Double

            var body: some View {
                ZStack {
                    VStack {
                        Text("6 · a child that reads the value it borrowed")
                        Text("value · \(percent(value))")
                        DebugInfoLabel()
                    }
                }
                .style(.card)
                .stroke(Palette.outline)
            }

            private func percent(_ value: Double) -> String {
                "\(Int((value * 100).rounded()))%"
            }
        }

        /// A child that only hands the binding on: no reader, never built again.
        private struct Holding: View {
            @Binding var value: Double

            var body: some View {
                ZStack {
                    VStack {
                        Text("7 · a child that only hands the binding on")
                        Slider($value)
                            .minimum(0)
                            .maximum(1)
                        DebugInfoLabel()
                    }
                }
                .style(.card)
                .stroke(Palette.outline)
            }
        }

        /// A child on the parent's state by BINDING: its engine follows the state it
        /// was handed, and shows what it read as a driven text.
        private struct Pulsed: View {
            @Binding var pulses: Int

            @State private var said = "pulses · 0"

            var body: some View {
                ZStack {
                    VStack {
                        Text("1 · a state by binding")
                        Text()
                            .text($said)
                        DebugInfoLabel()
                    }
                }
                .style(.card)
                .stroke(Palette.outline)
                .engine(following: $pulses) { _ in
                    said = "pulses · \(pulses)"
                }
            }
        }
        """#,
        "RebuildSample": #"""
        // Sources/Samples/Fundamentals/RebuildSample.swift
        @State private var left = 0
        @State private var right = 0

        // Reads nothing - the buttons write in handlers, the panels are handed
        // bindings - so this body is built once.
        var body: some View {
            VStack {
                HStack {
                    Button("Change left")
                        .onClicked { left += 1 }

                    Button("Change right")
                        .onClicked { right += 1 }
                }
                .horizontalAlignment(.center)

                // TWO OF THEM, because the reading is only worth anything against
                // another: one panel answers and the other stands still, and the
                // counts say which.
                RebuildPanel(name: "left", value: $left)

                RebuildPanel(name: "right", value: $right)
            }
        }

        /// One value, and the reading that says why this panel was described.
        private struct RebuildPanel: View {
            let name: String

            @Binding var value: Int

            var body: some View {
                ZStack {
                    VStack {
                        Text("\(name) is \(value)")
                            .fontWeight(.bold)

                        // WHY THIS VIEW IS BEING DESCRIBED, on the screen it is
                        // about: the view's name, how many times, and the state
                        // this one is for.
                        Text(debugInfo())

                        RebuildPassenger()
                    }
                }
                .style(.card)
                .stroke(Palette.outline)
                .lineWidth(1)
            }
        }

        /// A view that reads nothing and is built with nothing, so every rebuild of the
        /// panel above it carries it: its reading stays at the first build.
        private struct RebuildPassenger: View {
            var body: some View {
                Text(debugInfo())
            }
        }
        """#,
        "RefreshingList": #"""
        // Sources/Samples/Collections/RefreshSample.swift
        @State private var items = ["Weekly notes", "Old news"]
        @State private var refreshing = false
        @State private var fetched = 0

        var body: some View {
            Grid {
                HStack {
                    // Where the platform has no pull, a command refreshes - its spinner showing where it has one.
                    Button("Refresh")
                        .isEnabled(!refreshing)
                        .onClicked(.ignoreWhileRunning) { try await fetch() }

                    Button("Clear")
                        .onClicked { items = [] }

                    Text(refreshing ? "Refreshing" : items.count == 1 ? "1 item" : "\(items.count) items")
                        .verticalAlignment(.center)
                }
                .gridRow(0)

                ItemsView(items, id: \.self) { item in
                    Text(item)
                }
                // An empty list keeps its pull.
                .emptyView(Text("Nothing yet").textColor(Palette.subtle))
                .isRefreshing($refreshing)
                .onRefreshRequested(.ignoreWhileRunning) { try await fetch() }
                .gridRow(1)
            }
            .rows(.auto, .fill)
        }

        /// Fetches what is new, the spinner showing until it is in.
        private func fetch() async throws {
            refreshing = true
            defer { refreshing = false }
            try await Task.sleep(for: .milliseconds(900))
            fetched += 1
            items.insert("Fresh \(fetched)", at: 0)
        }
        """#,
        "RemovingRowSample": #"""
        // Sources/Samples/Layout/RemovingRowSample.swift
        /// The rows, and which of them have gone.
        static let rows = ["Milk", "Bread", "Coffee", "Apples", "Butter", "Rice"]

        @State private var gone: Set<String> = []
        @State private var atOnce: Set<String> = []
        @State private var slow = true

        var body: some View {
            // A PLAIN VStack. Nothing here ASKS for animation: the row is HIDDEN,
            // which fades it where it stands, and the rows under it are then given
            // new places - which is somewhere they travel to. The one line about
            // motion is the switch turning it OFF.
            VStack {
                VStack {
                    // INSIDE the stack's own braces, because that is where `gone`
                    // and `atOnce` are read: deleting a row builds this closure,
                    // and a reading taken outside it would be about a stack the
                    // delete never rebuilds.
                    DebugInfoLabel()

                    ForEach(Self.rows, id: \.self) { row in
                        Grid {
                            Text(row)
                                .verticalAlignment(.center)
                                .gridColumn(0)

                            Button("Delete")
                                .gridColumn(1)
                                .onClicked { remove(row) }
                        }
                        .columns(.fill, .auto)
                        .height(46)
                        .isVisible(!gone.contains(row) && !atOnce.contains(row))
                        // The other half of the sample: a row told to travel at no
                        // motion goes at once, and the stack still closes over it.
                        .motion(atOnce.contains(row) ? .none : .inherited)
                    }
                }

                SwitchRow("The row fades first", $slow)

                Button("Bring them back").onClicked {
                    gone.removeAll()
                    atOnce.removeAll()
                }
            }
        }

        /// Takes a row away - fading it where it stands, or at once.
        private func remove(_ row: String) {
            if slow {
                gone.insert(row)
            } else {
                atOnce.insert(row)
            }
        }
        """#,
        "RestStrips": #"""
        // Sources/Samples/Layout/ScrollViewSample.swift
        /// A strip of tiles a fixed distance apart - the shape both strips of the rest
        /// example are cut from. A tile is 140 wide with 20 between them, so one
        /// starts every 160, which is the interval the first strip is brought to rest on.
        @MainActor
        private func tileStrip() -> ScrollView {
            ScrollView {
                HStack {
                    ForEach(1...40) { tile in
                        Text("Tile \(tile)")
                            .verticalAlignment(.center)
                            .width(140)
                            .height(100)
                    }
                }
            }
            .orientation(.horizontal)
            .horizontalScrollIndicator(.never)
        }

        @State private var offset = Point.zero

        @State private var rested = 1

        var body: some View {
            Grid {
                tileStrip()
                    .scrollOffset($offset)
                    // Once a movement has ended - a drag let go of, a throw that
                    // ran out - a write carries the strip on to the tile it is
                    // nearest.
                    .onScrollStopped {
                        let tile = max(($offset.journey.value.x / 160).rounded(), 0)
                        rested = Int(tile) + 1
                        offset = Point(tile * 160, 0)
                    }
                    .gridRow(0)

                Text("at rest on tile \(rested)")
                    .gridRow(1)

                Text("`.onScrollStopped` + a write to `.scrollOffset`")
                    .gridRow(2)

                // The same strip with nothing said about where it rests, so the
                // difference on screen is the handler and nothing else.
                tileStrip()
                    .gridRow(3)

                Text("the platform's own rest")
                    .gridRow(4)
            }
            .rows(.auto, .auto, .auto, .auto, .auto)
            // The bands are as tall as they need to be, so the pair sits in the
            // middle of whatever height the window gave the cell.
            .verticalAlignment(.center)
        }
        """#,
        "SafeAreaSample": #"""
        // Sources/Samples/Layout/SafeAreaSample.swift
        @State private var presented = false
        @State private var under = true
        @State private var path: [Int] = []

        var body: some View {
            Button("Open a page")
                .onClicked { presented = true }
                .sheet(isPresented: $presented) {
                    NavigationStack($path) {
                        Grid {
                            ScrollView {
                                VStack {
                                    Switch($under).text("Under the bars")
                                    ForEach(Array(1...40), id: \.self) { row in
                                        Text("Row \(row)")
                                    }
                                }
                            }
                        }
                        .ignoresSafeArea(under ? .all : .none)
                        .galleryPage("Safe area")
                    } destination: { _ in
                        Text("")
                    }
                }
        }
        """#,
        "SameInputsSample": #"""
        // Sources/Samples/Fundamentals/SameInputsSample.swift
        @State private var counter = 0
        @State private var items = ["Alpha", "Beta", "Gamma"]

        var body: some View {
            VStack {
                // This closure reads the count, so a press builds it again - and
                // constructs every view below afresh. Which of them is BUILT is
                // each view's own question.
                DebugInfoLabel()

                Button("Count \(counter)")
                    .horizontalAlignment(.center)
                    .onClicked { counter += 1 }

                // CARRIED: built with a constant, reading nothing.
                Block(caption: "a constant", value: "fixed", tint: Palette.accent)

                // BUILT AGAIN: the count is what it was built with.
                Block(caption: "the count", value: "\(counter)", tint: Palette.brand)

                // BUILT AGAIN TOO, for the other reason: lent the same state every
                // time, and reading it.
                Reads(count: $counter, tint: Palette.brand)

                Text("Rows built with their item")

                VStack {
                    // AND ROWS: each depends on its item and nothing else, so the
                    // button builds none of them.
                    ForEach(items) { item in
                        Row(item: item)
                            .id(item)
                    }
                }
            }
        }

        /// One block: the caption, and the value it was built with. It reads nothing,
        /// so what it is built with alone decides whether it is built again.
        private struct Block: View {
            let caption: String
            let value: String
            let tint: Color

            var body: some View {
                VStack {
                    Text("Built with \(caption)")
                        .fontWeight(.bold)

                    Text(value)
                        .fontWeight(.bold)

                    DebugInfoLabel()
                }
            }
        }

        /// A block lent the count, and reading it.
        private struct Reads: View {
            @Binding var count: Int
            let tint: Color

            var body: some View {
                VStack {
                    Text("Reads the count")
                        .fontWeight(.bold)

                    Text("\(count)")
                        .fontWeight(.bold)

                    DebugInfoLabel()
                }
            }
        }

        /// One row, built with its item and nothing else.
        private struct Row: View {
            let item: String

            var body: some View {
                VStack {
                    Text(item)

                    DebugInfoLabel()
                }
            }
        }
        """#,
        "SaveAndDelete": #"""
        // Sources/Samples/State/GateSample.swift
        /// One gate for both of the document's actions.
        @State private var document = Gate(.ignoreWhileRunning)
        @State private var said = "Saved nothing yet."

        var body: some View {
            VStack {
                Text("Press Save, and watch Delete dim while it saves.")

                HStack {
                    Button("Save")
                        .isEnabled(!document.isBusy)
                        .onClicked(gate: document) {
                            said = "Saving…"
                            try await Task.sleep(for: .milliseconds(1500))
                            said = "Saved."
                        }

                    Button("Delete")
                        .isEnabled(!document.isBusy)
                        .onClicked(gate: document) {
                            said = "Deleting…"
                            try await Task.sleep(for: .milliseconds(1500))
                            said = "Deleted."
                        }
                }

                HStack {
                    if document.isBusy {
                        Spinner(true)
                    }
                    Text(said)
                }
            }
        }
        """#,
        "ScenesSample": #"""
        // Sources/Samples/Windows/ScenesSample.swift
        /// The application as it runs - which opens a window in the scene declaring it.
        @Environment(\.application) private var application

        /// What the last button answered.
        @State private var said = "Nothing asked yet."

        var body: some View {
            VStack {
                Button("New scratchpad")
                    .horizontalAlignment(.center)
                    .onClicked(.ignoreWhileRunning) { await open(.scratchpad, "New scratchpad") }

                Button("About")
                    .horizontalAlignment(.center)
                    .onClicked(.ignoreWhileRunning) { await open(.about, "About") }

                VStack {
                    DebugInfoLabel()

                    Text(said)

                    Text("Scenes open: \(application.scenes.count)")
                }
            }
        }

        /// Opens a window of the kind `type` names, in the scene declaring it, and says what came of it.
        private func open(_ type: WindowType<Void>, _ caption: String) async {
            do {
                try await application.openWindow(type)
                said = "\(caption): opened."
            } catch WindowError.alreadyOpen {
                said = "\(caption): WindowError.alreadyOpen - it is open already."
            } catch {
                said = "\(caption): \(error)"
            }
        }
        """#,
        "ScratchpadPage": #"""
        // Sources/Samples/Windows/ScratchpadPage.swift
        /// A scratchpad window's page: the scratchpads' one text, kept with their scene, and a way to close the window - or
        /// every scratchpad window at once.
        struct ScratchpadPage: View {
            /// The text, the scene's: every scratchpad window shows and writes it.
            @State(sceneKey: .scratch) private var text = ""

            /// The scratchpads - the scene the page is in, closed whole from here.
            @Environment(\.scene) private var scene

            /// The application as it runs - how many scenes stand.
            @Environment(\.application) private var application

            /// The window this is the page of - what it is called, how big, and closed from here.
            @Environment(\.window) private var window

            var body: some View {
                VStack {
                    Text("Write anything: every scratchpad window shows this one text, and keeps it.")

                    TextEditor($text)
                        .height(180)

                    Text("Scratchpad windows: \(scene.windows.count) · scenes open: \(application.scenes.count)")

                    HStack {
                        Button("Close this window")
                            .onClicked(.ignoreWhileRunning) { try await window.close() }

                        Button("Close every scratchpad")
                            .onClicked(.ignoreWhileRunning) { try await scene.close() }
                    }
                    .horizontalAlignment(.end)
                }
                .onCreated {
                    window.title = "Scratchpad"
                    window.width = 420
                    window.height = 340
                    window.minimumWidth = 320
                    window.minimumHeight = 280
                }
            }
        }
        """#,
        "ScratchpadScene": #"""
        // Sources/Samples/Windows/ScratchpadScene.swift
        extension WindowType where Value == Void {
            /// A scratchpad window: as many as the user opens.
            static let scratchpad = WindowType("gallery.scratchpad")
        }

        /// What the scratchpads KEEP - handed back with their scene when the system restores the application's windows.
        extension SceneKey where Value == String {
            /// The scratchpads' text.
            static let scratch = SceneKey("gallery.scratch")
        }

        /// The scratchpads: a scene of their own beside the galleries, its windows as many as
        /// `application.openWindow(.scratchpad)` opens - each showing the scene's one text. See `ScenesSample`.
        struct ScratchpadScene: Scene {
            var body: some Scene {
                WindowGroup(.scratchpad) { ScratchpadPage() }
            }
        }
        """#,
        "SearchFieldSample": #"""
        // Sources/Samples/Text/SearchFieldSample.swift
        @State private var query = ""
        @State private var searched = ""

        var body: some View {
            VStack {
                // The list below is filtered from `query`, so every keystroke builds
                // this closure; the field itself is handed the state.
                DebugInfoLabel()

                // Every keystroke lands on `query`; `.onSubmitted` hears the
                // keyboard's search key.
                SearchField($query)
                    .placeholder("Search the list")
                    .onSubmitted { searched = query }

                VStack {
                    ForEach(matches) { item in
                        Text(item)
                            .id(item)
                    }
                }

                Text(searched.isEmpty
                    ? "Type to narrow the list, then press the keyboard's search key."
                    : "Searched for: \(searched)")
            }
        }

        /// What the query matches, or everything when there is no query - a search
        /// box that hides the list until something is typed says nothing about the
        /// list.
        private var matches: [String] {
            let items = ["Alpha", "Alma", "Beta", "Gamma", "Delta"]

            return query.isEmpty
                ? items
                : items.filter { $0.lowercased().hasPrefix(query.lowercased()) }
        }
        """#,
        "SearchSample": #"""
        // Sources/Samples/Navigation/SearchSample.swift
        @Environment(\.window) private var window
        /// Where the gallery is: choosing a suggestion pushes a page.
        let nav: Navigation

        /// What there is to search. A constant: the sample is about the box, and
        /// nothing here edits the list.
        private let items = ["Alpha", "Beta", "Gamma", "Delta"]

        @State private var query = ""

        var body: some View {
            VStack {
                // The query and the matches are read here, so every keystroke
                // in the bar builds this closure.
                DebugInfoLabel()

                Text("Type in the box on the navigation bar; these rows follow it.")

                VStack {
                    ForEach(matches, id: \.self) { item in
                        // A row that opens a page: the chosen item rides as a VALUE
                        // of the route - `.item("Alpha")`.
                        MenuRow(item) { nav.push(.item(item)) }
                    }
                }

                Text(matches.isEmpty
                    ? "Nothing matches \"\(query)\""
                    : "\(matches.count) of \(items.count) shown")

                Button("Clear the box")
                    .isEnabled(!query.isEmpty)
                    .horizontalAlignment(.center)
                    .onClicked { query = "" }
            }
            // The box goes in the page's title slot. It is an ordinary view in the
            // tree, handed the same `@State` the content reads.
            .titleView {
                SearchField($query)
                    .placeholder("Search the list")
                    .placeholderColor(Palette.subtle)
                    .verticalAlignment(.center)
            }
        }

        /// What the query matches - everything when there is no query: these rows
        /// are the page's content, and an empty page under an empty box would read
        /// as a mistake.
        ///
        /// `hasPrefix` rather than `contains`, which is a choice about the RESULT
        /// and not about what compiles: matching from the start makes a short list
        /// of names narrow predictably as the user types, where a substring
        /// match keeps rows whose beginning bears no relation to the query.
        private var matches: [String] {
            query.isEmpty
                ? items
                : items.filter { $0.lowercased().hasPrefix(query.lowercased()) }
        }
        """#,
        "SelectableTextSample": #"""
        // Sources/Samples/Text/SelectableTextSample.swift
        /// Whether the address and the code can be selected, as the switch says.
        @State private var selectable = true

        var body: some View {
            VStack {
                Text("221B Baker Street, London NW1 6XE")
                    .textStyle(.headline)
                    .isSelectable(selectable)

                Text("Order 7F3K-92QX-L0MA")
                    .isSelectable(selectable)

                Text("A caption the user only reads.")
                    .textStyle(.caption)

                Switch($selectable)
                    .text("Selectable")
            }
        }
        """#,
        "SemanticsSample": #"""
        // Sources/Samples/BasicInput/SemanticsSample.swift
        @Environment(\.application) private var application
        @State private var described = true

        @State private var taps = 0

        @State private var rating = 3

        /// The last thing said out loud, shown - because a machine with no screen
        /// reader running shows nothing at all otherwise, and what was said is the
        /// whole point of the button.
        @State private var said = ""

        /// Said once, and both written onto the button and printed under it - so
        /// what the sample shows cannot drift from what the platform was handed.
        private static let says = "Add to favorites"

        private static let hint = "Puts this item on your list"

        var body: some View {
            // What a user is told is read here, so throwing the switch builds
            // this closure again.
            VStack {
                DebugInfoLabel()

                HStack {
                    VStack {
                        // A picture and no words. To anybody not looking at it,
                        // this control has no name at all.
                        Button()
                            .icon(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                            .style(.iconButton)
                            .contentMode(.fit)
                            .width(64)
                            .height(64)
                            .stroke(Palette.outline)
                            .lineWidth(1)
                            .onClicked { taps += 1 }

                        Text("A user hears")

                        Text("nothing")
                    }
                    .width(150)

                    VStack {
                        // The same button, saying what it is and what using it does.
                        // One value, not two branches of an `if`, so throwing the
                        // switch CLEARS the property off the same control instead of
                        // building a different one.
                        describedButton

                        Text("A user hears")

                        Text(described ? "\(Self.says)\n\(Self.hint)" : "nothing")
                    }
                    .width(150)
                }
                .horizontalAlignment(.center)

                Text("Tapped \(taps) time\(taps == 1 ? "" : "s")")

                SwitchRow("Describe the second button", $described)
                    .horizontalAlignment(.center)

                SectionTitle("A heading is what this says it is")

                // Drawn alike and read differently: only the second is somewhere a
                // user jumping through the page can land.
                VStack {
                    Text("Drawn large")
                        .fontWeight(.bold)

                    // Read as a heading: somewhere a user jumping through the page
                    // can land.
                    Text("A heading, and drawn the same")
                        .fontWeight(.bold)
                        .accessibilityHeading(.h1)
                }

                SectionTitle("One thing made of parts")

                // Five stars drawn, one rating heard: a screen reader meets the row
                // as one adjustable thing holding its value, not as five pictures,
                // steps it with a swipe up or down, and offers Clear as an action.
                HStack {
                    ForEach(1...5) { star in
                        Text(star <= rating ? "★" : "☆")
                            .onTapped { rating = star }
                    }
                }
                .horizontalAlignment(.center)
                .accessibilityRole(.adjustable)
                .accessibilityValue("\(rating) of 5")
                .onAccessibilityAdjusted { step in
                    rating = min(5, max(0, rating + (step == .increment ? 1 : -1)))
                }
                .accessibilityAction("Clear") { rating = 0 }

                Text("A user hears: Rating, \(rating) of 5")

                SectionTitle("Said out loud")

                // Said out loud, now, whatever the user was on. An ACT, because
                // it is something that happens at a moment rather than a value a
                // view can hold.
                Button("Announce the count")
                    .horizontalAlignment(.center)
                    .onClicked(.ignoreWhileRunning) {
                        let words = "Tapped \(taps) time\(taps == 1 ? "" : "s")"
                        try await application.announce(words)
                        said = words
                    }

                // Shown as well as said: with no screen reader running there is
                // nothing to see otherwise, and what was said is the point.
                Text(said.isEmpty ? "nothing said yet" : "said: \(said)")

                SectionTitle("What a user walks past")

                HStack {
                    // One word takes the panel AND everything in it out of what a
                    // screen reader walks; the rule below is a single view taken out.
                    ZStack {
                        VStack {
                            Text("Walked")
                                .fontWeight(.bold)

                            Text("Both lines are read")
                        }
                    }
                    .style(.card)

                    // The whole panel, and everything in it, is not there at all
                    // to a screen reader - one word instead of one per view.
                    ZStack {
                        VStack {
                            Text("Skipped")
                                .fontWeight(.bold)

                            Text("Neither line is read")
                        }
                    }
                    .style(.card)
                    .hidesChildrenFromAccessibility(true)
                }
                .horizontalAlignment(.center)

                // A rule is decoration: a stop that would waste the user's time.
                Fill(Palette.outline)
                    .height(1)
                    .isAccessibilityHidden(true)
            }
        }

        /// The described button, built as a VALUE so that turning the switch off
        /// takes the property off THIS control rather than describing another one.
        /// An absent property restores the host's native default, which is what
        /// makes a modifier written under a condition cost the property and not
        /// the control.
        private var describedButton: some View {
            let button = Button()
                .icon(ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"))
                .style(.iconButton)
                .contentMode(.fit)
                .width(64)
                .height(64)
                .stroke(Palette.outline)
                .lineWidth(1)
                .onClicked { taps += 1 }

            return described
                ? button.accessibilityLabel(Self.says).accessibilityHint(Self.hint)
                : button
        }
        """#,
        "ShapesSample": #"""
        // Sources/Samples/Shapes/ShapesSample.swift
        @State private var evenOdd = true

        /// A pentagram: five points, each joined to the one two along, so the
        /// outline crosses itself - which is the whole point of a fill rule.
        private static let star = [
            Point(28, 0), Point(44.5, 50.6), Point(1.4, 19.3),
            Point(54.6, 19.3), Point(11.5, 50.6),
        ]

        var body: some View {
            VStack {
                // The fill rule is read here, so switching it builds this closure.
                DebugInfoLabel()

                SectionTitle("Filled")

                HStack {
                    Rectangle()
                        .fill(Palette.accent)
                        .width(56)
                        .height(56)

                    Rectangle()
                        .fill(Palette.accent)
                        .cornerRadius(14)
                        .width(56)
                        .height(56)

                    Rectangle()
                        .fill(Palette.accent)
                        .cornerRadius(topLeft: 22, topRight: 4, bottomLeft: 4, bottomRight: 22)
                        .width(56)
                        .height(56)

                    Ellipse()
                        .fill(Palette.accent)
                        .width(56)
                        .height(56)
                }
                .spacing(12)
                .horizontalAlignment(.center)

                // A capsule's ends stay round at every size: wide, tall, or square.
                HStack {
                    Capsule()
                        .fill(Palette.accent)
                        .width(120)
                        .height(40)

                    Capsule()
                        .fill(Palette.accent)
                        .width(40)
                        .height(80)
                }
                .spacing(12)
                .horizontalAlignment(.center)

                SectionTitle("Stroked")

                // Two rows of three: six shapes side by side stand wider than a phone.
                VStack {
                    HStack {
                        Line()
                            .x1(0).y1(0)
                            .x2(56).y2(56)
                            .stroke(Palette.accent)
                            .lineWidth(4)
                            .lineCap(.round)
                            .width(56)
                            .height(56)

                        Line()
                            .x1(0).y1(28)
                            .x2(56).y2(28)
                            .stroke(Palette.accent)
                            .lineWidth(4)
                            .dash([3, 2])
                            .width(56)
                            .height(56)

                        Polyline([Point(0, 44), Point(14, 12), Point(30, 34), Point(56, 4)])
                            .stroke(Palette.accent)
                            .lineWidth(4)
                            .lineJoin(.round)
                            .width(56)
                            .height(56)
                    }
                    .spacing(28)

                    HStack {
                        // The one shape that is whatever you can write down: SVG path
                        // syntax, normalized by StateUI for every native host.
                        Path("M 28,0 L 56,56 L 0,56 Z")
                            .fill(Palette.accent)
                            .width(56)
                            .height(56)

                        // A transform on the GEOMETRY - the same ViewTransform
                        // every view takes, drawn whole: a lean draws here, and the
                        // stroke follows the shape it makes. On any shape, not only
                        // a Path. Narrowed first, the lean stays inside its room.
                        Path("M 28,0 L 56,56 L 0,56 Z")
                            .fill(Palette.accent)
                            .geometryTransform(.scaleX(0.6).skew(20, 0))
                            .width(56)
                            .height(56)

                        Rectangle()
                            .fill(Palette.accent)
                            .cornerRadius(14)
                            .geometryTransform(.scaleX(0.6).skew(20, 0))
                            .width(56)
                            .height(56)
                    }
                    .spacing(28)
                }
                .spacing(16)
                .horizontalAlignment(.center)

                SectionTitle("Where the dashes start")

                // The same dashes twice, half a pattern apart: the offset, like
                // the pattern itself, is counted in stroke widths.
                VStack {
                    Line()
                        .x1(0).y1(4)
                        .x2(200).y2(4)
                        .stroke(Palette.accent)
                        .lineWidth(4)
                        .dash([3, 2])
                        .dashPhase(0)
                        .width(200)
                        .height(8)

                    Line()
                        .x1(0).y1(4)
                        .x2(200).y2(4)
                        .stroke(Palette.accent)
                        .lineWidth(4)
                        .dash([3, 2])
                        .dashPhase(2.5)
                        .width(200)
                        .height(8)
                }
                .spacing(10)
                .horizontalAlignment(.center)

                SectionTitle("How far a sharp corner reaches")

                // The same sharp corner twice. A miter join carries the two outer
                // edges on until they cross, and the limit is how long that join
                // may be, in stroke widths; past it the point is cut flat.
                HStack {
                    Polyline([Point(10, 4), Point(28, 48), Point(46, 4)])
                        .stroke(Palette.accent)
                        .lineWidth(8)
                        .lineJoin(.miter)
                        .miterLimit(10)
                        .width(56)
                        .height(72)

                    Polyline([Point(10, 4), Point(28, 48), Point(46, 4)])
                        .stroke(Palette.accent)
                        .lineWidth(8)
                        .lineJoin(.miter)
                        .miterLimit(1)
                        .width(56)
                        .height(72)
                }
                .spacing(12)
                .horizontalAlignment(.center)

                SectionTitle("An outline that crosses itself")

                Polygon(Self.star)
                    .fill(Palette.accent)
                    .fillRule(evenOdd ? .evenOdd : .nonzero)
                    .width(56)
                    .height(56)
                    .horizontalAlignment(.center)

                SwitchRow("Even-odd fill", $evenOdd)
                    .horizontalAlignment(.center)

                SectionTitle("Made of a material")

                // Over stripes, so what each figure lets through shows.
                ZStack {
                    HStack {
                        Space()
                            .background(.tomato)
                        Space()
                            .background(.gold)
                        Space()
                            .background(.steelBlue)
                        Space()
                            .background(Palette.accent)
                    }

                    HStack {
                        Capsule()
                            .fill(.blur(.regular))
                            .width(120)
                            .height(48)

                        Ellipse()
                            .fill(.glass(.clear))
                            .stroke(.white)
                            .width(64)
                            .height(64)

                        Polygon(Self.star)
                            .fill(.blur(.thin))
                            .fillRule(evenOdd ? .evenOdd : .nonzero)
                            .stroke(.white)
                            .width(64)
                            .height(64)
                    }
                    .spacing(16)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
                }
                .height(100)
                .shape(.roundedRectangle(14))
                .clipsContent(true)
            }
            .spacing(12)
        }
        """#,
        "ShareSample": #"""
        // Sources/Samples/Navigation/ShareSample.swift
        @Environment(\.window) private var window
        @State private var words = "The language I mentioned"
        @State private var link = "https://www.swift.org"
        @State private var answer = "nothing shared yet"

        var body: some View {
            VStack {
                TextField($words)
                TextField($link)

                // False is a cancel; a platform with no share sheet throws why.
                Button("Share")
                    .onClicked(.ignoreWhileRunning) {
                        do {
                            let shared = try await window.share(text: words, link: link)
                            answer = shared ? "shared" : "cancelled"
                        } catch {
                            answer = "\(error)"
                        }
                    }

                Text(answer)
            }
        }
        """#,
        "ShortcutSample": #"""
        // Sources/Samples/BasicInput/ShortcutSample.swift
        @State private var saved = 0
        @State private var last = "nothing yet"
        @State private var note = ""

        var body: some View {
            VStack {
                Text("Press Command or Control with S, with Shift and S, with Shift and E, then 1 or 2 alone.")

                HStack {
                    // Command on Apple's platforms, Control elsewhere.
                    Button("Save")
                        .keyboardShortcut("s")
                        .onClicked { pressed("Save") }

                    Button("Save As")
                        .keyboardShortcut("s", modifiers: [.primary, .shift])
                        .onClicked { pressed("Save As") }

                    // A key alone is a shortcut too.
                    Button("First")
                        .keyboardShortcut("1", modifiers: [])
                        .onClicked { pressed("First") }
                }

                // While this field is typed into, 1 and 2 write themselves.
                TextField($note)
                    .placeholder("Type here")

                Text("Pressed \(saved) time\(saved == 1 ? "" : "s"), last: \(last)")
                    // A context menu shows the shortcut; the menu bar's entry acts on it.
                    .contextMenu {
                        MenuItem("Export…")
                            .keyboardShortcut("e", modifiers: [.primary, .shift])
                            .onClicked { pressed("Export from the context menu") }
                    }
            }
            .menuBar {
                Menu("File") {
                    MenuItem("Export…")
                        .keyboardShortcut("e", modifiers: [.primary, .shift])
                        .onClicked { pressed("Export") }
                }
                .id(StandardMenu.file)
            }
            .toolbar {
                ToolbarButton("Mark")
                    .keyboardShortcut("2", modifiers: [])
                    .onClicked { pressed("Mark") }
            }
        }

        private func pressed(_ name: String) {
            saved += 1
            last = name
        }
        """#,
        "SizingSample": #"""
        // Sources/Samples/Layout/SizingSample.swift
        var body: some View {
            VStack {
                row("width(120)",
                    // A request, not an instruction: the layout has the last word.
                    Rectangle()
                        .fill(Palette.accent)
                        .width(120)
                        .height(24))

                row("maximumWidth(200)",
                    Rectangle()
                        .fill(Palette.accent)
                        .height(24)
                        .maximumWidth(200))

                row("minimumWidth(160)",
                    Rectangle()
                        .fill(Palette.accent)
                        .height(24)
                        .minimumWidth(160))

                // The pair is the point: both ask for 80 high, and only the one
                // without a ceiling on it is allowed to have it.
                row("height(80), then the same with maximumHeight(32)",
                    HStack {
                        Rectangle()
                            .fill(Palette.outline)
                            .width(60)
                            .height(80)
                            .verticalAlignment(.start)

                        Rectangle()
                            .fill(Palette.accent)
                            .width(60)
                            .height(80)
                            .maximumHeight(32)
                            .verticalAlignment(.start)
                    })

                // A child drawn past the layout's edge, cut off at it.
                row("clipsContent(true)",
                    VStack {
                        Rectangle()
                            .fill(Palette.accent)
                            .height(24)
                            .translationX(60)
                    }
                    .clipsContent(true)
                    .width(120))

                row("clipsContent(false)",
                    VStack {
                        Rectangle()
                            .fill(Palette.accent)
                            .height(24)
                            .translationX(60)
                    }
                    .clipsContent(false)
                    .width(120))
            }
        }

        /// One example with the modifier that made it, so the column reads as a
        /// list of named cases.
        private func row<Shown: View>(_ caption: String, _ view: Shown) -> some View {
            VStack {
                Text(caption)

                view
            }
        }
        """#,
        "SliderSample": #"""
        // Sources/Samples/BasicInput/SliderSample.swift
        @State private var volume = 40.0
        @State private var soundOn = true
        @State private var dragging = false

        var body: some View {
            VStack {
                // The volume is READ here, so EVERY report the thumb makes builds
                // this closure - which is what a get on a dragged value costs.
                DebugInfoLabel()

                Text(soundOn ? "Volume: \(Int(volume))" : "Muted")

                Slider($volume)
                    .minimum(0)
                    .maximum(100)
                    .isEnabled(soundOn)
                    .onPressed { dragging = true }
                    .onReleased { dragging = false }

                Text(dragging ? "Dragging..." : "At rest")

                Switch($soundOn)
                    .text("Sound")
                    .horizontalAlignment(.center)
            }
        }
        """#,
        "SpinnerSample": #"""
        // Sources/Samples/BasicInput/SpinnerSample.swift
        @State private var loading = true

        var body: some View {
            VStack {
                // The flag is read here, so starting and stopping builds this
                // closure - the spinner itself costs nothing to keep running.
                DebugInfoLabel()

                Spinner(loading)
                    .height(48)

                Switch($loading)
                    .text("Working")
                    .horizontalAlignment(.center)

            }
        }
        """#,
        "SplitViewSample": #"""
        // Sources/Samples/Navigation/SplitViewSample.swift
        /// Where the gallery is: this sample opens and closes the menu, and sends
        /// the user to the section the menu does not always list.
        let nav: Navigation

        var body: some View {
            VStack {
                Text("Open the menu - every row in it a view - and narrow the window to lay it over the page.")

                SwitchRow("Menu open", nav.$menuOpen)
                    .horizontalAlignment(.center)

                SwitchRow("Menu button", nav.$showsMenuButton)
                    .horizontalAlignment(.center)

                // Where the platform places the menu for the room, as the split
                // view writes it.
                Text(nav.menuOverlays ? "The menu lies over the page" : "The menu stands beside the page")
                    .horizontalAlignment(.center)

                HStack {
                    Switch(nav.$listsHiddenRow)

                    Text(nav.listsHiddenRow
                        ? "The menu lists \"Not in the list\""
                        : "The menu does not list it")
                        .verticalAlignment(.center)
                }

                Button("Go there anyway")
                    .horizontalAlignment(.center)
                    .onClicked { nav.open(.hidden) }
            }
        }
        """#,
        "StackInASheet": #"""
        // Sources/Samples/Navigation/SheetsSample.swift
        @State private var presented = false
        @State private var said = "Nothing done yet."

        var body: some View {
            VStack {
                Text("Present the sheet, press its actions and push a page.")

                Button("Present the stack")
                    .horizontalAlignment(.center)
                    .onClicked { presented = true }
                    .sheet(isPresented: $presented) {
                        DraftSheet(said: $said)
                    }

                Text(said)
            }
        }

        /// A draft's stack in a sheet: the bar's actions are its pages', and Help is
        /// the stack's own, on every page it shows.
        private struct DraftSheet: View {
            @Binding var said: String
            @State private var path: [Int] = []
            @State private var pinned = false

            var body: some View {
                NavigationStack($path) {
                    VStack {
                        Text(said)
                        Text(pinned ? "Pinned" : "Not pinned")
                        Button("Push a page")
                            .onClicked { path.append(path.count + 1) }
                    }
                    .galleryPage("Draft")
                    .toolbar {
                        ToolbarButton("Undo")
                            .id("sheet.undo")
                            .placement(at: .start)
                            .onClicked { said = "Undone." }

                        ToolbarGroup {
                            ToolbarButton("Save")
                                .id("sheet.save")
                                .onClicked { said = "Saved." }
                                .menu(.split) {
                                    MenuItem("Save a copy")
                                        .id("sheet.saveCopy")
                                        .onClicked { said = "Saved a copy." }
                                }

                            ToolbarButton("Add")
                                .id("sheet.add")
                                .icon(ImageSource(light: "menu_duplicate.png", dark: "menu_duplicate_dark.png"))
                                .onClicked { said = "Added." }
                        }

                        ToolbarToggle("Pin", isOn: $pinned)
                            .id("sheet.pin")
                            .icon(
                                ImageSource(light: "menu_star.png", dark: "menu_star_dark.png"),
                                on: ImageSource(light: "menu_star_on.png", dark: "menu_star_on_dark.png"))

                        ToolbarButton("Delete")
                            .id("sheet.delete")
                            .placement(at: .overflow)
                            .role(.destructive)
                            .onClicked { said = "Deleted." }
                    }
                } destination: { number in
                    Text("Page \(number)")
                        .galleryPage("Page \(number)")
                        .toolbar {
                            ToolbarButton("Share")
                                .id("sheet.share")
                                .onClicked { said = "Shared page \(number)." }
                        }
                }
                // The stack's own action, on the bar of every page it shows.
                .toolbar {
                    ToolbarButton("Help")
                        .id("sheet.help")
                        .onClicked { said = "Help for every page." }
                }
            }
        }
        """#,
        "StackLayoutSample": #"""
        // Sources/Samples/Layout/StackLayoutSample.swift
        @State private var spaced = true
        @State private var onBaseline = true
        @State private var wraps = true

        /// Where a wrapped line shorter than the row stands.
        @State private var lines = TextAlignment.start
        static let tags = [
            "Button", "Toggle", "Slider", "Picker", "Text", "Image", "Stack", "Grid",
            "Scroll", "List", "Map", "Sheet", "Menu", "Toolbar", "Tab", "Split",
        ]

        var body: some View {
            VStack {
                SectionTitle("Vertical")

                VStack {
                    StackCell(text: "One")
                    StackCell(text: "Two")
                    StackCell(text: "Three")
                }

                SectionTitle("Horizontal")

                HStack {
                    StackCell(text: "One")
                    StackCell(text: "Two")
                    StackCell(text: "Three")
                }

                SectionTitle("Alignment")

                // Where a child sits in the room its stack gives it.
                VStack {
                    StackCell(text: "start")
                        .horizontalAlignment(.start)

                    StackCell(text: "center")
                        .horizontalAlignment(.center)

                    StackCell(text: "end")
                        .horizontalAlignment(.end)

                    StackCell(text: "fill")
                        .horizontalAlignment(.fill)
                }

                SectionTitle("First baseline")

                // A label and a value of other sizes reading as one line: each
                // rests its first line of words on the row's baseline.
                HStack {
                    Text("Total")
                        .verticalAlignment(onBaseline ? .firstBaseline : .center)
                    Text("€120")
                        .fontWeight(.bold)
                        .verticalAlignment(onBaseline ? .firstBaseline : .center)
                }

                Switch($onBaseline)
                    .text("On one baseline")

                SectionTitle("Space")

                // A space takes the room the other children leave.
                HStack {
                    StackCell(text: "Draft")
                    if spaced { Space() }
                    StackCell(text: "Send")
                }

                Switch($spaced)
                    .text("Space")

                SectionTitle("Short of room")

                // A row short of room takes it from its words: the button stays
                // whole, and the title wraps to what is left - or, kept to one
                // line, ends where the room does.
                HStack {
                    Text("A title longer than the row has room for beside its button")
                    Button("Open")
                }

                HStack {
                    Text("A title longer than the row has room for beside its button")
                        .maximumLines(1)
                    Button("Open")
                }

                SectionTitle("Wraps")

                // A row that wraps goes on onto the next line where its room
                // ends; on one line, its words share the room it has.
                HStack {
                    ForEach(Self.tags, id: \.self) { StackCell(text: $0) }
                }
                .wraps(wraps)
                .lineAlignment(lines)

                Switch($wraps)
                    .text("Wraps")

                // Where a line shorter than the row stands.
                Picker([TextAlignment.start, .center, .end], selection: $lines) { "\($0)".titled }
                    .presentation(.segmented)

                SectionTitle("Separator")

                // The platform's own line, across its stack.
                VStack {
                    Text("Inbox")
                    Separator()
                    Text("Archive")
                }

                HStack {
                    Text("Bold")
                        .fontWeight(.bold)
                    Separator()
                    Text("Italic")
                }
            }
        }

        /// One block of color with a word in it, so an arrangement is visible.
        private struct StackCell: View {
            let text: String

            var body: some View {
                Text(text)
            }
        }
        """#,
        "StateClassSample": #"""
        // Sources/Samples/State/StateClassSample.swift
        /// What a basket holds, as a class rather than a pile of `@State` in the view.
        ///
        /// The properties the interface draws are `@State` - the same word, the same
        /// storage and the same rule as in a view: a write asks the closures that READ
        /// that property for another build, and no other. A plain `var` is stored and
        /// nothing more, and this one is here to be SEEN not working: pressing the
        /// button below raises it and the screen does not follow.
        @MainActor
        private final class Basket {
            @State var items: [String] = []
            @State var note = ""

            /// Counted for the sample's sake; nothing on screen is meant to follow it.
            var plainTaps = 0

            var summary: String {
                items.isEmpty ? "The basket is empty" : items.joined(separator: ", ")
            }
        }

        /// A child the basket was LENT to.
        ///
        /// `@Binding`, the same wrapper an Int is borrowed with - a model is a value
        /// like any other as far as lending is concerned. `$basket` says: I lend you
        /// this, do with it what you want - and `basket.$note` is the note's own
        /// state, the `Binding<String>` a TextField takes and the host carries.
        private struct NoteRow: View {
            @Binding var basket: Basket

            var body: some View {
                VStack {
                    // The field is handed the note's own state and reads nothing; the
                    // label below READS `note`, which is what builds this again.
                    DebugInfoLabel()

                    TextField(basket.$note)
                        .placeholder("A note on the basket")

                    Text(basket.note.isEmpty ? "No note yet" : "Note: \(basket.note)")
                }
            }
        }

        @State private var basket = Basket()

        var body: some View {
            VStack {
                DebugInfoLabel()

                Text("\(basket.items.count) item(s)")

                Text(basket.summary)

                HStack {
                    Button("Add")
                        .onClicked { basket.items.append("Item \(basket.items.count + 1)") }

                    Button("Remove")
                        .isEnabled(!basket.items.isEmpty)
                        .onClicked { basket.items.removeLast() }
                }
                .horizontalAlignment(.center)

                NoteRow(basket: $basket)

                Button("Tap a plain property (\(basket.plainTaps))")
                    .onClicked { basket.plainTaps += 1 }

            }
        }
        """#,
        "StateSample": #"""
        // Sources/Samples/Fundamentals/StateSample.swift
        @State private var counter = 0
        @State private var name = ""

        var body: some View {
            // THE TWO CLOSURES ARE DRAWN, each inside an outline of its own, because
            // what a write rebuilds is easier to believe as a rectangle than as a
            // rule. The outlines are decoration: the reader of a value is the VStack
            // whose braces the get sits in, and that is where each reading is
            // taken.
            ZStack {
                VStack {
                    Text("This closure reads `counter`")
                        .tracking(1)

                    // THIS closure reads `counter`, so a write to it rebuilds THIS
                    // closure - and the reading says `for counter`.
                    DebugInfoLabel()

                    Text("Count: \(counter)")

                    HStack {
                        Button("Increment")
                            .onClicked { counter += 1 }

                        Button("Reset")
                            .isEnabled(counter != 0)
                            .onClicked { counter = 0 }
                    }
                    .horizontalAlignment(.center)

                    ZStack {
                        VStack {
                            Text("And this one reads `name`")
                                .tracking(1)

                            DebugInfoLabel()

                            TextField($name)
                                .placeholder("And the same for text")

                            Text(name.isEmpty ? "Hello, stranger" : "Hello, \(name)!")
                        }
                    }
                    .style(.card)
                    .stroke(Palette.outline)
                    .lineWidth(1)
                }
            }
            .style(.card)
            .stroke(Palette.outline)
            .lineWidth(1)
        }
        """#,
        "StepperSample": #"""
        // Sources/Samples/BasicInput/StepperSample.swift
        @State private var servings = 4.0

        var body: some View {
            VStack {
                // The count is read here, so every step builds this closure.
                DebugInfoLabel()

                Text("Servings: \(Int(servings))")

                Stepper($servings)
                    .minimum(1)
                    .maximum(12)
                    .step(1)
                    .horizontalAlignment(.center)

                SectionTitle("A bigger step")

                // The same value, stepped by five - and written back by hand,
                // which is what the binding above does for you.
                Stepper(servings)
                    .minimum(1)
                    .maximum(12)
                    .step(5)
                    .horizontalAlignment(.center)
                    .onValueChanged { value in servings = value }

                // One write: the value is the new one at once, the motion under
                // the steppers is smooth, and each shows its steps alone on the way.
                Button(servings < 7 ? "Twelve" : "One")
                    .horizontalAlignment(.center)
                    .onClicked { servings = servings < 7 ? 12 : 1 }
            }
        }
        """#,
        "StyleSample": #"""
        // Sources/Samples/Styles/StyleSample.swift
        @State private var enabled = true
        @State private var platformLook = false
        @State private var span = "Week"

        var body: some View {
            // The gallery's styles, or the platform's own look.
            let look: StyleKey<Button>? = platformLook ? .platform : nil

            return VStack {
                DebugInfoLabel()

                // Neither of these says anything of its own look: the violet, the
                // corners and the padding come from Style<Button> in AppStyles.swift,
                // which every button wears.
                HStack {
                    Button("Save").style(look)
                    Button("Cancel").style(look)
                }
                .horizontalAlignment(.center)

                // A style can say what a control looks like in a STATE; hearing
                // the control enter one is what .onVisualStateChanged is for, next
                // door in the Visual states sample.
                Button(enabled ? "Enabled" : "Disabled")
                    .style(look)
                    .isEnabled(enabled)
                    .horizontalAlignment(.center)
                    .onClicked {}

                Switch($enabled)
                    .text("Enabled")
                    .horizontalAlignment(.center)

                Switch($platformLook)
                    .text("Platform look")
                    .horizontalAlignment(.center)

                SectionTitle("A style for a role")

                // Each wears the style its role chooses, over the one every button
                // wears: the role's style says only what the role changes.
                HStack {
                    Button("Keep").style(look).role(.cancel)
                    Button("Delete").style(look).role(.destructive)
                }
                .horizontalAlignment(.center)

                SectionTitle("A style for a presentation")

                // The segments wear the style their presentation chooses, over the
                // one every picker wears.
                Picker(["Day", "Week", "Month"], selection: $span) { $0 }
                    .presentation(.segmented)
                    .style(platformLook ? .platform : nil)
                    .horizontalAlignment(.center)

                SectionTitle("A style asked for by name")

                // A keyed style is asked for; a keyed style REPLACES the implicit
                // one, so it says everything it needs.
                Text("Headline")
                    .style(.headline)

                SectionTitle("A style written from another")

                // The same words twice. "Quote" states the shape; "QuoteLoud" is
                // `.basedOn(.quote)` plus one color - so everything that matches
                // below is inherited, and the one thing that differs is the one
                // thing it declares.
                Text("The same eleven words, and one of these declares a color.")
                    .style(.quote)

                Text("The same eleven words, and one of these declares a color.")
                    .style(.quoteLoud)
            }
        }
        """#,
        "SummedOffTheUIThread": #"""
        // Sources/Samples/State/MainQueueSample.swift
        import Dispatch

        @State private var result = "Nothing summed yet"

        var body: some View {
            VStack {
                Text(result)

                Button("Sum a million on another thread").onClicked {
                    result = "Summing…"
                    let shown = $result
                    #if os(WASI)
                    shown.wrappedValue = "The Web has no main queue - post to the state instead"
                    #else
                    DispatchQueue.global().async {
                        let sum = (1 ... 1_000_000).reduce(0, +)
                        // The main queue runs this on the UI thread, where the state is written.
                        DispatchQueue.main.async { shown.wrappedValue = "\(sum), handed back on the main queue" }
                    }
                    #endif
                }
            }
            .horizontalAlignment(.start)
        }
        """#,
        "SwipeSample": #"""
        // Sources/Samples/Gestures/SwipeSample.swift
        @State private var swipe = ""

        @State private var narrowed = ""

        var body: some View {
            VStack {
                // What was swiped is read here, so every swipe builds this closure.
                DebugInfoLabel()

                ZStack {
                    Text("Swipe across this box")
                }
                .style(.card)
                .stroke(Palette.outline)
                .lineWidth(1)
                // A recognizer that listens for nothing recognizes nothing, so
                // `direction` defaults to every way.
                .onSwiped { direction in
                    swipe = Self.name(of: direction)
                }

                Text(swipe.isEmpty ? "nothing yet" : "Swiped \(swipe)")

                ZStack {
                    Text("Left or right, and a long way")
                }
                .style(.card)
                .stroke(Palette.outline)
                .lineWidth(1)
                // Narrowed: two of the four ways, and a finger that must travel
                // 150 device units before anything fires.
                .onSwiped(direction: [.left, .right], threshold: 150) { direction in
                    narrowed = Self.name(of: direction)
                }

                Text(narrowed.isEmpty ? "nothing yet" : "Swiped \(narrowed)")
            }
        }

        private static func name(of direction: SwipeDirection) -> String {
            switch direction {
            case .left: return "left"
            case .right: return "right"
            case .up: return "up"
            case .down: return "down"
            default: return "somewhere"
            }
        }
        """#,
        "SwitchSample": #"""
        // Sources/Samples/BasicInput/SwitchSample.swift
        @State private var soundOn = true
        @State private var said = "not thrown yet"
        @State private var alignment = Alignment.fill

        static let alignments: [Alignment] = [.fill, .start, .center, .end]

        var body: some View {
            VStack {
                // The flag is read here, so every flip builds this closure.
                DebugInfoLabel()

                Switch($soundOn)
                    .text("Sound")
                    // Runs beside the binding's write-back, carrying what the
                    // switch NOW is rather than what this side guessed.
                    .onToggled { on in said = on ? "thrown on" : "thrown off" }
                    // Filling its row, its words stand at the start and the switch
                    // at the end; aligned, it is as wide as the two together.
                    .horizontalAlignment($alignment)

                Picker(Self.alignments, selection: $alignment) { "\($0)".titled }
                    .presentation(.segmented)

                Text(soundOn ? "on" : "off")

                Text(said)
            }
        }
        """#,
        "TabsInASheet": #"""
        // Sources/Samples/Navigation/SheetsSample.swift
        @State private var presented = false
        @State private var said = "Nothing done yet."

        var body: some View {
            VStack {
                Text("Present the tabs, change tabs and press each tab's actions.")

                Button("Present the tabs")
                    .horizontalAlignment(.center)
                    .onClicked { presented = true }
                    .sheet(isPresented: $presented) {
                        MailSheet(said: $said)
                    }

                Text(said)
            }
        }

        /// A mailbox's tabs in a sheet, each a stack.
        private struct MailSheet: View {
            enum Tab: Hashable, CaseIterable { case inbox, drafts }

            @Binding var said: String
            @State private var tab: Tab = .inbox
            @State private var inbox: [Int] = []
            @State private var drafts: [Int] = []

            var body: some View {
                TabView(Tab.allCases, selection: $tab) { tab in
                    switch tab {
                    case .inbox:
                        NavigationStack($inbox) {
                            page("Inbox", path: $inbox)
                                .toolbar {
                                    ToolbarButton("Refresh")
                                        .id("tabs.refresh")
                                        .onClicked { said = "Refreshed the inbox." }
                                }
                        } destination: { number in
                            Text("Message \(number)").padding(24).galleryPage("Message \(number)")
                        }
                        .title("Inbox")
                        .icon(ImageSource(light: "tab_pages.png", dark: "tab_pages_dark.png"))

                    case .drafts:
                        NavigationStack($drafts) {
                            page("Drafts", path: $drafts)
                                .toolbar {
                                    ToolbarGroup {
                                        ToolbarButton("New")
                                            .id("tabs.new")
                                            .icon(ImageSource(light: "menu_duplicate.png", dark: "menu_duplicate_dark.png"))
                                            .onClicked { said = "Started a draft." }
                                        ToolbarButton("Send all")
                                            .id("tabs.send")
                                            .onClicked { said = "Sent every draft." }
                                    }
                                }
                        } destination: { number in
                            Text("Draft \(number)").padding(24).galleryPage("Draft \(number)")
                        }
                        .title("Drafts")
                        .icon(ImageSource(light: "tab_code.png", dark: "tab_code_dark.png"))
                    }
                }
            }

            /// A tab's first page: its name, and a button pushing a page onto its stack.
            private func page(_ name: String, path: Binding<[Int]>) -> some View {
                VStack {
                    Text(said)
                    Button("Push a page")
                        .onClicked { path.wrappedValue.append(path.wrappedValue.count + 1) }
                }
                .galleryPage(name)
            }
        }
        """#,
        "TabsSample": #"""
        // Sources/Samples/Navigation/TabsSample.swift
        let nav: Navigation

        var body: some View {
            VStack {
                Button("Open the tabs")
                    .horizontalAlignment(.center)
                    .onClicked { nav.open(.tabs) }
            }
        }
        """#,
        "TapSample": #"""
        // Sources/Samples/Gestures/TapSample.swift
        @State private var taps = 0

        var body: some View {
            VStack {
                // The count is read here, so every tap builds this closure.
                DebugInfoLabel()

                ZStack {
                    Text("Tap anywhere on this box")
                }
                .style(.card)
                .stroke(Palette.outline)
                .lineWidth(1)
                .onTapped { taps += 1 }

                ZStack {
                    Text("Double-tap this one to reset")
                }
                .style(.card)
                .stroke(Palette.outline)
                .lineWidth(1)
                .onTapped(count: 2) { taps = 0 }

                Text("Tapped \(taps) time(s)")
            }
        }
        """#,
        "TaskSleepSample": #"""
        // Sources/Samples/DateTime/TaskSleepSample.swift
        /// Whole seconds left. The interface reads this, so writing it is the whole
        /// of "tick".
        @State private var remaining = 0

        /// The countdown this run started from, for the bar's fraction.
        @State private var total = 30

        @State private var running = false

        var body: some View {
            VStack {
                // The countdown is read here, so every step builds this closure.
                DebugInfoLabel()

                Text("\(remaining)")
                    .fontWeight(.bold)

                ProgressBar(total == 0 ? 0 : Double(remaining) / Double(total))

                HStack {
                    // A press while the loop runs cancels it - Stop, or Start
                    // straight after Reset - so no two loops count together.
                    Button(running ? "Stop" : "Start")
                        .onClicked(.cancelPrevious) {
                            if running {
                                running = false
                                return
                            }

                            if remaining == 0 { remaining = total }

                            running = true

                            // Plain Swift concurrency, on every platform: when the
                            // sleep comes due, the handler resumes on `MainActor` -
                            // the thread the host draws on - with no `Timer`
                            // anywhere.
                            while running && remaining > 0 {
                                try await Task.sleep(for: .seconds(1))

                                guard running else { return }

                                remaining -= 1
                            }

                            running = false
                        }

                    Button("Reset")
                        .onClicked {
                            running = false
                            remaining = total
                        }
                }
                .horizontalAlignment(.center)

                HStack {
                    ForEach([10, 30, 60]) { length in
                        Button("\(length)s")
                            .onClicked {
                                running = false
                                total = length
                                remaining = length
                            }
                    }
                }
                .horizontalAlignment(.center)
            }
            .onDestroying { running = false }
        }
        """#,
        "TextEditorSample": #"""
        // Sources/Samples/Text/TextEditorSample.swift
        @State private var draft = ""

        var body: some View {
            VStack {
                // The count of characters below reads `draft`, so every keystroke
                // builds this closure; the two editors are handed the state.
                DebugInfoLabel()

                // The same text in both editors, so typing in either moves the
                // other - and only the right one grows with it.
                Grid {
                    VStack {
                        Text("a stated height")

                        TextEditor($draft)
                            .placeholder("Anything worth remembering")
                            .height(110)
                    }

                    VStack {
                        Text(".growsWithText(true)")

                        TextEditor($draft)
                            .placeholder("The same text, sized by it")
                            .growsWithText(true)
                    }
                    .verticalAlignment(.start)
                    .gridColumn(1)
                }
                .columns(.fill, .fill)

                Text(draft.isEmpty ? "nothing written yet" : "\(draft.count) character(s)")

                Button("Clear")
                    .horizontalAlignment(.center)
                    .isEnabled(!draft.isEmpty)
                    .onClicked { draft = "" }
            }
        }
        """#,
        "TextFieldSample": #"""
        // Sources/Samples/Text/TextFieldSample.swift
        @State private var name = ""
        @State private var editing = false
        @State private var code = ""
        @State private var selectAll = false
        @State private var email = ""
        @State private var done = 0
        @State private var hidden = true
        @State private var user = ""
        @State private var newPassword = ""
        @State private var signInCode = ""

        var body: some View {
            VStack {
                // The greeting below reads `name` and the caret below reads `code`,
                // so a keystroke in either builds this closure; the fields read
                // nothing - they are handed the state - and typing an address or a
                // password builds nothing at all.
                DebugInfoLabel()

                TextField($name)
                    .placeholder("Type your name")
                    .showsClearButton(true)
                    .isFocused($editing)

                Text(name.isEmpty ? "Hello, stranger" : "Hello, \(name)!")

                Text(editing ? "the field has the focus" : "the field does not have the focus")

                Text("return pressed \(done)x")

                // A field for something that is not prose: the platform's
                // underline and its next-word guesses only get in the way, the
                // caret can be put where the user did not, and every letter
                // typed stands in capitals, as a serial number's do.
                TextField($code)
                    .placeholder("a serial number")
                    .textCase(.uppercase)
                    .isSpellCheckEnabled(false)
                    .isTextPredictionEnabled(false)
                    .cursorPosition(selectAll ? 0 : code.count)
                    .selectionLength(selectAll ? code.count : 0)

                // SELECTING IS SOMETHING THAT HAPPENS, so it is a button rather
                // than a switch - and it says which of the two it will do next,
                // because a press has to WRITE a value the field has not been
                // given: a value the patch leaves out means unchanged, so a press
                // that asks for the selection the field already has says nothing.
                Button(selectAll ? "Clear the selection" : "Select the lot")
                    .horizontalAlignment(.center)
                    .onClicked { selectAll.toggle() }

                TextField("read only")
                    .isReadOnly(true)

                TextField()
                    .placeholder("a password")
                    .isPassword(hidden)
                    .submitLabel(.done)

                Switch($hidden)
                    .text("Hidden")
                    .horizontalAlignment(.center)

                // The keyboard the platform brings up, a cap on the length, and
                // what the return key does when it is pressed.
                TextField($email)
                    .placeholder("an address, capped at 20")
                    .inputPurpose(.email)
                    .maximumLength(20)
                    .onSubmitted { done += 1 }

                // Signing in: what each field holds is what the platform fills
                // it in with - a name it keeps, a strong password it makes and
                // keeps, a code it received.
                TextField($user)
                    .placeholder("a user name")
                    .inputPurpose(.username)

                TextField($newPassword)
                    .placeholder("a new password")
                    .isPassword(true)
                    .inputPurpose(.newPassword)

                TextField($signInCode)
                    .placeholder("a code sent to you")
                    .inputPurpose(.oneTimeCode)
            }
        }
        """#,
        "TextSample": #"""
        // Sources/Samples/Text/TextSample.swift
        var body: some View {
            VStack {
                Text("Plain")
                    .fontSize(16)

                Text("Bold")
                    .fontSize(16)
                    .fontWeight(.bold)

                Text("Italic, and colored")
                    .fontSize(16)
                    .fontAttributes(.italic)
                    .textColor(Palette.accent)

                Text("Underlined and struck through")
                    .fontSize(16)
                    .textDecorations([.underline, .strikethrough])

                Text("Centered, with room around it")
                    .fontSize(16)
                    .horizontalTextAlignment(.center)
                    .padding(8)

                Text("A long line that has nowhere left to go, so it is cut short with an ellipsis")
                    .fontSize(16)
                    .lineBreak(.tailTruncation)
                    .maximumLines(1)

                Text("Held to two lines, words that wrap end the second with an ellipsis where they go on past it")
                    .fontSize(16)
                    .maximumLines(2)
                    .width(260)
                    .horizontalAlignment(.start)

                Text("Letters spaced out")
                    .fontSize(16)
                    .tracking(3)

                // The height of a line as a MULTIPLE of the font's own: the same
                // two lines packed tight, then opened out.
                HStack {
                    Text("Two lines,\nlineHeight 0.8")
                        .fontSize(16)
                        .lineHeight(0.8)

                    Text("Two lines,\nlineHeight 2")
                        .fontSize(16)
                        .lineHeight(2)
                }
                .spacing(16)

                // One string in mixed case, drawn twice. The case is the DRAWING;
                // the text stays as it was written.
                Text("One string, drawn in Two Ways")
                    .fontSize(16)
                    .textCase(.uppercase)

                Text("One string, drawn in Two Ways")
                    .fontSize(16)
                    .textCase(.lowercase)

                // Text follows the system's text-size setting unless a label says
                // it does not.
                Text("Grows with the system text size")
                    .fontSize(16)

                Text("Stays at 16 whatever the system says")
                    .fontSize(16)
                    .isFontAutoScalingEnabled(false)
            }
            .spacing(10)
        }
        """#,
        "TextSpanSample": #"""
        // Sources/Samples/Text/TextSpanSample.swift
        @State private var highlighted = 1

        /// The line one word of which is colored - the word the button moves.
        private let words = ["A", "Text", "has", "one", "TextColor"]

        var body: some View {
            VStack {
                // `highlighted` is read here, so moving the highlight builds this
                // closure.
                DebugInfoLabel()

                // Three colors in one line, which is what runs are FOR: a label
                // has one `textColor`, so this is the only way.
                Text()
                    .spans {
                        TextSpan("let ").textColor(Palette.brand)
                        TextSpan("counter").textColor(Palette.accent)
                        TextSpan(" = 0")
                    }
                    .fontSize(17)
                    .fontFamily("Menlo")

                Text()
                    .spans {
                        TextSpan("Sold ")
                            .fontSize(17)
                            .textColor(Palette.text)

                        TextSpan("out")
                            .fontSize(17)
                            .fontWeight(.bold)
                            .textColor(Palette.onAccent)
                            .background(Palette.accent)
                    }

                Text()
                    .spans {
                        words.enumerated().map { index, word in
                            TextSpan(word + " ")
                                .fontSize(17)
                                .textColor(index == highlighted ? Palette.accent : Palette.text)
                                .fontWeight(index == highlighted ? .bold : .regular)
                        }
                    }

                Button("Move the highlight")
                    .onClicked { highlighted = (highlighted + 1) % words.count }

                // `text` and `spans` are MUTUALLY EXCLUSIVE: a label
                // given both shows the runs.
                Text("this text never appears")
                    .spans {
                        TextSpan("the runs win")
                            .fontSize(17)
                            .textColor(Palette.text)
                    }

            }
            .spacing(12)
        }
        """#,
        "TextStyleSample": #"""
        // Sources/Samples/Text/TextStyleSample.swift
        /// The step a line stands at, moved by the buttons and handed to the line as a state.
        @State private var style = TextStyle.title

        /// The seconds a countdown has left, and whether its digits are all as wide.
        @State private var seconds = 20
        @State private var monospaced = true

        var body: some View {
            VStack {
                Text("Display").textStyle(.display)
                Text("Title").textStyle(.title)
                Text("Subtitle").textStyle(.subtitle)
                Text("Headline").textStyle(.headline)
                Text("Body").textStyle(.body)
                Text("Caption").textStyle(.caption)

                HStack {
                    Text("Regular").fontWeight(.regular)
                    Text("Medium").fontWeight(.medium)
                    Text("Semibold").fontWeight(.semibold)
                    Text("Bold").fontWeight(.bold)
                }

                Text("A title, at a weight of its own").textStyle(.title).fontWeight(.regular)

                Text("Stepped through the ramp").textStyle($style)

                HStack {
                    Button("Larger").onClicked { style = TextStyle(rawValue: style.rawValue - 1) ?? .display }
                    Button("Smaller").onClicked { style = TextStyle(rawValue: style.rawValue + 1) ?? .caption }
                }

                // With digits of their own width, the words after the number move as it counts.
                HStack {
                    Text("\(seconds) s left").fontAttributes(monospaced ? .monospacedDigits : .none)
                    Button("Count down").onClicked(.cancelPrevious) {
                        seconds = 20
                        while seconds > 0 {
                            try await Task.sleep(for: .milliseconds(300))
                            seconds -= 1
                        }
                    }
                }

                Switch($monospaced).text("Digits of one width")
            }
        }
        """#,
        "TickerSample": #"""
        // Sources/Samples/DateTime/TickerSample.swift
        /// `@State` keeps the instance across renders; a tick asks for the render
        /// itself, naming the ticker - so the views that read it are rebuilt and
        /// the rest of the tree is left alone. Nothing here subscribes to anything.
        @State private var ticker = Ticker(every: .seconds(1), limit: 30)

        var body: some View {
            VStack {
                // The tick is read here, so every second builds this closure -
                // which is what a clock costs when its digits are described.
                DebugInfoLabel()

                Text("\((ticker.limit ?? 0) - ticker.ticks)")
                    .fontWeight(.bold)

                ProgressBar(remaining)

                HStack {
                    Button(ticker.isRunning ? "Stop" : "Start")
                        .onClicked { ticker.isRunning ? ticker.stop() : ticker.start() }

                    Button("Reset")
                        .onClicked { ticker.reset() }
                }
                .horizontalAlignment(.center)

                HStack {
                    ForEach([10, 30, 60]) { length in
                        Button("\(length)s")
                            .onClicked {
                                ticker.reset()
                                ticker.limit = length
                            }
                    }
                }
                .horizontalAlignment(.center)
            }
        }

        /// How much of the countdown is left, as a fraction for the bar.
        private var remaining: Double {
            let total = ticker.limit ?? 0

            return total == 0 ? 0 : Double(total - ticker.ticks) / Double(total)
        }
        """#,
        "TimePickerSample": #"""
        // Sources/Samples/DateTime/TimePickerSample.swift
        @State private var alarm = ClockTime(hour: 7, minute: 30)
        @State private var picks = 0

        var body: some View {
            VStack {
                // `alarm` is printed below, so picking a time builds this closure;
                // the picker itself is handed the state.
                DebugInfoLabel()

                TimePicker($alarm)
                    .format("t")

                Text("Alarm at \(alarm.text)")

                HStack {
                    Button("Morning")
                        .onClicked { alarm = ClockTime(hour: 7, minute: 30) }

                    Button("Lunch")
                        .onClicked { alarm = ClockTime(hour: 12, minute: 0) }

                    Button("Evening")
                        .onClicked { alarm = ClockTime(hour: 21, minute: 5) }
                }
                .horizontalAlignment(.center)

                SectionTitle("One-way, written back by hand")

                // The same time, one-way: `.time` is what puts it in the field,
                // and the write back is by hand.
                TimePicker()
                    .time(alarm)
                    .format("t")
                    .onTimeChanged { time in
                        alarm = time
                        picks += 1
                    }

                Text(picks == 0
                    ? "onTimeChanged has not fired"
                    : "onTimeChanged: \(alarm.text), \(picks) so far")
            }
        }
        """#,
        "ToolbarLayerPage": #"""
        // Sources/Samples/Navigation/ToolbarLayerPage.swift
        /// A page the toolbar's layers push: its own actions on the bar while it is shown, and a way one page deeper.
        ///
        /// Its actions stand nearer the title than the gallery's, which keep their place at the edge; going back takes them
        /// away with the page, and the bar stands as it stood before the push.
        struct ToolbarLayerPage: View {

            /// How deep it stands, from 1.
            let depth: Int

            /// The stack this page is on, which "Deeper" pushes onto.
            @Binding var path: [Route]

            /// How many times this page's Share was pressed.
            @State private var shared = 0

            var body: some View {
                VStack {
                    Text("Layer \(depth)")
                        .fontWeight(.bold)

                    Text("Shared \(shared) time(s)")

                    Text("Go back and this page's actions leave with it.")
                }
                .toolbar {
                    ToolbarGroup {
                        ToolbarButton("Share")
                            .id("layer.share")
                            .onClicked { shared += 1 }

                        ToolbarButton("Deeper")
                            .id("layer.deeper")
                            .onClicked { path.append(.layer(depth + 1)) }
                    }
                }
                .galleryPage("Layer \(depth)")
            }
        }
        """#,
        "ToolbarLayersSample": #"""
        // Sources/Samples/Navigation/ToolbarLayersSample.swift
        /// Where the gallery is: the button pushes a page onto its stack.
        let nav: Navigation

        /// How many times this page's own Refresh was pressed.
        @State private var refreshed = 0

        var body: some View {
            VStack {
                DebugInfoLabel()

                Text("Refreshed \(refreshed) time(s)")

                Text("Open a page, look at the bar, then go back.")

                Button("Open a page with its own actions")
                    .onClicked { nav.push(.layer(1)) }
            }
            .toolbar {
                ToolbarButton("Refresh")
                    .id("layers.refresh")
                    .onClicked { refreshed += 1 }
            }
        }
        """#,
        "ToolbarSample": #"""
        // Sources/Samples/Navigation/ToolbarSample.swift
        @State private var saved = 0
        @State private var recent = ["notes.txt", "budget.csv"]

        /// How many files Add has made, so each gets a name of its own - a menu
        /// row is identified by the file it names, and two rows may not claim the
        /// same identity.
        @State private var added = 0

        /// Whether the sample's group stands after the gallery's, by its order.
        @State private var afterGallery = false

        /// Whether the sample's group stands at the bar's start.
        @State private var atStart = false

        /// Whether the sample's group stands in the sidebar's part of the bar.
        @State private var overSidebar = false

        /// Whether the sample's group hides with the sidebar rather than move to
        /// the detail's start.
        @State private var hidesWithSidebar = false

        /// Whether Add shows its words beside its picture on the bar.
        @State private var addWords = false

        /// Whether the page is a favorite: a setting on the bar and in the File
        /// menu, one state for both.
        @State private var favorite = false

        /// Whether Save's menu opens as the button is held rather than from an
        /// arrow of its own.
        @State private var saveHeld = false

        /// Whether Sort shows the arrow saying its click opens a menu.
        @State private var sortArrow = true

        /// Whether the branch declaring the actions is disabled.
        @State private var locked = false

        /// Whether the page shows the bar at its foot.
        @State private var atFoot = true

        var body: some View {
            VStack {
                VStack {
                    // The counts are read here, so every toolbar item that acts
                    // builds this closure.
                    DebugInfoLabel()

                    Text("Saved \(saved) time(s)")

                    Text(recent.isEmpty ? "No recent files" : recent.joined(separator: ", "))

                    Text(favorite ? "A favorite" : "Not a favorite")

                    Text("Press Save, Add and the star; Sort and Save's arrow open menus; Clear is in the overflow.")

                    SectionTitle("Where the actions stand")

                    switchRow($afterGallery, "After the gallery's actions", id: "toolbar.afterGallery")
                    switchRow($atStart, "At the start", id: "toolbar.atStart")
                    switchRow($overSidebar, "Over the sidebar", id: "toolbar.overSidebar")
                    switchRow($hidesWithSidebar, "Hidden with the sidebar", id: "toolbar.hidesWithSidebar")

                    SectionTitle("A picture and its words")

                    switchRow($addWords, "Add's words beside its picture", id: "toolbar.addWords")

                    SectionTitle("A button's menu")

                    switchRow($saveHeld, "Save's menu held", id: "toolbar.saveHeld")
                    switchRow($sortArrow, "Sort's arrow", id: "toolbar.sortArrow")

                    SectionTitle("At the page's foot")

                    switchRow($atFoot, "The bar at the foot", id: "toolbar.atFoot")
                }
                // The page's actions, declared where their state lives: they follow
                // it as the body builds - `saved` decides whether Clear can be pressed,
                // `addWords` Add's words, the four switches where the group stands.
                .toolbar {
                    ToolbarGroup {
                        // Its click its own, its menu apart: from an arrow of its
                        // own, or held.
                        ToolbarButton("Save")
                            .id("save")
                            .onClicked { saved += 1 }
                            .menu(saveHeld ? .held : .split) {
                                MenuItem("Save a copy")
                                    .id("saveCopy")
                                    .onClicked {
                                        saved += 1
                                        added += 1
                                        recent.append("copy\(added).txt")
                                    }
                            }

                        // A picture alone, unless it asks for its words beside it.
                        ToolbarButton("Add")
                            .id("add")
                            .icon(ImageSource(light: "menu_duplicate.png", dark: "menu_duplicate_dark.png"))
                            .showsText(addWords)
                            .onClicked {
                                added += 1
                                recent.append("file\(added).txt")
                            }
                    }
                    .placement(overSidebar ? .sidebar : nil, at: atStart ? .start : .end, order: afterGallery ? 1 : 0)
                    .hidesWithSidebar(hidesWithSidebar)

                    // A menu its click opens, an arrow saying so.
                    ToolbarButton("Sort")
                        .id("sort")
                        .showsMenuArrow(sortArrow)
                        .menu {
                            MenuItem("A to Z").id("sort.up").onClicked { recent.sort() }
                            MenuItem("Z to A").id("sort.down").onClicked { recent.sort(by: >) }
                        }

                    // A setting: on and off, its filled star while on.
                    ToolbarToggle("Favorite", isOn: $favorite)
                        .id("favorite")
                        .icon(
                            ImageSource(light: "menu_star.png", dark: "menu_star_dark.png"),
                            on: ImageSource(light: "menu_star_on.png", dark: "menu_star_on_dark.png"))

                    ToolbarButton("Clear")
                        .id("clear")
                        .placement(at: .overflow)
                        .role(.destructive)
                        .isEnabled(saved > 0)
                        .onClicked { saved = 0 }
                }
                // The bar at the page's foot, by the same rules: words nobody
                // chooses at its start, an action at its end.
                .toolbar(.bottom) {
                    if atFoot {
                        ToolbarLabel(recent.isEmpty ? "No recent files" : "\(recent.count) recent file(s)")
                            .id("foot.files")
                            .placement(at: .start)

                        ToolbarButton("Save")
                            .id("foot.save")
                            .onClicked { saved += 1 }
                    }
                }
                // The desktop File menu, declared the same way: Save, and the recent
                // files following the state.
                .menuBar {
                    Menu("File") {
                        MenuItem("Save")
                            .id("save")
                            .onClicked { saved += 1 }

                        // The bar's setting again, checked as the state is.
                        MenuToggle("Favorite", isOn: $favorite)
                            .id("favorite")

                        Menu("Recent") {
                            recent.map { file in
                                MenuItem(file)
                                    .id(file)
                                    .onClicked { recent.removeAll { $0 == file } }
                            }
                        }
                        .id("recent")
                        .isEnabled(!recent.isEmpty)
                    }
                    .id(StandardMenu.file)
                }
                // Locked, the branch takes no input: its switches, and the
                // actions and menu items declared on it, dimmed with it.
                .isEnabled(!locked)

                SectionTitle("Out of reach")

                switchRow($locked, "Lock the switches and actions above", id: "toolbar.locked")
            }
        }

        /// A switch and what it says, told apart for scripts by `id`.
        private func switchRow(_ value: Binding<Bool>, _ words: String, id: String) -> some View {
            Switch(value)
                .text(words)
        }
        """#,
        "TooltipSample": #"""
        // Sources/Samples/BasicInput/TooltipSample.swift
        @State private var detailed = false

        var body: some View {
            VStack {
                Text("Rest the pointer on a button or on the swatch.")

                HStack {
                    // A button that is only a picture says what it does
                    // to the eye under the pointer.
                    Button("Media")
                        .icon(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                        .showsText(false)
                        .style(.iconButton)
                        .contentMode(.fit)
                        .width(48)
                        .height(48)
                        .tooltip(detailed ? "Opens the pictures, films and sounds" : "Media")

                    Button("Layout")
                        .icon(ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"))
                        .showsText(false)
                        .style(.iconButton)
                        .contentMode(.fit)
                        .width(48)
                        .height(48)
                        .tooltip(detailed ? "Opens the stacks, grids and placement" : "Layout")

                    // Any view takes one, not only a control.
                    Rectangle()
                        .fill(Palette.accent)
                        .width(48)
                        .height(48)
                        .tooltip(detailed ? "The color the gallery marks things with" : "Accent")
                }

                Switch($detailed)
                    .text("Detailed")
            }
        }
        """#,
        "TouchThroughSample": #"""
        // Sources/Samples/Gestures/TouchThroughSample.swift
        @State private var below = 0
        @State private var child = 0
        @State private var childrenToo = false
        @State private var disabled = false

        var body: some View {
            VStack {
                // Both counts are read here, so a tap on either builds this closure.
                DebugInfoLabel()

                Grid {
                    // Underneath, and still reachable.
                    Rectangle()
                        .fill(Palette.accent)
                        .height(120)
                        .onTapped { below += 1 }

                    // On top. Its own empty area lets taps through to the box below
                    // while the label inside still answers - or, with "Children too",
                    // the whole of it ignores input, the label included; disabled,
                    // the label still takes a tap and answers none.
                    VStack {
                        // The child wears its own color and its own padding, so
                        // what is the child and what is the empty area around it
                        // can be told apart by eye - and aimed at separately.
                        Text("tap the child")
                            .horizontalAlignment(.center)
                            .verticalAlignment(.center)
                            .onTapped { child += 1 }
                    }
                    .letsInputThrough(!childrenToo)
                    .ignoresInput(childrenToo)
                    .isEnabled(!disabled)
                }

                Text("below \(below)   child \(child)")
                    .horizontalAlignment(.center)

                HStack {
                    SwitchRow("Children too", $childrenToo)

                    SwitchRow("Disabled", $disabled)
                }
                .horizontalAlignment(.center)

                Button("Reset")
                    .onClicked { below = 0; child = 0 }
                    .horizontalAlignment(.center)
            }
        }
        """#,
        "TrafficLight": #"""
        // Sources/Samples/Interop/TrafficLight.swift
        /// What the light can show.
        ///
        /// A closed vocabulary, so it crosses as its member's number. The numbers are
        /// this application's own contract, and every host's control mirrors them.
        public enum TrafficSignal: Int32, CaseIterable, HostRepresentable {
            /// Red.
            case stop = 0

            /// Amber.
            case caution = 1

            /// Green.
            case go = 2
        }

        /// The gallery's own traffic light, declared: its node type, the tier it
        /// wears, and its members, each with its value's type.
        public enum TrafficLightContract: ElementContract {
            public static let nodeType: NodeType = "Gallery.TrafficLight"
            public static let tiers: [any Contract.Type] = [ViewContract.self]

            /// Which lamp is lit.
            public static let signal = ElementProperty<Self, TrafficSignal>("signal")

            /// A lamp was tapped, with its index from the top.
            public static let lampTapped = ElementEvent<Self, Int>("lampTapped")

            public static let members: [any ContractMember] = [signal, lampTapped]
        }

        /// The Swift half of the traffic light: a view whose node its contract makes.
        /// `setValue` writes its property and `onEvent` hears its event; margins,
        /// alignment, opacity and gestures come with `View`.
        public struct TrafficLight: ElementView {
            public var node = Node(contract: TrafficLightContract.self)

            /// A light; `signal(_:)` says which lamp is lit.
            public init() {}

            /// Which lamp is lit.
            public func signal(_ value: TrafficSignal) -> Self {
                setValue(TrafficLightContract.signal, value)
            }

            /// A lamp was tapped, with its index from the top.
            public func onLampTapped(_ handler: @escaping @MainActor (Int) throws -> Void) -> Self {
                onEvent(TrafficLightContract.lampTapped, handler)
            }
        }
        """#,
        "TransformSample": #"""
        // Sources/Samples/Layout/TransformSample.swift
        /// One color per family, so the three rows read apart at a glance rather than
        /// as one long run of identical squares.
        private enum Family {
            /// The two chains that differ only in the ORDER they are written in.
            static let order = Palette.accent

            /// The four ways of turning a view.
            static let turn = Palette.brand

            /// The three ways of resizing one.
            static let size = Color(light: AppColors.amber, dark: AppColors.windowYellow)
        }

        /// Whether the page wears its transforms - one switch over every example,
        /// so throwing it flies the whole page between plain squares and turned,
        /// tipped, grown ones.
        @State private var transformed = true

        var body: some View {
            VStack {
                // ONE SWITCH over every example below. Each transform is written
                // as a choice between itself and none, so throwing it sends the
                // whole page to its turned, grown self and back - and a changed
                // transform TRAVELS, so the boxes fly rather than jump.
                SwitchRow("Transforms", $transformed)

                // A GET IN THESE BRACES, which is what makes THIS row a reader:
                // it is built again on every throw, and its count is what that
                // costs. Each row of boxes below reads the switch in its own
                // braces, so each of them is a reader of its own.
                HStack {
                    Text(transformed ? "every transform on" : "plain squares")
                        .verticalAlignment(.center)

                    DebugInfoLabel()
                }
                .horizontalAlignment(.center)

                // The same two parts in both chains; only the order differs, so
                // the only thing the row shows is that order is what a chain MEANS.
                HStack {
                    piece(
                        box(Family.order)
                            .transform(transformed ? .rotate(45).translate(28, 0) : .identity),
                        "rotate, then move")

                    piece(
                        box(Family.order)
                            .transform(transformed ? .translate(28, 0).rotate(45) : .identity),
                        "move, then rotate")
                }
                .horizontalAlignment(.center)

                HStack {
                    piece(box(Family.turn).rotation(transformed ? 20 : 0), "rotation")
                    piece(box(Family.turn).rotationX(transformed ? 55 : 0), "rotationX")
                    piece(box(Family.turn).rotationY(transformed ? 55 : 0), "rotationY")
                    piece(
                        // Flat, in the plane of the screen.
                        box(Family.turn)
                            .rotation(transformed ? 20 : 0)
                            .pivotX(0)
                            .pivotY(0),
                        "anchor 0,0")
                }
                .horizontalAlignment(.center)

                HStack {
                    piece(box(Family.turn).transform(transformed ? .tilt(55) : .identity), "tilt, flat")
                    piece(box(Family.turn).transform(transformed ? .turn(55) : .identity), "turn, flat")
                }
                .horizontalAlignment(.center)

                // The same square and the same factor three times, so the only
                // thing the row shows is which axis each modifier reaches - and a
                // WIDER GAP than the orange row, because a scaled box is drawn
                // outside its room and would otherwise touch its neighbors.
                HStack {
                    // Drawing only - the room the layout gave it does not change.
                    piece(box(Family.size).scale(transformed ? 1.6 : 1), "scale")
                    piece(box(Family.size).scaleX(transformed ? 1.6 : 1), "scaleX")
                    piece(box(Family.size).scaleY(transformed ? 1.6 : 1), "scaleY")
                }
                .horizontalAlignment(.center)
            }
        }

        /// The square every example transforms - sized here, because a transform
        /// is about what is DRAWN and the room each one gets has to be the same.
        ///
        /// - Parameter color: which family this square belongs to.
        /// - Returns: the square, ready to be transformed.
        private func box(_ color: Color) -> Rectangle {
            Rectangle()
                .fill(color)
                .width(44)
                .height(44)
        }

        /// One piece with its caption, so a row reads as labeled examples rather
        /// than bare boxes. The gap under the box is what a scaled one grows into.
        private func piece<Shown: View>(_ view: Shown, _ caption: String) -> some View {
            VStack {
                view

                Text(caption)
            }
        }
        """#,
        "TwoFingersSample": #"""
        // Sources/Samples/MotionLayout/TwoFingersSample.swift
        import StateUIFoundation

        /// THE PARAMETERS: how far the ring is turned, a card a unit, and how large it
        /// stands.
        struct Ring: LayoutParameters {
            var turn = 0.0
            var size = 1.0

            static var axes: [WritableKeyPath<Ring, Double>] { [\.turn, \.size] }
        }

        /// The cards: the gallery's groups' pictures.
        static let cards = [
            "cat_fundamentals.png", "cat_driven.png", "cat_state.png", "cat_animation.png",
            "cat_basicinput.png", "cat_text.png", "cat_layout.png", "cat_styles.png",
        ]

        /// Where the ring stands on both axes - handed on with `$`, never read in
        /// the body.
        @State private var ring = Ring()

        var body: some View {
            let count = Double(Self.cards.count)

            return Grid {
                MotionLayout(Self.cards, parameters: $ring) { art in
                    ZStack { Image(ImageSource(art)).contentMode(.fill) }
                        .clipsContent(true)
                } placements: { room, ring in
                    Self.cards.indices.map { place($0, ring, room) }
                }
                // TWO FINGERS TURNING turn the ring a card every eighth of a
                // turn, round and round; SPREADING, they grow it from small to
                // large, resting at either or at its own size - both at once.
                .axis(
                    \.turn, input: .rotation(degreesPerUnit: 360 / count), range: 0...count, snaps: .every(1),
                    periodic: true)
                .axis(\.size, input: .magnification, range: 0.6...1.5, snaps: [1])
                .motion(.spring(response: .milliseconds(420), damping: 0.8))
            }
            .clipsContent(true)
        }

        /// Where the card at `index` stands: round the middle of the room, turned
        /// to face out, the ring and its cards as large as its size.
        private func place(_ index: Int, _ ring: Ring, _ room: Rect) -> Placement {
            let count = Double(Self.cards.count)
            let angle = (Double(index) + ring.turn) / count * 2 * .pi - .pi / 2
            let radius = min(room.width, room.height) * 0.3 * ring.size
            let width = min(room.width, room.height) * 0.16 * ring.size
            let height = width * 1.4
            let x = room.width / 2 + cos(angle) * radius
            let y = room.height / 2 + sin(angle) * radius

            return Placement(
                Rect(x - width / 2, y - height / 2, width, height),
                transform: .rotate(angle * 180 / .pi + 90),
                zIndex: Int(y))
        }
        """#,
        "Uploads": #"""
        // Sources/Samples/State/GateSample.swift
        /// Nothing held back, and busy while any upload runs.
        @State private var uploads = Gate(.runConcurrently)
        @State private var sent: [String] = []

        private let files = ["notes.txt", "photo.png", "song.mp3"]

        var body: some View {
            VStack {
                Text("Send all three, quickly.")

                ForEach(files) { file in
                    Button("Send \(file)")
                        .onClicked(gate: uploads) {
                            try await Task.sleep(for: .milliseconds(1500))
                            sent.append(file)
                        }
                }

                Text(uploads.isBusy ? "Uploading…" : "Sent: \(sent.isEmpty ? "nothing" : sent.joined(separator: ", "))")
            }
        }
        """#,
        "VisualStateSample": #"""
        // Sources/Samples/Styles/VisualStateSample.swift
        @State private var enabled = true
        @State private var presses = 0
        @State private var entered = "Normal"

        /// How big the button is drawn, and what the state handler moves. DRIVEN:
        /// the button's scale is read off this state on the host's own frames, so
        /// the handler has nothing to aim at and no render carries the movement.
        @State private var press = 1.0

        var body: some View {
            VStack {
                // A state describes the button alone. This closure reads `entered`,
                // which the handler writes, `presses` and `enabled` - so the count
                // follows what was heard and pressed, not the look.
                DebugInfoLabel()

                SectionTitle("On the control, not in a style")

                // TWO OF THEM, SIDE BY SIDE, because the difference is the point:
                // hold each one down and the left crosses to its pressed color
                // while the right arrives at it.
                HStack {
                    // Written on the CONTROL rather than in a style. The states after
                    // the dot are the ones a Button actually enters: .pressed is there,
                    // and .on - which is a Switch's - does not compile.
                    Button(enabled ? "Hold me" : "Disabled")
                        .isEnabled(enabled)
                        .scale($press)
                        .visualState(.pressed) { $0.background(Palette.brand) }
                        .visualState(.disabled) { $0
                            .background(Palette.outline)
                            .textColor(Palette.disabled)
                        }
                        // The color is a setter, which travels under the button's
                        // own motion. The scale is DRIVEN by `press`: the handler
                        // sends the state there over 90ms, and the button follows it.
                        .onVisualStateChanged { state in
                            entered = state.name
                            $press.journey.move(to: state == .pressed ? 0.94 : 1, .eased(.milliseconds(90)))
                        }
                        .onClicked { presses += 1 }

                    // THE SAME STATES, ARRIVING, so the two can be held down side by
                    // side: a visual state travels under the control's own motion, and
                    // `.motion(.none)` is what none of it looks like.
                    Button(enabled ? "Hold me too" : "Disabled")
                        .isEnabled(enabled)
                        .motion(.none)
                        .visualState(.pressed) { $0.background(Palette.brand) }
                        .visualState(.disabled) { $0
                            .background(Palette.outline)
                            .textColor(Palette.disabled)
                        }
                        .onClicked { presses += 1 }
                }
                .spacing(12)
                .horizontalAlignment(.center)

                Switch($enabled)
                    .text("Enabled")
                    .horizontalAlignment(.center)

                Text("entered \(entered) · pressed \(presses) times")
                    .fontSize(13)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)
            }
            .spacing(12)
        }
        """#,
        "WebBrowserPart": #"""
        // Sources/Samples/Media/WebViewSample.swift
        @State private var hasBack = false
        @State private var hasForward = false
        @State private var status = "nothing has loaded yet"
        @State private var answer = ""

        @Aim(WebView.self) private var browser

        var body: some View {
            Grid {
                VStack {
                    // The grid around this reads the status every page that
                    // loads writes, so this closure is built with it.
                    DebugInfoLabel()

                    HStack {
                        Button("Back")
                            .isEnabled(hasBack)
                            .onClicked(.ignoreWhileRunning) { try await browser.goBack() }

                        Button("Forward")
                            .isEnabled(hasForward)
                            .onClicked(.ignoreWhileRunning) { try await browser.goForward() }

                        Button("Reload")
                            .onClicked(.ignoreWhileRunning) { try await browser.reload() }
                    }
                    .horizontalAlignment(.center)
                }
                .gridRow(0)

                // The browser takes the `.fill` row - as tall as the window leaves -
                // and everything around it keeps its own height.
                WebView("https://example.com")
                    .aim(browser)
                    // What the view calls itself to the server. Left unwritten it
                    // is the platform's own browser string.
                    .userAgent("StateUI Gallery")
                    .canGoBack($hasBack)
                    .canGoForward($hasForward)
                    .onNavigating { report in
                        status = "fetching \(report.url)"
                    }
                    .onNavigated { report in
                        status = "\(report.result): \(report.url)"
                    }
                    // The platform killed the web content process and left the
                    // view blank. Nothing else reports it.
                    .onProcessTerminated {
                        status = "the web process died - press Reload"
                    }
                    .gridRow(1)

                Text(status)
                    .gridRow(2)

                Button("Title?")
                    .horizontalAlignment(.center)
                    .onClicked(.ignoreWhileRunning) {
                        answer = try await browser.evaluateJavaScript("document.title")
                    }
                    .gridRow(3)

                Text(answer)
                    .gridRow(4)
            }
            .rows(.auto, .fill, .auto(count: 3))
        }
        """#,
        "WindowBarSample": #"""
        // Sources/Samples/Windows/WindowBarSample.swift
        /// What the gallery's window says on its bar, written by the sample and declared by the window and the sample's page.
        @MainActor
        final class WindowBarState {
            /// The line under the sample page's title.
            @State var subtitle = ""

            /// Whether the window's bar carries "Surprise me" on every page.
            @State var showsSurprise = false
        }

        /// The values shared with the gallery window the sample is in.
        let bar: WindowBarState

        var body: some View {
            VStack {
                TextField(bar.$subtitle)
                    .placeholder("Window subtitle")

                Switch(bar.$showsSurprise)
                    .text("Surprise me on every page")
            }
            // The line under the page's title, wherever its title shows.
            .subtitle(bar.$subtitle)
        }
        """#,
        "WindowLog": #"""
        // Sources/Gallery/WindowLog.swift
        /// What a gallery window has said about its life, numbered, newest last -
        /// kept by the window (`GalleryWindow`), written by `MainPage` as the window
        /// is made and by `WindowPhaseLog` as its phase moves, and read by the
        /// Lifecycle sample.
        @MainActor
        final class WindowLog {
            /// The last six moments, each numbered.
            @State var events: [String] = []

            /// How many moments have come since the window opened - the number in
            /// front of each row, so a repeat plainly reads as a new one.
            @State private(set) var count = 0

            /// Writes one moment in, numbered, keeping the last six - enough to tell
            /// the story without the page growing for ever.
            func note(_ name: String) {
                count += 1
                events = Array((events + ["\(count) · \(name)"]).suffix(6))
            }
        }

        /// The window's phase, one line of the log per moment - a view of its own that
        /// draws nothing, so a phase change builds this rather than the menu holding
        /// it.
        ///
        /// The log's first line is `created`, which `MainPage` writes as the window
        /// is made: `.onChanged` hears a CHANGE, and the phase starts there. The
        /// activated/deactivated pair follows the host's own window activation, and
        /// where the application stands is `application.phase`, which the Phases
        /// sample shows.
        struct WindowPhaseLog: View {
            /// Where the moments are written.
            let log: WindowLog

            /// The window this view stands in, whose phase it follows.
            @Environment(\.window) private var window

            var body: some View {
                Rectangle()
                    .fill(Color(hex: 0x000000, opacity: 0))
                    .width(0)
                    .height(0)
                    .ignoresInput(true)
                    .onChanged(window.phase) { log.note("\(window.phase)") }
            }
        }
        """#,
        "WindowOverlaySample": #"""
        // Sources/Samples/Windows/WindowOverlaySample.swift
        /// Where the gallery is: the window's notice is its state.
        let nav: Navigation

        /// Whether this page's own notice stands over the window.
        @State private var onThisPage = false

        var body: some View {
            VStack {
                switchRow(nav.$windowNotice, "Over every page", id: "window.overlay")
                switchRow($onThisPage, "Over this page", id: "window.overlay.page")
            }
            .overlays {
                if onThisPage {
                    WindowNotice(words: "Over this page", shown: $onThisPage)
                        .verticalAlignment(.end)
                }
            }
        }

        /// A switch and what it says, told apart for scripts by `id`.
        private func switchRow(_ value: Binding<Bool>, _ words: String, id: String) -> some View {
            Switch(value)
                .text(words)
        }

        /// A notice laid over the window: a line with its own way out, at the top unless it says otherwise.
        struct WindowNotice: View {
            let words: String

            /// Whether it stands; its button takes it away.
            @Binding var shown: Bool

            var body: some View {
                HStack {
                    Text(words)
                        .verticalAlignment(.center)
                    Button("Dismiss")
                        .onClicked { shown = false }
                }
                .horizontalAlignment(.center)
                .verticalAlignment(.start)
            }
        }
        """#,
        "WindowPhaseSample": #"""
        // Sources/Samples/Windows/WindowPhaseSample.swift
        /// The application as it runs.
        @Environment(\.application) var application

        /// The galleries - the scene the page is in.
        @Environment(\.scene) var scene

        /// The window this page is in.
        @Environment(\.window) var window

        var body: some View {
            VStack {
                DebugInfoLabel()

                PhaseRow(name: "application", value: "\(application.phase)")   // active, inactive or background
                PhaseRow(name: "the galleries", value: "\(scene.phase)")   // active, inactive or background
                PhaseRow(name: "this window", value: "\(window.phase)")   // from created to destroying

                Text(verdict)
            }
        }

        /// What the three say together.
        private var verdict: String {
            if application.phase == .background {
                return "The application is out of sight."
            }

            if application.phase != .active {
                return "Another application is in front."
            }

            if scene.phase != .active {
                return "Another scene is in front of the galleries."
            }

            return "A gallery window is the one in front."
        }

        /// One phase: whose it is, and where it stands.
        private struct PhaseRow: View {
            let name: String
            let value: String

            var body: some View {
                HStack {
                    Text(name)
                        .width(110)
                        .verticalAlignment(.center)

                    Text(value)
                        .fontWeight(.bold)
                        .verticalAlignment(.center)
                }
                .horizontalAlignment(.center)
            }
        }
        """#,
        "WindowSample": #"""
        // Sources/Samples/Windows/WindowSample.swift
        @Environment(\.window) private var window

        @State private var renames = 0
        @State private var maximizable = true
        @State private var minimizable = true
        @State private var bounded = false
        @State private var width = 0.0
        @State private var height = 0.0

        var body: some View {
            VStack {
                DebugInfoLabel()

                Text(window.title ?? "Platform title")
                    .fontWeight(.bold)

                HStack {
                    action("Rename") {
                        renames += 1
                        window.title = "Gallery \(renames)"
                    }

                    action("Move to 80, 80") {
                        window.x = 80
                        window.y = 80
                    }
                }

                HStack {
                    action("900 × 650") {
                        window.width = 900
                        window.height = 650
                    }

                    action("1100 × 800") {
                        window.width = 1100
                        window.height = 800
                    }
                }

                option("Can maximize", id: "window.maximize", value: $maximizable)
                    .onChanged(maximizable) {
                        window.isMaximizable = maximizable
                    }

                option("Can minimize", id: "window.minimize", value: $minimizable)
                    .onChanged(minimizable) {
                        window.isMinimizable = minimizable
                    }

                // A maximum bounds maximizing too: maximized, the window grows to
                // it at most, and on a Mac it takes no full screen.
                option("At most 1200 × 900", id: "window.bounded", value: $bounded)
                    .onChanged(bounded) {
                        window.maximumWidth = bounded ? 1200 : nil
                        window.maximumHeight = bounded ? 900 : nil
                    }

                Text("Sample frame: \(Int(width)) × \(Int(height))")
            }
            .onFrameChanged(in: .global) { frame in
                width = frame.width
                height = frame.height
            }
        }

        /// An action that writes the surrounding window session.
        private func action(_ title: String, _ write: @escaping () -> Void) -> some View {
            Button(title)
                .onClicked { write() }
        }

        /// A native boolean window capability.
        private func option(_ title: String, id: String, value: Binding<Bool>) -> some View {
            Switch(value)
                .text(title)
        }
        """#,
        "WorkFromCode": #"""
        // Sources/Samples/State/GateSample.swift
        /// A draft that saves through its own gate, whoever asks.
        @MainActor
        final class Draft {
            let saving = Gate(.ignoreWhileRunning)
            @State var saves = 0

            /// Saves, unless a save is under way: the gate lets this one go.
            func save() {
                Task(gate: saving) {
                    try await Task.sleep(for: .milliseconds(1500))
                    self.saves += 1
                }
            }
        }

        @State private var draft = Draft()
        @State private var autosave = Ticker(every: .seconds(3))

        var body: some View {
            VStack {
                Text("Start the autosave, and watch Save dim while it saves.")

                HStack {
                    // No await: the press asks the draft, whose own gate decides.
                    Button("Save")
                        .isEnabled(!draft.saving.isBusy)
                        .onClicked { draft.save() }

                    Button(autosave.isRunning ? "Stop autosave" : "Start autosave")
                        .onClicked { autosave.isRunning ? autosave.stop() : autosave.start() }
                }

                Text(draft.saving.isBusy ? "Saving…" : "Saves: \(draft.saves)")
            }
            .onCreated { autosave.onTick = { draft.save() } }
            .onDestroying { autosave.stop() }
        }
        """#,
        "WrittenInPlacePart": #"""
        // Sources/Samples/Media/WebViewSample.swift
        var body: some View {
            WebView()
                .source(html: "<meta name='viewport' content='width=device-width'><h2>Written in place</h2><p>No network involved.</p>")
        }
        """#,
    ]
}

#if APPKIT || UIKIT || ANDROID || WINUI || GTK || WEB
extension Listings {
    /// The hosts' own code, which only a host's build shows.
    fileprivate static let ofHosts: [String: String] = [
        "Cube3DSample.Android.glsl": #"""
        // Platforms/Android/Swift/Host/GLESCube3DView.swift
        // The vertex shader, compiled for OpenGL ES 3.0: a corner carries its face's brightness in w, and the
        // color is the frame's.
        layout(location = 0) in vec4 corner;
        uniform mat4 transform;
        uniform vec4 color;
        out vec4 painted;
        void main() {
            gl_Position = transform * vec4(corner.xyz, 1.0);
            painted = vec4(color.rgb * corner.w, color.a);
        }

        // The fragment shader: every point of a face takes the color its corners were painted.
        precision mediump float;
        in vec4 painted;
        out vec4 fragment;
        void main() { fragment = painted; }
        """#,
        "Cube3DSample.Android.java": #"""
        // Platforms/Android/Java/com/stateui/gallery/Cube3DView.java
        /**
         * The surface a cube is drawn into by the Swift half, with OpenGL ES: a TextureView, drawn as a view is, so the
         * opacity, transform and clip StateUI puts on every view hold for it. It hands its surface over as it comes and goes,
         * and asks for the display's frames while it spins and stands in a window.
         */
        final class Cube3DView extends TextureView implements TextureView.SurfaceTextureListener, Choreographer.FrameCallback {
            private static final float SIDE = 240;

            private final long control;
            private final float density;
            private Surface surface;
            private boolean spinning = true;
            private boolean following;

            Cube3DView(Context context, long control) {
                super(context);
                this.control = control;
                density = context.getResources().getDisplayMetrics().density;
                setSurfaceTextureListener(this);
            }

            /** Whether the cube turns: frames come only while it does. */
            void setSpinning(boolean value) {
                spinning = value;
                follow();
            }

            @Override
            protected void onMeasure(int width, int height) {
                int side = Math.round(SIDE * density);
                setMeasuredDimension(resolveSize(side, width), resolveSize(side, height));
            }

            @Override
            protected void onAttachedToWindow() {
                super.onAttachedToWindow();
                follow();
            }

            @Override
            protected void onDetachedFromWindow() {
                super.onDetachedFromWindow();
                follow();
            }

            @Override
            public void onSurfaceTextureAvailable(SurfaceTexture texture, int width, int height) {
                surface = new Surface(texture);
                GalleryNatives.surfaceReady(control, surface, width, height);
                follow();
            }

            @Override
            public void onSurfaceTextureSizeChanged(SurfaceTexture texture, int width, int height) {
                if (surface != null) GalleryNatives.surfaceReady(control, surface, width, height);
            }

            @Override
            public boolean onSurfaceTextureDestroyed(SurfaceTexture texture) {
                GalleryNatives.surfaceGone(control);
                surface.release();
                surface = null;
                follow();
                return true;
            }

            @Override
            public void onSurfaceTextureUpdated(SurfaceTexture texture) {}

            @Override
            public void doFrame(long nanoseconds) {
                if (!following) return;
                GalleryNatives.cubeFrame(control, nanoseconds);
                Choreographer.getInstance().postFrameCallback(this);
            }

            /** Asks for frames while the cube spins on a surface in a window, and for none otherwise. */
            private void follow() {
                boolean wanted = spinning && surface != null && isAttachedToWindow();
                if (wanted == following) return;
                following = wanted;
                if (wanted) {
                    Choreographer.getInstance().postFrameCallback(this);
                } else {
                    Choreographer.getInstance().removeFrameCallback(this);
                }
            }
        }

        // Platforms/Android/Java/com/stateui/gallery/GalleryNatives.java
        /**
         * What the gallery's own Android views tell its Swift half, each by the number
         * its control was made with. The Swift half answers each, in Host/GalleryNatives.swift.
         */
        final class GalleryNatives {
            private GalleryNatives() {}

            /** A traffic light's lamp was tapped, counted from the top. */
            static native void lampTapped(long control, int lamp);

            /** A rating bar's user chose a rating. */
            static native void rated(long control, double rating);

            /** A cube's surface came, or changed its size in pixels. */
            static native void surfaceReady(long control, Surface surface, int width, int height);

            /** A cube's surface is going: nothing draws into it once this returns. */
            static native void surfaceGone(long control);

            /** A display frame for a cube, while it asks for them. */
            static native void cubeFrame(long control, long nanoseconds);

            /** A map's user tapped it, where the place under the finger is. */
            static native void mapClicked(long control, double latitude, double longitude);

            /** A map's user chose the marker of {@code number}. */
            static native void markerSelected(long control, long number);

            /** A map's user asked for the details of the marker of {@code number}. */
            static native void markerDetails(long control, long number);

            /** The battery said its level, 0 to 1, and whether it charges. */
            static native void batteryChanged(double level, boolean charging);
        }
        """#,
        "Cube3DSample.Android.swift": #"""
        // Platforms/Android/Swift/Host/GLESCube3DView.swift
        /// A cube drawn with OpenGL ES 3.0 into the surface of the gallery's own Java view, com.stateui.gallery.Cube3DView -
        /// a TextureView that asks for the display's frames while the cube spins and stands in a window. The Swift half is
        /// Sources/Samples/Interop/Cube3D.swift.
        @MainActor
        final class GLESCube3DView: AndroidControl {
            let view: JavaObject

            /// How long the cube's edge is, as a share of the view.
            var cubeSize = 0.6 {
                didSet { if cubeSize != oldValue { draw() } }
            }

            /// Which color it is painted.
            var color = CubeColor.teal {
                didSet { if color != oldValue { draw() } }
            }

            /// Whether it turns. Stopped, it holds the angle it had.
            var isSpinning = true {
                didSet { if isSpinning != oldValue { Java.call(view.reference, Self.setSpinning, .bool(isSpinning)) } }
            }

            private let number: Int64

            /// The surface drawn into, while the view has one: its window, the EGL objects over it, its size in pixels.
            private var drawing: Drawing?

            /// The angle turned, and the display's time of the frame it last turned on - 0 for none yet.
            private var angle = 0.0
            private var lastFrame: Int64 = 0

            private static let viewClass = Java.findClass("com/stateui/gallery/Cube3DView")
            private static let make = Java.method(viewClass, "<init>", "(Landroid/content/Context;J)V")
            private static let setSpinning = Java.method(viewClass, "setSpinning", "(Z)V")

            init() {
                number = GalleryControls.reserve()
                view = Java.new(Self.viewClass, Self.make, .object(StateUIAndroid.context), .long(number))
                GalleryControls.hold(self, as: number)
            }

            isolated deinit {
                drawing?.close()
                GalleryControls.forget(number)
            }

            /// The view's surface came, or changed size: the EGL context and the cube's program are made the first time.
            func surfaceReady(_ surface: jobject?, environment: UnsafeMutablePointer<JNIEnv?>?, width: Int32, height: Int32) {
                if drawing == nil, let surface, let window = ANativeWindow_fromSurface(environment, surface) {
                    drawing = Drawing(window: window)
                }
                drawing?.size = (width, height)
                lastFrame = 0
                draw()
            }

            /// The view's surface is going: nothing is drawn into it again.
            func surfaceGone() {
                drawing?.close()
                drawing = nil
            }

            /// One display frame while spinning: the angle moves by the time since the last, in seconds.
            func frame(at time: Int64) {
                if lastFrame != 0 { angle += Double(time - lastFrame) / 1_000_000_000 }
                lastFrame = time
                draw()
            }

        }

        extension GLESCube3DView {
            /// Adds the cube for `Cube3DContract`. Said once, as the library loads.
            @MainActor
            static func register() {
                StateUIControls.add(Cube3DContract.self, create: { _ in GLESCube3DView() }) { cube in
                    cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
                    cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
                    cube.property(Cube3DContract.isSpinning) { control, spinning in control.isSpinning = spinning ?? true }
                }
            }
        }
        """#,
        "Cube3DSample.AppKit.metal": #"""
        // Platforms/AppKit/Host/MetalCube3DView.swift
        // Compiled as MetalCube3DView is made. A vertex is one float4 - the
        // corner in xyz, the face's brightness in w - so there is no struct
        // whose padding Swift and Metal could measure differently.
        #include <metal_stdlib>
        using namespace metal;

        struct Uniforms {
            float4x4 transform;
            float4 color;
        };

        struct Painted {
            float4 position [[position]];
            float4 color;
        };

        vertex Painted cube_vertex(const device float4 *corners [[buffer(0)]],
                                   constant Uniforms &uniforms [[buffer(1)]],
                                   uint id [[vertex_id]]) {
            float4 corner = corners[id];

            Painted out;
            out.position = uniforms.transform * float4(corner.xyz, 1.0);
            out.color = float4(uniforms.color.rgb * corner.w, 1.0);
            return out;
        }

        fragment float4 cube_fragment(Painted in [[stage_in]]) {
            return in.color;
        }
        """#,
        "Cube3DSample.AppKit.swift": #"""
        // Platforms/AppKit/Host/MetalCube3DView.swift
        /// A cube turning on the GPU - an ordinary `MTKView` that knows nothing of
        /// StateUI.
        ///
        /// `register()`, at the end of this file, adds it for `Cube3DContract`, and
        /// that registration is the whole bridge. The Swift half is
        /// Sources/Samples/Interop/Cube3D.swift.
        ///
        /// Its shaders are compiled FROM SOURCE as the view is made, so the
        /// application ships no `.metal` file and its build needs nothing added to it.
        ///
        /// It renders in `draw(_:)` rather than through an `MTKViewDelegate`: a view
        /// that draws itself needs no second object, and this way the drawing runs
        /// where every other `NSView` draws.
        final class MetalCube3DView: MTKView {
            /// How long the cube's edge is, as a share of the room it is given: 1
            /// turns corner to corner inside the view.
            var cubeSize: Double = 0.6 {
                didSet { if cubeSize != oldValue { drawIfStill() } }
            }

            /// Which color the cube is painted, as the member number the Swift side
            /// sends: teal 0, amber 1, violet 2. Anything else is teal.
            var color: Int32 = 0 {
                didSet { if color != oldValue { drawIfStill() } }
            }

            /// Whether the cube turns. Stopped, it holds the angle it had.
            var isSpinning: Bool = true {
                didSet {
                    guard isSpinning != oldValue else { return }

                    // The clock restarts with the motion, or the time spent stopped
                    // would arrive as one jump.
                    lastTime = CACurrentMediaTime()
                    resumeOrStop()
                }
            }

            private static let colors: [SIMD3<Float>] = [
                SIMD3(0.161, 0.722, 0.678),
                SIMD3(0.961, 0.710, 0.275),
                SIMD3(0.580, 0.443, 0.929),
            ]

            /// The eight corners as six faces, each face two triangles. `xyz` is the
            /// corner and `w` is how brightly that face takes the color - which is
            /// what makes a solid read as a solid.
            private static let corners: [SIMD4<Float>] = {
                let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, Float)] = [
                    (SIMD3(1, -1, -1), SIMD3(1, 1, -1), SIMD3(1, 1, 1), SIMD3(1, -1, 1), 1.00),
                    (SIMD3(-1, -1, -1), SIMD3(-1, 1, -1), SIMD3(-1, 1, 1), SIMD3(-1, -1, 1), 0.55),
                    (SIMD3(-1, 1, -1), SIMD3(1, 1, -1), SIMD3(1, 1, 1), SIMD3(-1, 1, 1), 0.88),
                    (SIMD3(-1, -1, -1), SIMD3(1, -1, -1), SIMD3(1, -1, 1), SIMD3(-1, -1, 1), 0.42),
                    (SIMD3(-1, -1, 1), SIMD3(1, -1, 1), SIMD3(1, 1, 1), SIMD3(-1, 1, 1), 0.97),
                    (SIMD3(-1, -1, -1), SIMD3(1, -1, -1), SIMD3(1, 1, -1), SIMD3(-1, 1, -1), 0.50),
                ]

                return faces.flatMap { a, b, c, d, shade in
                    [a, b, c, a, c, d].map { SIMD4($0.x, $0.y, $0.z, shade) }
                }
            }()

            /// What the vertex function is handed for the whole frame.
            ///
            /// Its layout is the shader's: a 4x4 of floats, then four floats. Both
            /// sides measure 80 bytes, which is what lets it cross as raw bytes.
            private struct Uniforms {
                var transform: simd_float4x4
                var color: SIMD4<Float>
            }

            private let queue: MTLCommandQueue?
            private var pipeline: MTLRenderPipelineState?
            private var depth: MTLDepthStencilState?
            private var mesh: MTLBuffer?

            private var angle: Double = 0
            private var lastTime: CFTimeInterval = CACurrentMediaTime()

            /// The view, its pipeline and its mesh, built once.
            ///
            /// A machine with no Metal device leaves the pipeline empty and the view
            /// draws its background alone - a gallery is worth more than a crash.
            init() {
                let device = MTLCreateSystemDefaultDevice()
                queue = device?.makeCommandQueue()

                super.init(frame: .zero, device: device)

                colorPixelFormat = .bgra8Unorm
                depthStencilPixelFormat = .depth32Float
                clearColor = MTLClearColor(red: 0.102, green: 0.090, blue: 0.145, alpha: 1)
                preferredFramesPerSecond = 60

                wantsLayer = true
                layer?.cornerRadius = 18
                layer?.masksToBounds = true

                guard let device else { return }

                mesh = device.makeBuffer(
                    bytes: Self.corners,
                    length: MemoryLayout<SIMD4<Float>>.stride * Self.corners.count)

                let describedDepth = MTLDepthStencilDescriptor()
                describedDepth.depthCompareFunction = .less
                describedDepth.isDepthWriteEnabled = true
                depth = device.makeDepthStencilState(descriptor: describedDepth)

                pipeline = Self.pipeline(on: device, colorFormat: colorPixelFormat)
            }

            @available(*, unavailable)
            required init(coder: NSCoder) {
                fatalError("MetalCube3DView is created in code")
            }

            /// Square, and big enough to see a solid turn in.
            override var intrinsicContentSize: NSSize {
                NSSize(width: 240, height: 240)
            }

            /// Nothing turns while the view is off screen, and nothing is left turning
            /// behind it: the loop stops with the window it was shown in.
            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()

                lastTime = CACurrentMediaTime()
                resumeOrStop()
            }

            /// One frame: the angle the clock has reached, the cube at the size and
            /// color it was given.
            override func draw(_ dirtyRect: NSRect) {
                let now = CACurrentMediaTime()
                let elapsed = now - lastTime
                lastTime = now

                // Only a turning cube moves with the clock. Stopped, the frame drawn
                // for a changed size or color finds the angle where it was left.
                if isSpinning {
                    angle += elapsed
                }

                guard let pipeline, let mesh, let queue,
                      let pass = currentRenderPassDescriptor,
                      let drawable = currentDrawable,
                      let buffer = queue.makeCommandBuffer(),
                      let encoder = buffer.makeRenderCommandEncoder(descriptor: pass),
                      drawableSize.height > 0
                else { return }

                var uniforms = Uniforms(
                    transform: transform(aspect: Float(drawableSize.width / drawableSize.height)),
                    color: Self.paint(color))

                encoder.setRenderPipelineState(pipeline)
                encoder.setDepthStencilState(depth)
                encoder.setVertexBuffer(mesh, offset: 0, index: 0)
                encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: Self.corners.count)
                encoder.endEncoding()

                buffer.present(drawable)
                buffer.commit()
            }

            /// Where the cube stands, how big it is, and how it is turned - one matrix
            /// the vertex function multiplies each corner by.
            private func transform(aspect: Float) -> simd_float4x4 {
                let scale = Float(max(0, min(1, cubeSize)))
                let turn = Float(angle)

                return Self.perspective(fieldOfView: 50 * .pi / 180, aspect: aspect)
                    * Self.translation(z: -4)
                    * Self.rotation(aroundX: turn * 0.35)
                    * Self.rotation(aroundY: turn * 0.60)
                    * Self.scaling(scale)
            }

            /// The color a member number names, opaque - teal for a number naming
            /// none, so a value from outside the vocabulary paints rather than
            /// vanishes.
            private static func paint(_ color: Int32) -> SIMD4<Float> {
                let index = Int(color)
                let rgb = colors.indices.contains(index) ? colors[index] : colors[0]

                return SIMD4(rgb, 1)
            }

            /// Turning, or stopped where it stands - and never running for a view no
            /// window shows.
            private func resumeOrStop() {
                isPaused = window == nil || !isSpinning
            }

            /// Draws the one frame a stopped cube needs to show a changed size or
            /// color. A turning one is already drawing.
            private func drawIfStill() {
                guard isPaused, window != nil else { return }

                draw()
            }

        }

        // MARK: - Registration

        extension MetalCube3DView {
            /// Adds the cube for `Cube3DContract`. Said once, before the application
            /// runs.
            ///
            /// A view that draws on the GPU registers exactly like one that draws with a
            /// layer: an `MTKView` is an `NSView`. It reports nothing, so `create` only
            /// makes it - every member here goes one way, from the description to the
            /// frames. Every host draws the cube in its own way; a build for no host -
            /// the gallery's own tests - has nothing to draw it with, so it declares no
            /// cube. This file names it with no condition around it because nothing but
            /// an AppKit build compiles this folder.
            @MainActor
            static func register() {
                StateUIControls.add(Cube3DContract.self, create: { _ -> MetalCube3DView in
                    MetalCube3DView()
                }) { cube in
                    cube.property(Cube3DContract.size) { view, size in
                        view.cubeSize = size ?? 0.6
                    }
                    cube.property(Cube3DContract.color) { view, color in
                        view.color = (color ?? .teal).rawValue
                    }
                    cube.property(Cube3DContract.isSpinning) { view, spinning in
                        view.isSpinning = spinning ?? true
                    }
                }
            }
        }
        """#,
        "Cube3DSample.GTK.glsl": #"""
        // Platforms/GTK/Host/OpenGLCube3DWidget.swift
        // GLSL 3.30 core, compiled from source as the area is realized. A corner carries the brightness of its face
        // in w; the color comes with each frame.
        layout(location = 0) in vec4 corner;
        uniform mat4 transform;
        uniform vec4 color;
        out vec4 painted;
        void main() {
            gl_Position = transform * vec4(corner.xyz, 1.0);
            painted = vec4(color.rgb * corner.w, color.a);
        }

        in vec4 painted;
        out vec4 fragment;
        void main() { fragment = painted; }
        """#,
        "Cube3DSample.GTK.swift": #"""
        // Platforms/GTK/Host/OpenGLCube3DWidget.swift
        /// A cube drawn by OpenGL 3.3 core in a `GtkGLArea`, turning on the widget's frame clock - a widget that knows
        /// nothing of StateUI. The Swift half is Sources/Samples/Interop/Cube3D.swift.
        ///
        /// Its GL calls go through libepoxy, the loader GTK itself draws with. A `GTKControl` is an object holding the widget
        /// it shows.
        @MainActor
        final class OpenGLCube3DWidget: GTKControl {
            let widget: UnsafeMutablePointer<GtkWidget>

            /// How long the cube's edge is, as a share of the area.
            var cubeSize = 0.6 {
                didSet { if cubeSize != oldValue { gtk_gl_area_queue_render(area) } }
            }

            /// Which color it is painted.
            var color = CubeColor.teal {
                didSet { if color != oldValue { gtk_gl_area_queue_render(area) } }
            }

            /// Whether it turns. Stopped, it holds the angle it had.
            var isSpinning = true {
                didSet { if isSpinning != oldValue { followClock() } }
            }

            /// An area asking GTK for OpenGL 3.3 core with a depth buffer, its GL made where the widget is realized.
            init() {
                widget = gtk_gl_area_new()
                g_object_ref_sink(widget)
                gtk_widget_set_size_request(widget, 240, 240)
                gtk_gl_area_set_required_version(area, 3, 3)
                gtk_gl_area_set_allowed_apis(area, GDK_GL_API_GL)
                gtk_gl_area_set_has_depth_buffer(area, 1)

                // "realize" compiles the shaders and loads the corners, "render" draws a frame, "unrealize" lets them go,
                // and "map" forgets the last frame, so the cube does not leap by the time it spent off screen.
                // Each a C callback, handed the control as its data: it lives as long as its widget.
                let me = Unmanaged.passUnretained(self).toOpaque()
                let realized: @convention(c) (OpaquePointer?, gpointer?) -> Void = { _, data in
                    MainActor.assumeIsolated { OpenGLCube3DWidget.from(data).realize() }
                }
                let unrealized: @convention(c) (OpaquePointer?, gpointer?) -> Void = { _, data in
                    MainActor.assumeIsolated { OpenGLCube3DWidget.from(data).unrealize() }
                }
                let render: @convention(c) (OpaquePointer?, OpaquePointer?, gpointer?) -> gboolean = { _, _, data in
                    MainActor.assumeIsolated { OpenGLCube3DWidget.from(data).render() }
                }
                let mapped: @convention(c) (OpaquePointer?, gpointer?) -> Void = { _, data in
                    MainActor.assumeIsolated { OpenGLCube3DWidget.from(data).lastFrame = 0 }
                }
                for (signal, handler) in [
                    ("realize", unsafeBitCast(realized, to: GCallback.self)),
                    ("unrealize", unsafeBitCast(unrealized, to: GCallback.self)),
                    ("render", unsafeBitCast(render, to: GCallback.self)),
                    ("map", unsafeBitCast(mapped, to: GCallback.self)),
                ] {
                    g_signal_connect_data(UnsafeMutableRawPointer(widget), signal, handler, me, nil, GConnectFlags(rawValue: 0))
                }
                followClock()
            }

            /// Turns on the widget's frames while spinning: GTK ticks only a mapped widget, so the cube stops behind a page
            /// the user has left. A stopped cube still owes one frame to a value that changed.
            private func followClock() {
                if isSpinning, tick == 0 {
                    lastFrame = 0
                    let turn: @convention(c) (UnsafeMutablePointer<GtkWidget>?, OpaquePointer?, gpointer?) -> gboolean = {
                        _, clock, data in
                        nonisolated(unsafe) let clock = clock
                        return MainActor.assumeIsolated { OpenGLCube3DWidget.from(data).turn(at: gdk_frame_clock_get_frame_time(clock)) }
                    }
                    tick = gtk_widget_add_tick_callback(widget, turn, Unmanaged.passUnretained(self).toOpaque(), nil)
                } else if !isSpinning, tick != 0 {
                    gtk_widget_remove_tick_callback(widget, tick)
                    tick = 0
                }
            }

            /// Clears to the housing's color and draws the cube: turned, scaled and seen in perspective.
            private func render() -> gboolean {
                epoxy_glClearColor(0.102, 0.090, 0.145, 1)
                epoxy_glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
                guard program != 0 else { return 1 }

                epoxy_glEnable(GLenum(GL_DEPTH_TEST))
                epoxy_glUseProgram(program)
                let width = Double(max(gtk_widget_get_width(widget), 1))
                let height = Double(max(gtk_widget_get_height(widget), 1))
                var transform = Self.transform(aspect: width / height, turn: angle, scale: min(max(cubeSize, 0), 1))
                epoxy_glUniformMatrix4fv(transformAt, 1, GLboolean(GL_FALSE), &transform)
                let (red, green, blue) = Self.colors[Int(color.rawValue)]
                epoxy_glUniform4f(colorAt, red, green, blue, 1)
                epoxy_glBindVertexArray(vertexArray)
                epoxy_glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(Self.corners.count / 4))
                return 1
            }

            extension OpenGLCube3DWidget {
                /// Adds the cube for `Cube3DContract`. Said once, before the application runs.
                @MainActor
                static func register() {
                    StateUIControls.add(Cube3DContract.self, create: { _ in OpenGLCube3DWidget() }) { cube in
                        cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
                        cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
                        cube.property(Cube3DContract.isSpinning) { control, spinning in control.isSpinning = spinning ?? true }
                    }
                }
            }
        """#,
        "Cube3DSample.UIKit.metal": #"""
        // Platforms/UIKit/Host/MetalCube3DView.swift
        // The cube's shaders, compiled from this source as the view is made. A
        // corner is one float4: its position in xyz, its face's brightness in w.
        #include <metal_stdlib>
        using namespace metal;

        struct Uniforms {
            float4x4 transform;
            float4 color;
        };

        struct Painted {
            float4 position [[position]];
            float4 color;
        };

        vertex Painted cube_vertex(const device float4 *corners [[buffer(0)]],
                                   constant Uniforms &uniforms [[buffer(1)]],
                                   uint id [[vertex_id]]) {
            float4 corner = corners[id];

            Painted out;
            out.position = uniforms.transform * float4(corner.xyz, 1.0);
            out.color = float4(uniforms.color.rgb * corner.w, 1.0);
            return out;
        }

        fragment float4 cube_fragment(Painted in [[stage_in]]) {
            return in.color;
        }
        """#,
        "Cube3DSample.UIKit.swift": #"""
        // Platforms/UIKit/Host/MetalCube3DView.swift
        /// A cube turning on the GPU - an ordinary `MTKView` that knows nothing of
        /// StateUI.
        ///
        /// `register()`, at the end of this file, adds it for `Cube3DContract`, and
        /// that registration is the whole bridge. The Swift half is
        /// Sources/Samples/Interop/Cube3D.swift.
        ///
        /// Its shaders are compiled FROM SOURCE as the view is made, so the
        /// application ships no `.metal` file and its build needs nothing added to it.
        ///
        /// It renders in `draw(_:)` rather than through an `MTKViewDelegate`: a view
        /// that draws itself needs no second object, and this way the drawing runs
        /// where every other `UIView` draws.
        final class MetalCube3DView: MTKView {

            /// How long the cube's edge is, as a share of the room it is given: 1
            /// turns corner to corner inside the view.
            var cubeSize: Double = 0.6 {
                didSet { if cubeSize != oldValue { drawIfStill() } }
            }

            /// Which color the cube is painted, as the member number the Swift side
            /// sends: teal 0, amber 1, violet 2. Anything else is teal.
            var color: Int32 = 0 {
                didSet { if color != oldValue { drawIfStill() } }
            }

            /// Whether the cube turns. Stopped, it holds the angle it had.
            var isSpinning: Bool = true {
                didSet {
                    guard isSpinning != oldValue else { return }

                    // The clock restarts with the motion, or the time spent stopped
                    // would arrive as one jump.
                    lastTime = CACurrentMediaTime()
                    resumeOrStop()
                }
            }

            /// The view, its pipeline and its mesh, built once.
            ///
            /// A machine with no Metal device leaves the pipeline empty and the view
            /// draws its background alone - a gallery is worth more than a crash.
            init() {
                let device = MTLCreateSystemDefaultDevice()
                queue = device?.makeCommandQueue()

                super.init(frame: .zero, device: device)

                colorPixelFormat = .bgra8Unorm
                depthStencilPixelFormat = .depth32Float
                clearColor = MTLClearColor(red: 0.102, green: 0.090, blue: 0.145, alpha: 1)
                preferredFramesPerSecond = 60

                layer.cornerRadius = 18
                layer.masksToBounds = true

                guard let device else { return }

                mesh = device.makeBuffer(
                    bytes: Self.corners,
                    length: MemoryLayout<SIMD4<Float>>.stride * Self.corners.count)

                let describedDepth = MTLDepthStencilDescriptor()
                describedDepth.depthCompareFunction = .less
                describedDepth.isDepthWriteEnabled = true
                depth = device.makeDepthStencilState(descriptor: describedDepth)

                pipeline = Self.pipeline(on: device, colorFormat: colorPixelFormat)
            }

            /// Nothing turns while the view is off screen, and nothing is left turning
            /// behind it: the loop stops with the window it was shown in.
            override func didMoveToWindow() {
                super.didMoveToWindow()

                lastTime = CACurrentMediaTime()
                resumeOrStop()
            }

            /// One frame: the angle the clock has reached, the cube at the size and
            /// color it was given.
            override func draw(_ rect: CGRect) {
                let now = CACurrentMediaTime()
                let elapsed = now - lastTime
                lastTime = now

                // Only a turning cube moves with the clock. Stopped, the frame drawn
                // for a changed size or color finds the angle where it was left.
                if isSpinning {
                    angle += elapsed
                }

                guard let pipeline, let mesh, let queue,
                      let pass = currentRenderPassDescriptor,
                      let drawable = currentDrawable,
                      let buffer = queue.makeCommandBuffer(),
                      let encoder = buffer.makeRenderCommandEncoder(descriptor: pass),
                      drawableSize.height > 0
                else { return }

                var uniforms = Uniforms(
                    transform: transform(aspect: Float(drawableSize.width / drawableSize.height)),
                    color: Self.paint(color))

                encoder.setRenderPipelineState(pipeline)
                encoder.setDepthStencilState(depth)
                encoder.setVertexBuffer(mesh, offset: 0, index: 0)
                encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: Self.corners.count)
                encoder.endEncoding()

                buffer.present(drawable)
                buffer.commit()
            }

            /// Turning, or stopped where it stands - and never running for a view no
            /// window shows.
            private func resumeOrStop() {
                isPaused = window == nil || !isSpinning
            }

        }

        extension MetalCube3DView {
            /// Adds the cube for `Cube3DContract`. Said once, before the application
            /// runs.
            ///
            /// A view that draws on the GPU registers exactly like one that draws with a
            /// layer: an `MTKView` is a `UIView`. It reports nothing, so `create` only
            /// makes it - every member here goes one way, from the description to the
            /// frames. This file names the cube with no condition around it because
            /// nothing but a UIKit build compiles this folder.
            @MainActor
            static func register() {
                StateUIControls.add(Cube3DContract.self, create: { _ -> MetalCube3DView in
                    MetalCube3DView()
                }) { cube in
                    cube.property(Cube3DContract.size) { view, size in
                        view.cubeSize = size ?? 0.6
                    }
                    cube.property(Cube3DContract.color) { view, color in
                        view.color = (color ?? .teal).rawValue
                    }
                    cube.property(Cube3DContract.isSpinning) { view, spinning in
                        view.isSpinning = spinning ?? true
                    }
                }
            }
        }
        """#,
        "Cube3DSample.Web.javascript": #"""
        // Platforms/Web/Page/cube3d.js
        // <gallery-cube3d>: a cube drawn by WebGL 2 on a canvas of its own, turning on the browser's display frames while
        // it is in view - an element that knows nothing of StateUI. Its attributes say what it is: `size`, the edge as a
        // share of its room from 0 to 1; `color`, 0 teal, 1 amber, 2 violet; `spinning`, present while it turns. The Swift
        // half is Platforms/Web/Host/WebGLCube3DView.swift.

        const colors = [[0.161, 0.722, 0.678], [0.961, 0.710, 0.275], [0.580, 0.443, 0.929]];

        // Six faces of two triangles each, every corner its position and its face's brightness in w.
        const corners = new Float32Array([
          [[[1, -1, -1], [1, 1, -1], [1, 1, 1], [1, -1, 1]], 1.00],
          [[[-1, -1, -1], [-1, 1, -1], [-1, 1, 1], [-1, -1, 1]], 0.55],
          [[[-1, 1, -1], [1, 1, -1], [1, 1, 1], [-1, 1, 1]], 0.88],
          [[[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]], 0.42],
          [[[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]], 0.97],
          [[[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1]], 0.50],
        ].flatMap(([face, shade]) => [0, 1, 2, 0, 2, 3].flatMap((at) => [...face[at], shade])));

        const vertexShader = `#version 300 es
        layout(location = 0) in vec4 corner;
        uniform mat4 transform;
        uniform vec4 color;
        out vec4 painted;
        void main() {
          gl_Position = transform * vec4(corner.xyz, 1.0);
          painted = vec4(color.rgb * corner.w, color.a);
        }`;

        const fragmentShader = `#version 300 es
        precision mediump float;
        in vec4 painted;
        out vec4 fragment;
        void main() { fragment = painted; }`;

        class Cube3D extends HTMLElement {
          static observedAttributes = ["size", "color", "spinning"];

          constructor() {
            super();
            const shadow = this.attachShadow({ mode: "open" });
            shadow.innerHTML = `<style>
              :host { display: block; position: relative; min-width: 240px; min-height: 240px; }
              canvas { position: absolute; inset: 0; width: 100%; height: 100%; display: block; border-radius: inherit; }
              p { position: absolute; inset: 0; margin: auto; height: fit-content; text-align: center; color: #bbb; font: 14px system-ui; }
            </style><canvas></canvas>`;
            this.canvas = shadow.querySelector("canvas");
            this.angle = 0;
            this.lastFrame = 0;
            this.inView = false;
            this.canvas.addEventListener("webglcontextlost", (lost) => { lost.preventDefault(); this.gl = null; });
            this.canvas.addEventListener("webglcontextrestored", () => this.makeContext());
          }

          connectedCallback() {
            if (!this.gl) this.makeContext();
            this.resized = new ResizeObserver(() => this.draw());
            this.resized.observe(this);
            // The cube turns only where the user can see it: behind a page left, it holds its angle.
            this.seen = new IntersectionObserver(([entry]) => {
              this.inView = entry.isIntersecting;
              this.follow();
            });
            this.seen.observe(this);
          }

          disconnectedCallback() {
            this.resized?.disconnect();
            this.seen?.disconnect();
            this.inView = false;
            this.follow();
          }

          attributeChangedCallback() {
            this.follow();
            this.draw();
          }

          get size() { return Math.min(Math.max(Number(this.getAttribute("size") ?? 0.6), 0), 1); }
          get color() { return colors[Number(this.getAttribute("color") ?? 0)] ?? colors[0]; }
          get spinning() { return this.hasAttribute("spinning"); }

          // The shaders, the corners and where the uniforms stand, made in the canvas's own context.
          makeContext() {
            const gl = this.canvas.getContext("webgl2", { antialias: true });
            if (!gl) {
              this.shadowRoot.append(Object.assign(document.createElement("p"), { textContent: "This browser draws no WebGL 2." }));
              return;
            }
            const program = gl.createProgram();
            for (const [kind, source] of [[gl.VERTEX_SHADER, vertexShader], [gl.FRAGMENT_SHADER, fragmentShader]]) {
              const shader = gl.createShader(kind);
              gl.shaderSource(shader, source);
              gl.compileShader(shader);
              gl.attachShader(program, shader);
              gl.deleteShader(shader);
            }
            gl.linkProgram(program);
            const vertexArray = gl.createVertexArray();
            gl.bindVertexArray(vertexArray);
            gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
            gl.bufferData(gl.ARRAY_BUFFER, corners, gl.STATIC_DRAW);
            gl.enableVertexAttribArray(0);
            gl.vertexAttribPointer(0, 4, gl.FLOAT, false, 16, 0);
            this.gl = gl;
            this.program = program;
            this.vertexArray = vertexArray;
            this.transformAt = gl.getUniformLocation(program, "transform");
            this.colorAt = gl.getUniformLocation(program, "color");
            this.draw();
          }

          // Turns on the display's frames while spinning in view; a stopped cube still owes one frame to a value changed.
          follow() {
            const turns = this.spinning && this.inView;
            if (turns && !this.frame) {
              this.lastFrame = 0;
              const turn = (time) => {
                if (this.lastFrame) this.angle += (time - this.lastFrame) / 1000;
                this.lastFrame = time;
                this.draw();
                this.frame = requestAnimationFrame(turn);
              };
              this.frame = requestAnimationFrame(turn);
            } else if (!turns && this.frame) {
              cancelAnimationFrame(this.frame);
              this.frame = 0;
            }
          }

          // Clears to the housing's color and draws the cube: turned, scaled and seen in perspective.
          draw() {
            const gl = this.gl;
            if (!gl) return;
            const ratio = devicePixelRatio || 1;
            const width = Math.max(1, Math.round(this.clientWidth * ratio)), height = Math.max(1, Math.round(this.clientHeight * ratio));
            if (this.canvas.width !== width) this.canvas.width = width;
            if (this.canvas.height !== height) this.canvas.height = height;
            gl.viewport(0, 0, width, height);
            gl.clearColor(0.102, 0.090, 0.145, 1);
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
            gl.enable(gl.DEPTH_TEST);
            gl.useProgram(this.program);
            gl.uniformMatrix4fv(this.transformAt, false, transform(width / height, this.angle, this.size));
            gl.uniform4f(this.colorAt, ...this.color, 1);
            gl.bindVertexArray(this.vertexArray);
            gl.drawArrays(gl.TRIANGLES, 0, corners.length / 4);
          }
        }

        customElements.define("gallery-cube3d", Cube3D);
        """#,
        "Cube3DSample.Web.swift": #"""
        // Platforms/Web/Host/WebGLCube3DView.swift
        /// A cube drawn by WebGL 2 in the page: the gallery's own element, `<gallery-cube3d>` of Page/cube3d.js, which knows
        /// nothing of StateUI - told what it is through its attributes. The Swift half is Sources/Samples/Interop/Cube3D.swift.
        @MainActor
        final class WebGLCube3DView: WebControl {
            let element = WebPageElement(tag: "gallery-cube3d")

            /// How long the cube's edge is, as a share of the element.
            var cubeSize = 0.6 {
                didSet { if cubeSize != oldValue { element.setAttribute("size", String(cubeSize)) } }
            }

            /// Which color it is painted, as the element reads it: the vocabulary's member number.
            var color = CubeColor.teal {
                didSet { if color != oldValue { element.setAttribute("color", String(color.rawValue)) } }
            }

            /// Whether it turns. Stopped, it holds the angle it had.
            var isSpinning = true {
                didSet { if isSpinning != oldValue { element.setAttribute("spinning", isSpinning ? "" : nil) } }
            }

            init() {
                element.setAttribute("size", String(cubeSize))
                element.setAttribute("color", String(color.rawValue))
                element.setAttribute("spinning", "")
            }
        }

        extension WebGLCube3DView {
            /// Adds the cube for `Cube3DContract`. Said once, before the application runs.
            static func register() {
                StateUIControls.add(Cube3DContract.self, create: { _ in WebGLCube3DView() }) { cube in
                    cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
                    cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
                    cube.property(Cube3DContract.isSpinning) { control, spinning in control.isSpinning = spinning ?? true }
                }
            }
        }
        """#,
        "Cube3DSample.WinUI.cpp": #"""
        // Platforms/WinUI/Relay/Cube3D.cpp
        // A cube drawn by Direct3D 11.1 into WinUI's SwapChainPanel - an element that knows nothing of StateUI. Its device
        // asks for feature level 11_1 alone; its swap chain is the panel's, sized in pixels for the panel's scale; it turns
        // on WinUI's frames only while it spins and stands on screen, so nothing turns behind a page the user has left, and
        // a value changed while it stands still draws the one frame it needs.

        namespace {
            // First what a cube draws with: its paints, its shaders, and its device, corners and swap chain - made once, and
            // sized again with the panel by standChain. Then the drawing itself, and the frames it follows.

                /// Clears to the housing's color and draws the cube: turned, scaled and seen in perspective.
                void draw(Cube &cube) {
                    auto panel = cube.panel.get();
                    if (!panel || panel.ActualWidth() < 1 || panel.ActualHeight() < 1) return;
                    standChain(cube, panel);

                    float const housing[4] = {0.102f, 0.090f, 0.145f, 1};
                    auto target = cube.target.get();
                    cube.context->OMSetRenderTargets(1, &target, cube.depth.get());
                    cube.context->ClearRenderTargetView(target, housing);
                    cube.context->ClearDepthStencilView(cube.depth.get(), D3D11_CLEAR_DEPTH, 1, 0);
                    D3D11_VIEWPORT viewport{0, 0, static_cast<float>(cube.width), static_cast<float>(cube.height), 0, 1};
                    cube.context->RSSetViewports(1, &viewport);

                    Frame frame{};
                    transform(double(cube.width) / cube.height, cube.angle, std::clamp(cube.size, 0.0, 1.0), frame.transform);
                    auto const &paint = paints[std::clamp(cube.color, 0, 2)];
                    std::copy(paint, paint + 3, frame.color);
                    frame.color[3] = 1;
                    cube.context->UpdateSubresource(cube.frame.get(), 0, nullptr, &frame, 0, 0);

                    UINT const stride = 4 * sizeof(float), offset = 0;
                    auto corners = cube.corners.get();
                    auto constants = cube.frame.get();
                    cube.context->IASetInputLayout(cube.layout.get());
                    cube.context->IASetVertexBuffers(0, 1, &corners, &stride, &offset);
                    cube.context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
                    cube.context->VSSetShader(cube.vertexShader.get(), nullptr, 0);
                    cube.context->VSSetConstantBuffers(0, 1, &constants);
                    cube.context->PSSetShader(cube.pixelShader.get(), nullptr, 0);
                    cube.context->RSSetState(cube.bothSides.get());
                    cube.context->OMSetDepthStencilState(cube.nearest.get(), 0);
                    cube.context->Draw(36, 0);
                    check_hresult(cube.chain->Present(1, 0));
                }

                /// Follows WinUI's frames while the cube spins and stands on screen, and lets go of them otherwise.
                void followFrames(std::shared_ptr<Cube> const &cube) {
                    auto follows = static_cast<bool>(cube->rendering);
                    if (cube->spinning && cube->shown && !follows) {
                        cube->lastFrame = -1;
                        std::weak_ptr<Cube> weak = cube;
                        cube->rendering = xaml::Media::CompositionTarget::Rendering(
                            [weak](auto const &, winrt::Windows::Foundation::IInspectable const &args) {
                                auto cube = weak.lock();
                                if (!cube) return;
                                try {
                                    auto now = std::chrono::duration<double>(
                                        args.as<xaml::Media::RenderingEventArgs>().RenderingTime()).count();
                                    if (cube->lastFrame >= 0) cube->angle += now - cube->lastFrame;
                                    cube->lastFrame = now;
                                    draw(*cube);
                                } catch (...) {
                                    report("drawing the cube");
                                }
                            });
                    } else if (!(cube->spinning && cube->shown) && follows) {
                        xaml::Media::CompositionTarget::Rendering(cube->rendering);
                        cube->rendering = {};
                    }
                }
            }

            extern "C" GalleryObjectRef gallery_cube_make(void) {
                try {
                    controls::SwapChainPanel panel;
                    panel.MinWidth(240);
                    panel.MinHeight(240);
                    auto cube = std::make_shared<Cube>();
                    cube->panel = winrt::make_weak(panel);
                    std::weak_ptr<Cube> weak = cube;
                    panel.Loaded([weak](auto const &, auto const &) {
                        if (auto cube = weak.lock()) {
                            cube->shown = true;
                            followFrames(cube);
                            try { draw(*cube); } catch (...) { report("drawing the cube"); }
                        }
                    });
                    panel.Unloaded([weak](auto const &, auto const &) {
                        if (auto cube = weak.lock()) {
                            cube->shown = false;
                            followFrames(cube);
                        }
                    });
                    auto redraw = [weak](auto const &, auto const &) {
                        if (auto cube = weak.lock()) {
                            try { draw(*cube); } catch (...) { report("drawing the cube"); }
                        }
                    };
                    panel.SizeChanged(redraw);
                    panel.CompositionScaleChanged(redraw);
                    cubes[identity(panel)] = cube;
                    return detach(panel);
                } catch (...) {
                    report("making a cube");
                    return nullptr;
                }
            }

            extern "C" void gallery_cube_set(GalleryObjectRef handle, double size, int32_t color, bool spinning) {
                try {
                    auto found = cube(handle);
                    if (!found) return;
                    found->size = size;
                    found->color = color;
                    found->spinning = spinning;
                    followFrames(found);
                    if (found->shown) draw(*found);
                } catch (...) {
                    report("setting the cube");
                }
            }
        """#,
        "Cube3DSample.WinUI.hlsl": #"""
        // Platforms/WinUI/Relay/Cube3D.cpp
        // Compiled by D3DCompile as the cube's device is made: `vertex` as vs_5_0, `pixel` as ps_5_0. A corner
        // carries its face's brightness in w; the color is the frame's.
        cbuffer Frame : register(b0) { float4x4 transform; float4 color; };
        struct Corner { float4 at : POSITION; };
        struct Painted { float4 position : SV_POSITION; float4 color : COLOR; };
        Painted vertex(Corner corner) {
            Painted painted;
            painted.position = mul(transform, float4(corner.at.xyz, 1));
            painted.color = float4(color.rgb * corner.at.w, color.a);
            return painted;
        }
        float4 pixel(Painted painted) : SV_TARGET { return painted.color; }
        """#,
        "Cube3DSample.WinUI.swift": #"""
        // Platforms/WinUI/Host/Direct3DCube3DControl.swift
        /// A cube drawn by Direct3D 11.1 in a SwapChainPanel the gallery's relay makes - Platforms/WinUI/Relay/Cube3D.cpp,
        /// an element that knows nothing of StateUI. It turns on WinUI's frames only while it spins and stands on screen.
        /// The Swift half is Sources/Samples/Interop/Cube3D.swift.
        @MainActor
        final class Direct3DCube3DControl: WinUIControl {
            // The relay's SwapChainPanel: a WinUIControl is the object holding the element it shows.
            let element: OpaquePointer

            /// How long the cube's edge is, as a share of the panel.
            var cubeSize = 0.6 {
                didSet { if cubeSize != oldValue { tell() } }
            }

            /// Which color it is painted.
            var color = CubeColor.teal {
                didSet { if color != oldValue { tell() } }
            }

            /// Whether it turns. Stopped, it holds the angle it had.
            var isSpinning = true {
                didSet { if isSpinning != oldValue { tell() } }
            }

            init() {
                element = gallery_cube_make()!
            }

            isolated deinit {
                gallery_cube_close(element)
                gallery_winui_release(element)
            }

                private func tell() {
                    gallery_cube_set(element, cubeSize, color.rawValue, isSpinning)
                }
            }

            // MARK: - Registration

            extension Direct3DCube3DControl {
                /// Adds the cube for `Cube3DContract`. Said once, before the application runs.
                @MainActor
                static func register() {
                    StateUIControls.add(Cube3DContract.self, create: { _ in Direct3DCube3DControl() }) { cube in
                        cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
                        cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
                        cube.property(Cube3DContract.isSpinning) { control, spinning in control.isSpinning = spinning ?? true }
                    }
                }
            }
        """#,
        "InteropActsSample.Android.java": #"""
        // Platforms/Android/Java/com/stateui/gallery/GalleryDevice.java
        /** What the gallery's own acts and events ask of the device: its log and its battery. */
        final class GalleryDevice {
            private GalleryDevice() {}

            /** Writes `line` to Android's log, where logcat reads it. */
            static void log(String line) {
                Log.i("Gallery", line);
            }

            /** The battery's level, 0 to 1 - 0 where the device has none - and 1 where it charges, else 0. */
            static double[] battery(Context context) {
                return reading(context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED)));
            }

            /** Tells each change of the battery - the one standing first - until the receiver is unregistered. */
            static BroadcastReceiver watchBattery(Context context) {
                BroadcastReceiver receiver = new BroadcastReceiver() {
                    @Override
                    public void onReceive(Context context, Intent intent) {
                        double[] battery = reading(intent);
                        GalleryNatives.batteryChanged(battery[0], battery[1] != 0);
                    }
                };
                IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
                if (Build.VERSION.SDK_INT >= 33) {
                    context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
                } else {
                    context.registerReceiver(receiver, filter);
                }
                return receiver;
            }

            /** A battery status read as `battery` gives it: the level, 0 to 1, and 1 where it charges, else 0. */
            private static double[] reading(Intent status) {
                if (status == null) return new double[] {0, 0};
                int level = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
                int scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
                int state = status.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
                boolean charging = state == BatteryManager.BATTERY_STATUS_CHARGING || state == BatteryManager.BATTERY_STATUS_FULL;
                return new double[] {level >= 0 && scale > 0 ? (double) level / scale : 0, charging ? 1 : 0};
            }
        }

        // Platforms/Android/Java/com/stateui/gallery/RatingBarView.java
        /** Fades the bar out and back, as its act asks. */
        void flash() {
            animate().alpha(0.25f).setDuration(120).withEndAction(() -> animate().alpha(1).setDuration(120));
        }
        """#,
        "InteropActsSample.Android.load.swift": #"""
        // Platforms/Android/Swift/GalleryAndroid.swift
        // What Android calls as it loads this library, on the UI thread: the application is named to the host, this head
        // says what it answers for the application - the controls it realizes, the acts it performs, the events it raises,
        // each in Host/ beside this file - and the host registers the native methods its activity calls.
        @_cdecl("JNI_OnLoad")
        public func JNI_OnLoad(_ machine: UnsafeMutableRawPointer?, _ reserved: UnsafeMutableRawPointer?) -> Int32 {
            MainActor.assumeIsolated {
                registerApplication()
                GalleryControls.register()
                GalleryActs.register()
                GalleryEventSources.register()
            }
            return StateUIAndroid.load(machine)
        }
        """#,
        "InteropActsSample.Android.swift": #"""
        // Platforms/Android/Swift/Host/GalleryActs.swift
        /// The acts the gallery performs on this head: its log and its battery, asked of the device through the gallery's
        /// own Java, com.stateui.gallery.GalleryDevice.
        enum GalleryActs {
            /// Registers each act with the host. Said once, as the library loads.
            @MainActor
            static func register() {
                StateUIActs.add(GalleryContract.log) { line in
                    Java.frame { Java.callStatic(Self.device, Self.log, .object(Java.string(line))) }
                }

                StateUIActs.add(GalleryContract.batteryLevel) {
                    // The sticky ACTION_BATTERY_CHANGED, read in GalleryDevice.java.
                    battery()
                }
            }

            /// The battery's level, 0 to 1 - 0 where the device has none - and whether it charges.
            @MainActor
            static func battery() -> (Double, Bool) {
                let reading = Java.frame { () -> [Double] in
                    var values = [0.0, 0.0]
                    guard let array = Java.callStaticObject(Self.device, Self.batteryNow, .object(StateUIAndroid.context))
                    else { return values }
                    values.withUnsafeMutableBufferPointer { Java.jni.GetDoubleArrayRegion(Java.env, array, 0, 2, $0.baseAddress) }
                    return values
                }
                return (reading[0], reading[1] != 0)
            }

            @MainActor private static let device = Java.findClass("com/stateui/gallery/GalleryDevice")
            @MainActor private static let log = Java.staticMethod(device, "log", "(Ljava/lang/String;)V")
            @MainActor private static let batteryNow = Java.staticMethod(device, "battery", "(Landroid/content/Context;)[D")
        }

        // Platforms/Android/Swift/Host/RatingBarView.swift
        extension RatingBarView {
            /// Adds the bar for `RatingBarContract`, and the act aimed at it. Said once, as the library loads.
            @MainActor
            static func register() {
                StateUIControls.add(RatingBarContract.self, create: { reports -> RatingBarView in
                    let bar = RatingBarView()
                    bar.onRatingChanged = { rating in
                        reports.report(RatingBarContract.rating, rating, as: RatingBarContract.ratingChanged)
                    }
                    return bar
                }) { bar in
                    // The stars and the rating come together: a rating stands within the stars, whichever of the two changed.
                    bar.applies(RatingBarContract.maximum, RatingBarContract.rating) { control, values in
                        control.show(
                            rating: values[RatingBarContract.rating] ?? 0, of: Int(values[RatingBarContract.maximum] ?? 5))
                    }
                    bar.raises(RatingBarContract.ratingChanged)
                }

                // An act aimed at a control is its control's: the identity the aim sent is turned back into the control
                // this host made, and the performer is handed that control.
                StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
                    // The Java view fades itself, with its own animate().
                    bar.flash()
                }
            }
        }
        """#,
        "InteropActsSample.AppKit.swift": #"""
        // Platforms/AppKit/Host/GalleryActs.swift
        /// The gallery's own acts, as this host answers them.
        ///
        /// `GalleryContract` declares each name with what it takes and answers - see
        /// Sources/Samples/Interop/GalleryContract.swift - and this is the half that
        /// performs them. An act aimed at a control is its view's, registered beside
        /// it: `RatingBarView.register()` performs `flash`. `Gallery.Nobody` is registered nowhere on purpose: the
        /// "Calling AppKit" sample calls it to show what a missing registration does.
        enum GalleryActs {
            /// Registers every act this host performs. Said once, before the
            /// application runs.
            @MainActor
            static func register() {
                // A performer is handed the arguments its act declares and answers
                // the values it declares.
                StateUIActs.add(GalleryContract.log) { line in
                    Logger(subsystem: "com.stateui.gallery", category: "Gallery").notice("\(line, privacy: .public)")
                }

                StateUIActs.add(GalleryContract.batteryLevel) {
                    battery()
                }
            }

        }

        // Platforms/AppKit/Host/RatingBarView.swift
        extension RatingBarView {
            /// Adds the bar for `RatingBarContract`, and performs the act aimed at
            /// one. Said once, before the application runs.
            @MainActor
            static func register() {

                        // Aimed at one bar: the identity the aim sent is turned back into the
                        // view this host made, and the performer is handed that view.
                        StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
                            bar.flash()
                        }
                    }
                }

        // Platforms/AppKit/main.swift
        // What this host answers for the application, said before it runs: the
        // controls it realizes, the acts it performs, and the pushes it reports. Each
        // lives in Host/ beside this file.
        GalleryControls.register()
        GalleryActs.register()
        GalleryEventSources.start()
        """#,
        "InteropActsSample.GTK.swift": #"""
        // Platforms/GTK/Host/GalleryActs.swift
        /// The gallery's own acts, as this host answers them.
        ///
        /// `GalleryContract` declares each name with what it takes and answers - see
        /// Sources/Samples/Interop/GalleryContract.swift - and this is the half that performs them. An act aimed at a control
        /// is its control's, registered beside it: `RatingBarWidget.register()` performs `flash`. `Gallery.Nobody` is
        /// registered nowhere on purpose: the "Calling GTK" sample calls it to show what a missing registration does.
        enum GalleryActs {
            /// Registers every act this host performs. Said once, before the application runs.
            @MainActor
            static func register() {
                // A performer is handed the arguments its act declares and answers the values it declares.
                // GLib's own log, where journalctl reads it.
                StateUIActs.add(GalleryContract.log) { line in
                    g_log_default_handler("Gallery", STATEUI_LOG_LEVEL_MESSAGE, line, nil)
                }
                // The battery, as UPower tells it on the system bus.
                StateUIActs.add(GalleryContract.batteryLevel) {
                    GalleryPower.battery()
                }
            }

        // Platforms/GTK/Host/RatingBarWidget.swift
        extension RatingBarWidget {
            /// Adds the bar for `RatingBarContract`, and the act aimed at one bar. Said once, before the application runs.
            @MainActor
            static func register() {

                        // Aimed at one bar: the identity the aim sent is turned back into the control this host made for it.
                        // The performer is handed that control, and flash() dims it and brings it back with libadwaita's animation.
                        StateUIActs.add(RatingBarContract.flash, on: RatingBarWidget.self) { bar in
                            bar.flash()
                        }
                    }
                }

        // Platforms/GTK/main.swift
        // Register the gallery module, then say what this host answers for it before it runs: the controls it realizes,
        // the acts it performs, and the pushes it reports - each in Host/ beside this file.
        registerApplication()
        // Each control's own register(), at the end of its file: its widget, and any act aimed at it.
        GalleryControls.register()
        GalleryActs.register()
        GalleryEventSources.start()
        """#,
        "InteropActsSample.UIKit.swift": #"""
        // Platforms/UIKit/Host/GalleryActs.swift
        /// The gallery's own acts, as this host answers them.
        ///
        /// `GalleryContract` declares each name with what it takes and answers - see
        /// Sources/Samples/Interop/GalleryContract.swift - and this is the half that
        /// performs them. An act aimed at a control is its view's, registered beside
        /// it: `RatingBarView.register()` performs `flash`. `Gallery.Nobody` is registered nowhere on purpose: the
        /// "Calling UIKit" sample calls it to show what a missing registration does.
        enum GalleryActs {
            /// Registers every act this host performs. Said once, before the
            /// application runs.
            @MainActor
            static func register() {
                StateUIActs.add(GalleryContract.log) { line in
                    Logger(subsystem: "com.stateui.gallery", category: "Gallery").notice("\(line, privacy: .public)")
                }

                StateUIActs.add(GalleryContract.batteryLevel) {
                    battery()
                }
            }

        }

        // Platforms/UIKit/Host/RatingBarView.swift
        extension RatingBarView {
            /// Adds the bar for `RatingBarContract`, and performs the act aimed at
            /// one. Said once, before the application runs.
            @MainActor
            static func register() {

                        // Aimed at one bar: the identity the aim sent is turned back into the
                        // view this host made, and the performer is handed that view.
                        StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
                            bar.flash()
                        }
                    }
                }

        // Platforms/UIKit/main.swift
        // What this host answers for the application, said before it runs: the
        // controls it realizes, the acts it performs, and the pushes it reports. Each
        // lives in Host/ beside this file.
        GalleryControls.register()
        GalleryActs.register()
        GalleryEventSources.start()

        StateUIUIKit.run()
        """#,
        "InteropActsSample.Web.javascript": #"""
        // Platforms/Web/Page/gallery-acts.js
        // The gallery's own acts as the page's scripts answer them, and what they tell: the browser's console and its
        // battery, wherever the browser offers it. The Swift half is Platforms/Web/Host/GalleryActs.swift and
        // GalleryEventSources.swift.
        // The page loads this script before the application starts.

        // A line for the log: the browser's console, where its developer tools read it.
        StateUI.acts.log = (line) => {
          console.log(line);
          return "";
        };

        // The battery as two words, its level from 0 to 1 and whether it charges; a browser that says nothing of it - a
        // desktop's mains, Safari, Firefox - answers 0.
        const battery = navigator.getBattery?.().catch(() => null) ?? Promise.resolve(null);
        const said = (power) => (power ? `${power.level} ${power.charging}` : "0 false");

        StateUI.acts.batteryLevel = async () => said(await battery);
        """#,
        "InteropActsSample.Web.swift": #"""
        // Platforms/Web/Host/GalleryActs.swift
        /// The gallery's own acts, as this host answers them: through the page's own scripts, Page/gallery-acts.js, which
        /// reach the browser's console and battery.
        ///
        /// `GalleryContract` declares each name with what it takes and answers - see
        /// Sources/Samples/Interop/GalleryContract.swift - and this is the half that performs them. An act aimed at a control
        /// is its control's, registered beside it: `RatingBarElement.register()` performs `flash`. `Gallery.Nobody` is
        /// registered nowhere on purpose: the "Calling Web" sample calls it to show what a missing registration does.
        enum GalleryActs {
            /// Registers every act this host performs. Said once, before the application runs.
            @MainActor
            static func register() {
                StateUIActs.add(GalleryContract.log) { line in
                    _ = try await StateUIScripts.call("log", line)
                }
                StateUIActs.add(GalleryContract.batteryLevel) {
                    battery(try await StateUIScripts.call("batteryLevel"))
                }
            }

            /// The battery as the page's scripts say it - its level from 0 to 1 and whether it charges, two words - 0 where
            /// they say nothing of it.
            static func battery(_ words: String) -> (Double, Bool) {
                let said = words.split(separator: " ")
                return (said.first.flatMap { Double($0) } ?? 0, said.count > 1 && said[1] == "true")
            }
        }

        // Platforms/Web/Host/RatingBarElement.swift
        /// Dims the bar and brings it back: the element's own animation of its opacity.
        func flash() {
            element.call("flash")
        }

        // Aimed at one bar: the identity the aim sent is turned back into the control this host made for it.
        StateUIActs.add(RatingBarContract.flash, on: RatingBarElement.self) { bar in
            bar.flash()
        }
        """#,
        "InteropActsSample.WinUI.cpp": #"""
        // Platforms/WinUI/Relay/System.cpp
        // The battery as Windows knows it: the power status every desktop reads, and the notices Windows sends as the
        // battery's charge or the power source changes.

        // The reading GalleryPower.battery() in the Swift half calls: for the battery act, and after each notice.
        extern "C" void gallery_battery(double *level, bool *charging) {
            try {
                *level = 0;
                *charging = false;
                SYSTEM_POWER_STATUS status{};
                // No system battery, or a charge Windows does not know: nothing to say.
                if (!GetSystemPowerStatus(&status) || (status.BatteryFlag & 128) || status.BatteryLifePercent > 100) return;
                *level = status.BatteryLifePercent / 100.0;
                *charging = status.ACLineStatus == 1;
            } catch (...) {
                report("reading the battery");
            }
        }
        """#,
        "InteropActsSample.WinUI.flash.cpp": #"""
        // Platforms/WinUI/Relay/Controls.cpp
        // The act aimed at the bar: a Storyboard fading WinUI's RatingControl down and back, twice.
        extern "C" void gallery_rating_bar_flash(GalleryObjectRef bar) {
            try {
                auto rating = as<controls::RatingControl>(bar);
                animation::DoubleAnimation fade;
                fade.From(1.0);
                fade.To(0.25);
                fade.Duration(xaml::DurationHelper::FromTimeSpan(std::chrono::milliseconds(120)));
                fade.AutoReverse(true);
                fade.RepeatBehavior(animation::RepeatBehaviorHelper::FromCount(2));
                // Stopped, the opacity is the host's again.
                fade.FillBehavior(animation::FillBehavior::Stop);
                animation::Storyboard::SetTarget(fade, rating);
                animation::Storyboard::SetTargetProperty(fade, L"Opacity");
                animation::Storyboard flash;
                flash.Children().Append(fade);
                flash.Begin();
            } catch (...) {
                report("flashing a rating bar");
            }
        }
        """#,
        "InteropActsSample.WinUI.swift": #"""
        // Platforms/WinUI/Host/GalleryActs.swift
        /// The gallery's own acts, as this host answers them.
        ///
        /// `GalleryContract` declares each name with what it takes and answers - see
        /// Sources/Samples/Interop/GalleryContract.swift - and this is the half that performs them. An act aimed at a control
        /// is its control's, registered beside it: `RatingBarControl.register()` performs `flash`. `Gallery.Nobody` is
        /// registered nowhere on purpose: the "Calling WinUI" sample calls it to show what a missing registration does.
        enum GalleryActs {
            /// Registers every act this host performs. Said once, before the application runs.
            @MainActor
            static func register() {
                // The log needs no relay: Swift calls Win32 itself - OutputDebugStringW, which a debugger reads.
                StateUIActs.add(GalleryContract.log) { line in
                    line.withCString(encodedAs: UTF16.self) { OutputDebugStringW($0) }
                }
                // The power status, GetSystemPowerStatus, read by the gallery's relay.
                StateUIActs.add(GalleryContract.batteryLevel) {
                    GalleryPower.battery()
                }
            }
        }

        // Platforms/WinUI/Host/RatingBarControl.swift
        extension RatingBarControl {
            /// Adds the bar for `RatingBarContract`, and performs its aimed `flash`. Said once, before the application runs.
            @MainActor
            static func register() {

                        // Aimed at one bar: the identity the aim sent is turned back into the control this host made for it.
                        StateUIActs.add(RatingBarContract.flash, on: RatingBarControl.self) { bar in
                            // A Storyboard in the relay fades the bar's opacity down and back, twice.
                            bar.flash()
                        }
                    }
                }

        // Platforms/WinUI/main.swift
        // Before StateUIWinUI.run(): every control - RatingBarControl.register() among them - and every act.
        GalleryControls.register()
        GalleryActs.register()
        """#,
        "InteropControlSample.Android.controls.swift": #"""
        // Platforms/Android/Swift/Host/GalleryControls.swift
        /// Registers every control this host realizes. Said once, as the library loads.
        @MainActor
        static func register() {
            TrafficLightView.register()
            RatingBarView.register()
            GLESCube3DView.register()
            GoogleMapView.register()
        }
        """#,
        "InteropControlSample.Android.java": #"""
        // Platforms/Android/Java/com/stateui/gallery/TrafficLightView.java
        /** Three lamps in a dark housing, one lit; a tap on a lamp is told, and lights nothing by itself. */
        final class TrafficLightView extends View {
            private static final int[] LAMPS = {0xFFE5484D, 0xFFF5B546, 0xFF46B45F};
            private static final float LAMP = 44, SPACING = 10, PADDING = 12;

            private final long control;
            private final float density;
            private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
            private final RectF housing = new RectF();
            private int signal = -1;

            TrafficLightView(Context context, long control) {
                super(context);
                this.control = control;
                density = context.getResources().getDisplayMetrics().density;
                setClickable(true);
            }

            /** Which lamp is lit, from the top; none for any other number. */
            void setSignal(int lamp) {
                if (lamp == signal) return;
                signal = lamp;
                invalidate();
            }

            /** How big it is, which the host asks by measuring it as Android measures any view. */
            @Override
            protected void onMeasure(int width, int height) {
                setMeasuredDimension(
                        resolveSize(Math.round((PADDING * 2 + LAMP) * density), width),
                        resolveSize(Math.round((PADDING * 2 + LAMP * 3 + SPACING * 2) * density), height));
            }

            @Override
            protected void onDraw(Canvas canvas) {
                housing.set(0, 0, getWidth(), getHeight());
                paint.setColor(0xFF1A1725);
                canvas.drawRoundRect(housing, 18 * density, 18 * density, paint);
                for (int lamp = 0; lamp < 3; lamp++) {
                    paint.setColor(lamp == signal ? LAMPS[lamp] : (LAMPS[lamp] & 0x00FFFFFF) | 0x2E000000);
                    canvas.drawCircle(getWidth() / 2f, center(lamp), LAMP / 2 * density, paint);
                }
            }

            /** Tells a tapped lamp to the Swift half by the number it made this view with; whoever owns the state decides. */
            @Override
            public boolean onTouchEvent(MotionEvent event) {
                if (event.getActionMasked() == MotionEvent.ACTION_UP) {
                    for (int lamp = 0; lamp < 3; lamp++) {
                        if (Math.abs(event.getY() - center(lamp)) <= LAMP / 2 * density) {
                            GalleryNatives.lampTapped(control, lamp);
                            break;
                        }
                    }
                }
                return true;
            }

            private float center(int lamp) {
                return (PADDING + LAMP / 2 + lamp * (LAMP + SPACING)) * density;
            }
        }
        """#,
        "InteropControlSample.Android.natives.java": #"""
        // Platforms/Android/Java/com/stateui/gallery/GalleryNatives.java
        /**
         * What the gallery's own Android views tell its Swift half, each by the number
         * its control was made with. The Swift half answers each, in Host/GalleryNatives.swift.
         */
        final class GalleryNatives {
            private GalleryNatives() {}

            /** A traffic light's lamp was tapped, counted from the top. */
            static native void lampTapped(long control, int lamp);

            /** A rating bar's user chose a rating. */
            static native void rated(long control, double rating);

            /** A cube's surface came, or changed its size in pixels. */
            static native void surfaceReady(long control, Surface surface, int width, int height);

            /** A cube's surface is going: nothing draws into it once this returns. */
            static native void surfaceGone(long control);

            /** A display frame for a cube, while it asks for them. */
            static native void cubeFrame(long control, long nanoseconds);

            /** A map's user tapped it, where the place under the finger is. */
            static native void mapClicked(long control, double latitude, double longitude);

            /** A map's user chose the marker of {@code number}. */
            static native void markerSelected(long control, long number);

            /** A map's user asked for the details of the marker of {@code number}. */
            static native void markerDetails(long control, long number);

            /** The battery said its level, 0 to 1, and whether it charges. */
            static native void batteryChanged(double level, boolean charging);
        }
        """#,
        "InteropControlSample.Android.swift": #"""
        // Platforms/Android/Swift/Host/TrafficLightView.swift
        /// Three lamps in a dark housing, one lit: the gallery's own Java view, com.stateui.gallery.TrafficLightView, which
        /// knows nothing of StateUI. The Swift half is Sources/Samples/Interop/TrafficLight.swift.
        @MainActor
        final class TrafficLightView: AndroidControl {
            let view: JavaObject

            /// A lamp was tapped; the argument is its index, top to bottom. The light does not switch itself: it reports,
            /// and whoever owns the state decides.
            var onLampTapped: ((Int) -> Void)?

            /// Which lamp is lit.
            var signal = TrafficSignal.stop {
                didSet { if signal != oldValue { Java.call(view.reference, Self.setSignal, .int(signal.rawValue)) } }
            }

            private let number: Int64

            private static let viewClass = Java.findClass("com/stateui/gallery/TrafficLightView")
            private static let make = Java.method(viewClass, "<init>", "(Landroid/content/Context;J)V")
            private static let setSignal = Java.method(viewClass, "setSignal", "(I)V")

            init() {
                number = GalleryControls.reserve()
                view = Java.new(Self.viewClass, Self.make, .object(StateUIAndroid.context), .long(number))
                Java.call(view.reference, Self.setSignal, .int(signal.rawValue))
                GalleryControls.hold(self, as: number)
            }

            isolated deinit {
                GalleryControls.forget(number)
            }

            /// The view says lamp `index` was tapped.
            /// It reaches here through a native method of the gallery's, GalleryNatives.lampTapped, by this control's number.
            func tapped(_ index: Int) {
                onLampTapped?(index)
            }
        }

        extension TrafficLightView {
            /// Adds the light for `TrafficLightContract`: `create` makes the control once per element and wires the tap it
            /// reports, and `property` puts the described signal on it. Said once, as the library loads.
            @MainActor
            static func register() {
                StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
                    let light = TrafficLightView()
                    light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
                    return light
                }) { light in
                    light.property(TrafficLightContract.signal) { control, signal in
                        control.signal = signal ?? .stop
                    }
                    light.raises(TrafficLightContract.lampTapped)
                }
            }
        }
        """#,
        "InteropControlSample.AppKit.list.swift": #"""
        // Platforms/AppKit/Host/GalleryControls.swift
        /// The gallery's own controls, as this host realizes them.
        ///
        /// The contracts and the Swift halves are shared by every host - see
        /// Sources/Samples/Interop. What each control IS on screen is its view's, and
        /// so is its registration: `register()` at the end of the view's own file.
        /// This is the list of them, and nothing else.
        enum GalleryControls {
            /// Registers every control this host realizes. Said once, before the
            /// application runs.
            @MainActor
            static func register() {
                TrafficLightView.register()
                RatingBarView.register()
                MetalCube3DView.register()
            }
        }
        """#,
        "InteropControlSample.AppKit.swift": #"""
        // Platforms/AppKit/Host/TrafficLightView.swift
        /// Three lamps in a housing, one lit at a time - an ordinary `NSView` that
        /// knows nothing of StateUI.
        ///
        /// `register()`, at the end of this file, adds it for `TrafficLightContract`,
        /// and that registration is the whole bridge. The Swift half is
        /// Sources/Samples/Interop/TrafficLight.swift.
        final class TrafficLightView: NSView {
            /// A lamp was tapped; the argument is its index, top to bottom.
            ///
            /// The control does not switch itself: it reports, and whoever owns the
            /// state decides.
            var onLampTapped: ((Int) -> Void)?

            /// Which lamp is lit, as the member number the Swift side sends: stop 0,
            /// caution 1, go 2. Anything else - the initial -1 included - lights
            /// nothing.
            var signal: Int32 = -1 {
                didSet { if signal != oldValue { repaint() } }
            }

            private static let lampColors = [
                NSColor(srgbRed: 0.898, green: 0.282, blue: 0.302, alpha: 1),
                NSColor(srgbRed: 0.961, green: 0.710, blue: 0.275, alpha: 1),
                NSColor(srgbRed: 0.275, green: 0.706, blue: 0.373, alpha: 1),
            ]

            private static let lampSide: CGFloat = 44
            private static let spacing: CGFloat = 10
            private static let padding: CGFloat = 12

            private var lamps: [NSView] = []

            override var isFlipped: Bool { true }

            /// The housing and its three lamps, wired once.
            init() {
                super.init(frame: .zero)

                wantsLayer = true
                layer?.backgroundColor = NSColor(srgbRed: 0.102, green: 0.090, blue: 0.145, alpha: 1).cgColor
                layer?.cornerRadius = 18

                for _ in 0..<3 {
                    let lamp = NSView()
                    lamp.wantsLayer = true
                    lamp.layer?.cornerRadius = Self.lampSide / 2
                    addSubview(lamp)
                    lamps.append(lamp)
                }

                // ONE recognizer on the housing, the lamp read from the click's
                // position - nothing to keep in step with the layout.
                let click = NSClickGestureRecognizer(target: self, action: #selector(clicked(_:)))
                addGestureRecognizer(click)
                repaint()
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) {
                fatalError("TrafficLightView is created in code")
            }

            /// As tall as its three lamps and their padding, and as wide as one.
            override var intrinsicContentSize: NSSize {
                NSSize(
                    width: Self.padding * 2 + Self.lampSide,
                    height: Self.padding * 2 + Self.lampSide * 3 + Self.spacing * 2)
            }

            override func layout() {
                super.layout()

                for (index, lamp) in lamps.enumerated() {
                    lamp.frame = NSRect(
                        x: (bounds.width - Self.lampSide) / 2,
                        y: Self.padding + CGFloat(index) * (Self.lampSide + Self.spacing),
                        width: Self.lampSide,
                        height: Self.lampSide)
                }
            }

            /// Which lamp the click landed on, reported - the state decides what is
            /// lit next.
            @objc private func clicked(_ recognizer: NSClickGestureRecognizer) {
                let at = recognizer.location(in: self)

                for (index, lamp) in lamps.enumerated() where lamp.frame.contains(at) {
                    onLampTapped?(index)
                    return
                }
            }

            /// The lit lamp at full color, the others dimmed to embers.
            private func repaint() {
                for (index, lamp) in lamps.enumerated() {
                    let color = Self.lampColors[index]
                    lamp.layer?.backgroundColor = Int32(index) == signal
                        ? color.cgColor
                        : color.withAlphaComponent(0.18).cgColor
                }
            }
        }

        // MARK: - Registration

        extension TrafficLightView {
            /// Adds the light for `TrafficLightContract`: `create` makes the view once
            /// per element and wires the tap it reports, and `property` puts the
            /// described signal on it. Said once, before the application runs.
            @MainActor
            static func register() {
                StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
                    let light = TrafficLightView()
                    light.onLampTapped = { index in
                        reports.raise(TrafficLightContract.lampTapped, index)
                    }
                    return light
                }) { light in
                    light.property(TrafficLightContract.signal) { view, signal in
                        view.signal = (signal ?? .stop).rawValue
                    }
                    light.raises(TrafficLightContract.lampTapped)
                }
            }
        }
        """#,
        "InteropControlSample.GTK.swift": #"""
        // Platforms/GTK/Host/TrafficLightWidget.swift
        /// Three lamps in a housing, one lit at a time - a `GtkDrawingArea` that knows nothing of StateUI.
        ///
        /// `register()`, at the end of this file, adds it for `TrafficLightContract`, and that registration is the whole
        /// bridge. The Swift half is Sources/Samples/Interop/TrafficLight.swift.
        ///
        /// A `GTKControl` is an object holding the widget it shows.
        @MainActor
        final class TrafficLightWidget: GTKControl {
            let widget: UnsafeMutablePointer<GtkWidget>

            /// A lamp was tapped; the argument is its index, top to bottom. The control does not switch itself: it reports,
            /// and whoever owns the state decides.
            var onLampTapped: ((Int) -> Void)?

            /// Which lamp is lit.
            var signal = TrafficSignal.stop {
                didSet { if signal != oldValue { gtk_widget_queue_draw(widget) } }
            }

            private static let lampColors: [(red: Double, green: Double, blue: Double)] = [
                (0.898, 0.282, 0.302), (0.961, 0.710, 0.275), (0.275, 0.706, 0.373),
            ]
            private static let lampSide = 44.0
            private static let spacing = 10.0
            private static let padding = 12.0

            private let click: OpaquePointer

            /// The housing and its three lamps, drawn by cairo, and one click gesture read by where it lands.
            init() {
                widget = gtk_drawing_area_new()
                g_object_ref_sink(widget)
                click = gtk_gesture_click_new()
                let area = UnsafeMutablePointer<GtkDrawingArea>(OpaquePointer(widget))
                gtk_drawing_area_set_content_width(area, Int32(Self.padding * 2 + Self.lampSide))
                gtk_drawing_area_set_content_height(area, Int32(Self.padding * 2 + Self.lampSide * 3 + Self.spacing * 2))

                // A C callback carries no context: the control rides along as its data, and lives as long as the widget.
                let me = Unmanaged.passUnretained(self).toOpaque()
                gtk_drawing_area_set_draw_func(area, { _, cairo, width, height, data in
                    nonisolated(unsafe) let cairo = cairo
                    MainActor.assumeIsolated {
                        Unmanaged<TrafficLightWidget>.fromOpaque(data!).takeUnretainedValue()
                            .draw(cairo, width: Double(width), height: Double(height))
                    }
                }, me, nil)

                let released: @convention(c) (OpaquePointer?, Int32, Double, Double, gpointer?) -> Void = { _, _, x, y, data in
                    MainActor.assumeIsolated {
                        Unmanaged<TrafficLightWidget>.fromOpaque(data!).takeUnretainedValue().clicked(x: x, y: y)
                    }
                }
                g_signal_connect_data(
                    UnsafeMutableRawPointer(click), "released", unsafeBitCast(released, to: GCallback.self), me, nil,
                    GConnectFlags(rawValue: 0))
                gtk_widget_add_controller(widget, click)
            }

            extension TrafficLightWidget {
                /// Adds the light for `TrafficLightContract`: `create` makes the control once per element and wires the tap it
                /// reports, and `property` puts the described signal on it. Said once, before the application runs.
                @MainActor
                static func register() {
                    StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightWidget in
                        let light = TrafficLightWidget()
                        light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
                        return light
                    }) { light in
                        // Handed back typed - a TrafficSignal, not its number.
                        light.property(TrafficLightContract.signal) { control, signal in
                            control.signal = signal ?? .stop
                        }
                        light.raises(TrafficLightContract.lampTapped)
                    }
                }
            }
        """#,
        "InteropControlSample.UIKit.list.swift": #"""
        // Platforms/UIKit/Host/GalleryControls.swift
        /// The gallery's own controls, as this host realizes them.
        ///
        /// The contracts and the Swift halves are shared by every host - see
        /// Sources/Samples/Interop. What each control IS on screen is its view's, and
        /// so is its registration: `register()` at the end of the view's own file.
        /// This is the list of them, and nothing else.
        enum GalleryControls {
            /// Registers every control this host realizes. Said once, before the
            /// application runs.
            @MainActor
            static func register() {
                TrafficLightView.register()
                RatingBarView.register()
                MetalCube3DView.register()
            }
        }
        """#,
        "InteropControlSample.UIKit.swift": #"""
        // Platforms/UIKit/Host/TrafficLightView.swift
        /// Three lamps in a housing, one lit at a time - an ordinary `UIView` that
        /// knows nothing of StateUI.
        ///
        /// `register()`, at the end of this file, adds it for `TrafficLightContract`,
        /// and that registration is the whole bridge. The Swift half is
        /// Sources/Samples/Interop/TrafficLight.swift.
        final class TrafficLightView: UIView {

            /// A lamp was tapped; the argument is its index, top to bottom.
            ///
            /// The control does not switch itself: it reports, and whoever owns the
            /// state decides.
            var onLampTapped: ((Int) -> Void)?

            /// Which lamp is lit, as the member number the Swift side sends: stop 0,
            /// caution 1, go 2. Anything else - the initial -1 included - lights
            /// nothing.
            var signal: Int32 = -1 {
                didSet { if signal != oldValue { repaint() } }
            }

            /// The housing and its three lamps, wired once.
            init() {
                super.init(frame: .zero)

                backgroundColor = UIColor(red: 0.102, green: 0.090, blue: 0.145, alpha: 1)
                layer.cornerRadius = 18

                for _ in 0..<3 {
                    let lamp = UIView()
                    lamp.layer.cornerRadius = Self.lampSide / 2
                    lamp.isUserInteractionEnabled = false
                    addSubview(lamp)
                    lamps.append(lamp)
                }

                // One recognizer on the housing, the lamp read from where the tap lands.
                addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
                repaint()
            }

            /// As tall as its three lamps and their padding, and as wide as one.
            override func sizeThatFits(_ size: CGSize) -> CGSize {
                CGSize(
                    width: Self.padding * 2 + Self.lampSide,
                    height: Self.padding * 2 + Self.lampSide * 3 + Self.spacing * 2)
            }

            /// The lit lamp at full color, the others dimmed to embers.
            private func repaint() {
                for (index, lamp) in lamps.enumerated() {
                    let color = Self.lampColors[index]
                    lamp.backgroundColor = Int32(index) == signal ? color : color.withAlphaComponent(0.18)
                }
            }

        }

        extension TrafficLightView {
            /// Adds the light for `TrafficLightContract`: `create` makes the view once
            /// per element and wires the tap it reports, and `property` puts the
            /// described signal on it. Said once, before the application runs.
            @MainActor
            static func register() {
                StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
                    let light = TrafficLightView()
                    light.onLampTapped = { index in
                        reports.raise(TrafficLightContract.lampTapped, index)
                    }
                    return light
                }) { light in
                    light.property(TrafficLightContract.signal) { view, signal in
                        view.signal = (signal ?? .stop).rawValue
                    }
                    light.raises(TrafficLightContract.lampTapped)
                }
            }
        }
        """#,
        "InteropControlSample.Web.javascript": #"""
        // Platforms/Web/Page/traffic-light.js
        // <gallery-traffic-light>: three lamps in a housing, one lit at a time - an element that knows nothing of StateUI.
        // Its `signal` attribute says which lamp is lit, 0 red, 1 amber, 2 green; a tap on a lamp raises `lamptap`, its
        // `detail` the lamp's index top to bottom. It does not switch itself: whoever owns the state decides. The Swift
        // half is Platforms/Web/Host/TrafficLightElement.swift.

        class TrafficLight extends HTMLElement {
          static observedAttributes = ["signal"];

          constructor() {
            super();
            // A housing and three lamp buttons in its shadow root, each raising `lamptap` with its index as it is tapped.
            const shadow = this.attachShadow({ mode: "open" });
            shadow.innerHTML = `<style>
              :host { display: inline-grid; gap: 10px; padding: 12px; border-radius: 16px; background: #1a1725; }
              button { width: 44px; height: 44px; padding: 0; border: 0; border-radius: 50%; cursor: pointer;
                background: var(--lamp); opacity: 0.22; transition: opacity 0.15s ease, box-shadow 0.15s ease; }
              button[aria-pressed="true"] { opacity: 1; box-shadow: 0 0 18px var(--lamp); }
              button:focus-visible { outline: 2px solid white; outline-offset: 2px; }
            </style>`;
            ["#e5484d", "#f5b546", "#46b45f"].forEach((lamp, index) => {
              const button = document.createElement("button");
              button.style.setProperty("--lamp", lamp);
              button.setAttribute("aria-label", ["Red", "Amber", "Green"][index]);
              button.addEventListener("click", () => this.dispatchEvent(new CustomEvent("lamptap", { detail: index })));
              shadow.append(button);
            });
            this.show();
          }

          attributeChangedCallback() {
            this.show();
          }

          show() {
            const lit = Number(this.getAttribute("signal") ?? 0);
            this.shadowRoot.querySelectorAll("button").forEach((lamp, index) => lamp.setAttribute("aria-pressed", String(index === lit)));
          }
        }

        customElements.define("gallery-traffic-light", TrafficLight);
        """#,
        "InteropControlSample.Web.swift": #"""
        // Platforms/Web/Host/TrafficLightElement.swift
        /// Three lamps in a housing, one lit at a time: the gallery's own element, `<gallery-traffic-light>` of
        /// Page/traffic-light.js, which knows nothing of StateUI.
        /// Told what it is through its attributes, heard through the events it raises.
        ///
        /// `register()`, at the end of this file, adds it for `TrafficLightContract`, and that registration is the whole
        /// bridge. The Swift half is Sources/Samples/Interop/TrafficLight.swift.
        @MainActor
        final class TrafficLightElement: WebControl {
            let element = WebPageElement(tag: "gallery-traffic-light")

            /// A lamp was tapped; the argument is its index, top to bottom. The control does not switch itself: it reports,
            /// and whoever owns the state decides.
            var onLampTapped: ((Int) -> Void)?

            /// Which lamp is lit.
            var signal = TrafficSignal.stop {
                didSet { if signal != oldValue { element.setAttribute("signal", String(signal.rawValue)) } }
            }

            init() {
                element.setAttribute("signal", String(signal.rawValue))
                element.listen("lamptap", number: { [weak self] index in self?.onLampTapped?(Int(index)) })
            }
        }

        extension TrafficLightElement {
            /// Adds the lamps for `TrafficLightContract`. Said once, before the application runs.
            static func register() {
                StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightElement in
                    let light = TrafficLightElement()
                    light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
                    return light
                }) { light in
                    // The value arrives typed - a TrafficSignal, not its number.
                    light.property(TrafficLightContract.signal) { control, signal in
                        control.signal = signal ?? .stop
                    }
                    light.raises(TrafficLightContract.lampTapped)
                }
            }
        }
        """#,
        "InteropControlSample.WinUI.cpp": #"""
        // Platforms/WinUI/Relay/Controls.cpp
        // The gallery's traffic light and rating bar as WinUI elements that know nothing of StateUI: a housing of three
        // lamps drawn with XAML's shapes, and WinUI's own RatingControl.
        // Each function is C++/WinRT behind the C name the Swift half calls, declared in include/CGalleryWinUI.h.

        // The housing and its lamps. A tap is told through the callbacks the Swift half handed over, by the number it made
        // the control with.
        extern "C" GalleryObjectRef gallery_traffic_light_make(int64_t control) {
            try {
                controls::Border housing;
                housing.Background(brush(26, 23, 37));
                housing.CornerRadius(xaml::CornerRadius{18, 18, 18, 18});
                housing.Padding(xaml::Thickness{12, 12, 12, 12});
                housing.HorizontalAlignment(xaml::HorizontalAlignment::Center);
                controls::StackPanel lamps;
                lamps.Spacing(10);
                for (int32_t lamp = 0; lamp < 3; ++lamp) {
                    shapes::Ellipse ellipse;
                    ellipse.Width(44);
                    ellipse.Height(44);
                    ellipse.Fill(brush(lampColors[lamp][0], lampColors[lamp][1], lampColors[lamp][2]));
                    ellipse.Opacity(lamp == 0 ? 1 : 0.18);
                    xaml::Automation::AutomationProperties::SetName(ellipse, lampNames[lamp]);
                    // The light does not switch itself: it reports, and whoever owns the state decides.
                    ellipse.Tapped([control, lamp](auto const &, xaml::Input::TappedRoutedEventArgs const &args) {
                        args.Handled(true);
                        if (callbacks.lampTapped) callbacks.lampTapped(control, lamp);
                    });
                    lamps.Children().Append(ellipse);
                }
                housing.Child(lamps);
                return detach(housing);
            } catch (...) {
                report("making a traffic light");
                return nullptr;
            }
        }

        extern "C" void gallery_traffic_light_set_signal(GalleryObjectRef light, int32_t signal) {
            try {
                auto lamps = as<controls::Border>(light).Child().as<controls::StackPanel>().Children();
                for (uint32_t lamp = 0; lamp < lamps.Size(); ++lamp) {
                    lamps.GetAt(lamp).as<xaml::UIElement>().Opacity(static_cast<int32_t>(lamp) == signal ? 1 : 0.18);
                }
            } catch (...) {
                report("lighting a lamp");
            }
        }
        """#,
        "InteropControlSample.WinUI.swift": #"""
        // Platforms/WinUI/Host/TrafficLightControl.swift
        /// Three lamps in a housing, one lit at a time - a XAML Border of three Ellipses the gallery's relay makes, which
        /// knows nothing of StateUI.
        ///
        /// `register()`, at the end of this file, adds it for `TrafficLightContract`, and that registration is the whole
        /// bridge. The Swift half is Sources/Samples/Interop/TrafficLight.swift.
        @MainActor
        final class TrafficLightControl: WinUIControl {
            // The relay's Border, made by C++/WinRT behind C functions: a WinUIControl is the object holding the element it
            // shows.
            let element: OpaquePointer

            /// A lamp was tapped; the argument is its index, top to bottom. The control does not switch itself: it reports,
            /// and whoever owns the state decides.
            var onLampTapped: ((Int) -> Void)?

            /// Which lamp is lit.
            var signal = TrafficSignal.stop {
                didSet { if signal != oldValue { gallery_traffic_light_set_signal(element, signal.rawValue) } }
            }

            private let number: Int64

            init() {
                // The relay tells a tap by the number the control makes its element with.
                number = GalleryControls.reserve()
                element = gallery_traffic_light_make(number)!
                GalleryControls.hold(self, as: number)
            }

            isolated deinit {
                GalleryControls.forget(number)
                gallery_winui_release(element)
            }

            /// The relay says lamp `index` was tapped.
            func tapped(_ index: Int) {
                onLampTapped?(index)
            }
        }

        // MARK: - Registration

        extension TrafficLightControl {
            /// Adds the light for `TrafficLightContract`: `create` makes the control once per element and wires the tap it
            /// reports, and `property` puts the described signal on it. Said once, before the application runs.
            @MainActor
            static func register() {
                StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightControl in
                    let light = TrafficLightControl()
                    light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
                    return light
                }) { light in
                    // Handed back typed - a TrafficSignal, not its number.
                    light.property(TrafficLightContract.signal) { control, signal in
                        control.signal = signal ?? .stop
                    }
                    light.raises(TrafficLightContract.lampTapped)
                }
            }
        }
        """#,
        "InteropEventsSample.Android.java": #"""
        // Platforms/Android/Java/com/stateui/gallery/GalleryActivity.java
        /** The gallery's activity: the host's own, and the battery watched while it lives, for the gallery's own event. */
        public final class GalleryActivity extends StateUIActivity {
            private BroadcastReceiver battery;

            @Override
            protected void onCreate(Bundle state) {
                super.onCreate(state);
                battery = GalleryDevice.watchBattery(this);
            }

            @Override
            protected void onDestroy() {
                unregisterReceiver(battery);
                super.onDestroy();
            }
        }

        // Platforms/Android/Java/com/stateui/gallery/GalleryDevice.java
        /** What the gallery's own acts and events ask of the device: its log and its battery. */
        final class GalleryDevice {
            private GalleryDevice() {}

            /** Writes `line` to Android's log, where logcat reads it. */
            static void log(String line) {
                Log.i("Gallery", line);
            }

            /** The battery's level, 0 to 1 - 0 where the device has none - and 1 where it charges, else 0. */
            static double[] battery(Context context) {
                return reading(context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED)));
            }

            /** Tells each change of the battery - the one standing first - until the receiver is unregistered. */
            static BroadcastReceiver watchBattery(Context context) {
                BroadcastReceiver receiver = new BroadcastReceiver() {
                    @Override
                    public void onReceive(Context context, Intent intent) {
                        double[] battery = reading(intent);
                        GalleryNatives.batteryChanged(battery[0], battery[1] != 0);
                    }
                };
                IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
                if (Build.VERSION.SDK_INT >= 33) {
                    context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
                } else {
                    context.registerReceiver(receiver, filter);
                }
                return receiver;
            }

            /** A battery status read as `battery` gives it: the level, 0 to 1, and 1 where it charges, else 0. */
            private static double[] reading(Intent status) {
                if (status == null) return new double[] {0, 0};
                int level = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
                int scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
                int state = status.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
                boolean charging = state == BatteryManager.BATTERY_STATUS_CHARGING || state == BatteryManager.BATTERY_STATUS_FULL;
                return new double[] {level >= 0 && scale > 0 ? (double) level / scale : 0, charging ? 1 : 0};
            }
        }

        // Platforms/Android/Java/com/stateui/gallery/GalleryNatives.java
        /**
         * What the gallery's own Android views tell its Swift half, each by the number
         * its control was made with. The Swift half answers each, in Host/GalleryNatives.swift.
         */
        final class GalleryNatives {
            private GalleryNatives() {}

            /** A traffic light's lamp was tapped, counted from the top. */
            static native void lampTapped(long control, int lamp);

            /** A rating bar's user chose a rating. */
            static native void rated(long control, double rating);

            /** A cube's surface came, or changed its size in pixels. */
            static native void surfaceReady(long control, Surface surface, int width, int height);

            /** A cube's surface is going: nothing draws into it once this returns. */
            static native void surfaceGone(long control);

            /** A display frame for a cube, while it asks for them. */
            static native void cubeFrame(long control, long nanoseconds);

            /** A map's user tapped it, where the place under the finger is. */
            static native void mapClicked(long control, double latitude, double longitude);

            /** A map's user chose the marker of {@code number}. */
            static native void markerSelected(long control, long number);

            /** A map's user asked for the details of the marker of {@code number}. */
            static native void markerDetails(long control, long number);

            /** The battery said its level, 0 to 1, and whether it charges. */
            static native void batteryChanged(double level, boolean charging);
        }
        """#,
        "InteropEventsSample.Android.swift": #"""
        // Platforms/Android/Swift/Host/GalleryEventSources.swift
        /// The gallery's own event on this head: the battery, which the gallery's activity watches while it lives and tells
        /// through GalleryNatives.
        enum GalleryEventSources {
            /// Declares the event the activity's watcher raises. Said once, as the library loads.
            @MainActor
            static func register() {
                StateUIEvents.raises(GalleryContract.batteryChanged)
            }

            @MainActor private static var lastSaid: (level: Double, charging: Bool)?

            /// The battery said its level and whether it charges: raised where it changed, and a device with no battery
            /// says nothing.
            @MainActor
            static func report(level: Double, charging: Bool) {
                guard level > 0 else { return }
                guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

                lastSaid = (level, charging)
                StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
            }
        }

        // Platforms/Android/Swift/Host/GalleryNatives.swift
        // The native methods of the gallery's Java views, com.stateui.gallery.GalleryNatives - found by their JNI names, each
        // called on the UI thread, where Swift's main actor runs.

        @_cdecl("Java_com_stateui_gallery_GalleryNatives_batteryChanged")
        public func galleryBatteryChanged(
            _ env: UnsafeMutablePointer<JNIEnv?>?, _ owner: jclass?, _ level: jdouble, _ charging: jboolean
        ) {
            MainActor.assumeIsolated { GalleryEventSources.report(level: level, charging: charging != 0) }
        }
        """#,
        "InteropEventsSample.AppKit.swift": #"""
        // Platforms/AppKit/Host/GalleryEventSources.swift
        /// The gallery's own pushes: what this host reports without being asked.
        ///
        /// `GalleryContract` declares each event with what it carries, and every
        /// `HostEvents.on` subscription hears it. A raise nobody hears is an ordinary
        /// answer, so the sources are wired unconditionally.
        ///
        /// THE SPLIT IS THE PLATFORM'S: a desktop with no battery reports nothing at
        /// all, and the sample's own words say so. What is watched here is the power
        /// source, which macOS reports through a run-loop source of its own.
        @MainActor
        enum GalleryEventSources {
            /// What was last said, so an unchanged reading raises nothing - a power
            /// source notifies on far more than a level change.
            private static var lastSaid: (level: Double, charging: Bool)?

            /// Declares what the gallery raises and starts watching. Said once,
            /// before the application runs.
            static func start() {
                // Declared where the source is wired: a handler listening for an
                // event nothing declared is told, once, that it will not hear it.
                StateUIEvents.raises(GalleryContract.batteryChanged)

                // Named in full: a C function pointer carries no context at all, and
                // an unqualified call to a static method captures the type implicitly.
                // The source stands on the main run loop, so the call comes on the
                // main thread.
                let notify: IOPowerSourceCallbackType = { _ in
                    MainActor.assumeIsolated { GalleryEventSources.report() }
                }

                guard let source = IOPSNotificationCreateRunLoopSource(notify, nil)?.takeRetainedValue()
                else { return }

                CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
                report()
            }

            /// Raises the battery's reading, where it has changed and there is one.
            private static func report() {
                let (level, charging) = GalleryActs.battery()

                guard level > 0 else { return }
                guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

                lastSaid = (level, charging)
                StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
            }
        }

        // Platforms/AppKit/main.swift
        // What this host answers for the application, said before it runs: the
        // controls it realizes, the acts it performs, and the pushes it reports. Each
        // lives in Host/ beside this file.
        GalleryControls.register()
        GalleryActs.register()
        GalleryEventSources.start()
        """#,
        "InteropEventsSample.GTK.swift": #"""
        // Platforms/GTK/Host/GalleryEventSources.swift
        /// The gallery's own pushes, as this host raises them: the battery, as UPower tells it.
        ///
        /// It raises on the UI thread, where GLib tells the signal, and a raise nobody hears is an ordinary answer, so the
        /// source is wired whether or not anything listens.
        enum GalleryEventSources {
            /// The battery as it was last said, so a notice that changed nothing of it raises nothing.
            @MainActor private static var lastSaid: (level: Double, charging: Bool)?

            /// Declares what the host raises and wires its source. Said once, before the application runs.
            @MainActor
            static func start() {
                // A handler listening for an event nothing declared is told, once, that it will not hear it.
                StateUIEvents.raises(GalleryContract.batteryChanged)

                // UPower's display device signals each change of its properties, the battery's among them.
                guard let device = GalleryPower.device else { return }
                // A C callback carries no context; the report is named in full.
                let changed: @convention(c) (OpaquePointer?, OpaquePointer?, OpaquePointer?, gpointer?) -> Void = { _, _, _, _ in
                    MainActor.assumeIsolated { GalleryEventSources.report() }
                }
                g_signal_connect_data(
                    UnsafeMutableRawPointer(device), "g-properties-changed", unsafeBitCast(changed, to: GCallback.self), nil,
                    nil, GConnectFlags(rawValue: 0))
                report()
            }

            @MainActor
            private static func report() {
                let (level, charging) = GalleryPower.battery()
                // Nothing is raised without a battery, nor for a notice that left it as it was.
                guard level > 0, lastSaid?.level != level || lastSaid?.charging != charging else { return }

                lastSaid = (level, charging)
                StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
            }
        }

        // Platforms/GTK/main.swift
        // Register the gallery module, then say what this host answers for it before it runs: the controls it realizes,
        // the acts it performs, and the pushes it reports - each in Host/ beside this file.
        registerApplication()
        // Each control's own register(), at the end of its file: its widget, and any act aimed at it.
        GalleryControls.register()
        GalleryActs.register()
        GalleryEventSources.start()
        """#,
        "InteropEventsSample.UIKit.swift": #"""
        // Platforms/UIKit/Host/GalleryEventSources.swift
        /// The gallery's own pushes: what this host reports without being asked.
        ///
        /// `GalleryContract` declares each event with what it carries, and every
        /// `HostEvents.on` subscription hears it. A raise nobody hears is an ordinary
        /// answer, so the sources are wired unconditionally.
        ///
        /// THE SPLIT IS THE PLATFORM'S: a device UIKit knows no battery of - the
        /// simulator - reports nothing at all, and the sample's own words say so.
        /// What is watched here is the battery, which UIKit reports through the
        /// notification center once its monitoring is on.
        @MainActor
        enum GalleryEventSources {

                /// Declares what the gallery raises and starts watching. Said once,
                /// before the application runs.
                static func start() {
                    // What the host raises, declared where its source is wired: a handler
                    // listening for an event nothing raises is told so.
                    StateUIEvents.raises(GalleryContract.batteryChanged)

                    UIDevice.current.isBatteryMonitoringEnabled = true
                    for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification] {
                        observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                            MainActor.assumeIsolated { report() }
                        })
                    }
                    report()
                }

                /// Raises the battery's reading, where it has changed and there is one.
                private static func report() {
                    let (level, charging) = GalleryActs.battery()

                    guard level > 0 else { return }
                    guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

                    lastSaid = (level, charging)
                    StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
                }
            }

        // Platforms/UIKit/main.swift
        // What this host answers for the application, said before it runs: the
        // controls it realizes, the acts it performs, and the pushes it reports. Each
        // lives in Host/ beside this file.
        GalleryControls.register()
        GalleryActs.register()
        GalleryEventSources.start()

        StateUIUIKit.run()
        """#,
        "InteropEventsSample.Web.javascript": #"""
        // Platforms/Web/Page/gallery-acts.js
        // The gallery's own acts as the page's scripts answer them, and what they tell: the browser's console and its
        // battery, wherever the browser offers it. The Swift half is Platforms/Web/Host/GalleryActs.swift and
        // GalleryEventSources.swift.
        // The page loads this script before the application starts.

        // The battery as two words, its level from 0 to 1 and whether it charges; a browser that says nothing of it - a
        // desktop's mains, Safari, Firefox - answers 0.
        const battery = navigator.getBattery?.().catch(() => null) ?? Promise.resolve(null);
        const said = (power) => (power ? `${power.level} ${power.charging}` : "0 false");

        // A browser that offers its battery - Chrome, Edge - tells it at once and at each change; the others tell nothing.
        battery.then((power) => {
          if (!power) return;
          const tell = () => StateUI.tell("battery", said(power));
          power.addEventListener("levelchange", tell);
          power.addEventListener("chargingchange", tell);
          tell();
        });
        """#,
        "InteropEventsSample.Web.swift": #"""
        // Platforms/Web/Host/GalleryEventSources.swift
        /// The gallery's own pushes, as this host raises them: the battery, as the browser tells the page's scripts.
        enum GalleryEventSources {
            /// Declares what the host raises and wires its source. Said once, before the application runs.
            @MainActor
            static func start() {
                // What the host raises, declared where its source is wired: a handler listening for an event nothing
                // declared is told, once, that it will not hear it.
                StateUIEvents.raises(GalleryContract.batteryChanged)
                StateUIScripts.hear("battery") { words in
                    let (level, charging) = GalleryActs.battery(words)
                    guard level > 0 else { return }
                    StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
                }
            }
        }

        // Platforms/Web/main.swift
        GalleryEventSources.start()
        StateUIWeb.run(name: "Gallery")
        """#,
        "InteropEventsSample.WinUI.cpp": #"""
        // Platforms/WinUI/Relay/System.cpp
        // The battery as Windows knows it: the power status every desktop reads, and the notices Windows sends as the
        // battery's charge or the power source changes.

        namespace {
            /// Windows' names for the battery's charge and for the power source.
            constexpr GUID batteryPercentage = {0xa7ad8041, 0xb45a, 0x4cae, {0x87, 0xa3, 0xee, 0xcb, 0xb4, 0x68, 0xa9, 0xe1}};
            constexpr GUID powerSource = {0x5d3e9a59, 0xe9d5, 0x4b00, {0xa6, 0xbd, 0xff, 0x34, 0xff, 0x51, 0x65, 0x48}};

            // The function the Swift half handed over: each notice is passed on to it, on a thread of Windows' own.
            void (*told)(void) = nullptr;

            ULONG CALLBACK changed(PVOID, ULONG, PVOID) {
                if (told) told();
                return 0;
            }

            DEVICE_NOTIFY_SUBSCRIBE_PARAMETERS subscription{changed, nullptr};
        }

        // The reading GalleryPower.battery() in the Swift half calls: for the battery act, and after each notice.
        extern "C" void gallery_battery(double *level, bool *charging) {
            try {
                *level = 0;
                *charging = false;
                SYSTEM_POWER_STATUS status{};
                // No system battery, or a charge Windows does not know: nothing to say.
                if (!GetSystemPowerStatus(&status) || (status.BatteryFlag & 128) || status.BatteryLifePercent > 100) return;
                *level = status.BatteryLifePercent / 100.0;
                *charging = status.ACLineStatus == 1;
            } catch (...) {
                report("reading the battery");
            }
        }

        extern "C" void gallery_battery_watch(void (*changedTold)(void)) {
            try {
                told = changedTold;
                for (auto setting : {&batteryPercentage, &powerSource}) {
                    HPOWERNOTIFY handle = nullptr;
                    PowerSettingRegisterNotification(setting, DEVICE_NOTIFY_CALLBACK, &subscription, &handle);
                }
            } catch (...) {
                report("watching the battery");
            }
        }
        """#,
        "InteropEventsSample.WinUI.swift": #"""
        // Platforms/WinUI/Host/GalleryEventSources.swift
        /// The gallery's own pushes, as this host raises them: the battery, as Windows tells it.
        enum GalleryEventSources {
            /// The battery as it was last said, so a notice that changed nothing of it raises nothing.
            @MainActor private static var lastSaid: (level: Double, charging: Bool)?

            /// Declares what the host raises and wires its source. Said once, before the application runs.
            @MainActor
            static func start() {
                // A handler listening for an event nothing declared is told, once, that it will not hear it.
                StateUIEvents.raises(GalleryContract.batteryChanged)

                // The gallery's relay asks Windows for each change of the battery's charge and of the power source
                // (PowerSettingRegisterNotification). A raise nobody hears is an ordinary answer, so it is wired regardless.
                gallery_battery_watch(batteryChanged)
                report()
            }

            @MainActor
            fileprivate static func report() {
                let (level, charging) = GalleryPower.battery()
                // Windows tells more than a level change: no battery, or a reading unchanged, raises nothing.
                guard level > 0, lastSaid?.level != level || lastSaid?.charging != charging else { return }

                lastSaid = (level, charging)
                StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
            }
        }

        /// What Windows calls as the battery's charge or the power source changes - on a thread of its own, and once as the
        /// watch begins: the report is the main actor's.
        /// It stands outside the main actor, as a closure written inside `start()` would be the main actor's.
        private let batteryChanged: @convention(c) () -> Void = {
            Task { @MainActor in GalleryEventSources.report() }
        }

        // Platforms/WinUI/main.swift
        // Before StateUIWinUI.run(): the pushes this host raises, their source wired.
        GalleryEventSources.start()
        """#,
    ]
}
#else
extension Listings {
    /// No host's code: a build for none shows none.
    fileprivate static let ofHosts: [String: String] = [:]
}
#endif
