#if WINUI
import StateUI

/// Functions the application registers with its host, called like the acts the
/// library ships: typed arguments in, typed values back, a thrown error on
/// failure.
struct WinUIActsSample: SampleContent, ExampleContent {
    @State private var draft = "Copy me somewhere"
    @State private var status = "nothing asked yet"
    @Aim(RatingBar.self) private var stars

    static let id = "winUIActs"
    static let title = "Calling WinUI"
    static let summary = "A function the app registers with its host - called, awaited, and failing out loud."

    /// Both halves are Swift here, so the headings say what each one IS.
    static let codeHeading = "In StateUI"

    static let code = """
        // The application's own acts and events, with no control behind them.
        // Public, because the host registers BY TYPE from a module of its own.
        public enum GalleryContract: ApplicationTier {
            public static let name = "Gallery"

            public static let setClipboard = ElementAct<Self, String, Void>("Gallery.SetClipboard")
            public static let readClipboard = ElementAct<Self, Void, String>("Gallery.ReadClipboard")
            public static let batteryLevel = ElementAct<Self, Void, (Double, Bool)>("Gallery.BatteryLevel")
            public static let nobody = ElementAct<Self, Void, Void>("Gallery.Nobody")

            public static let members: [any ContractMember] = [
                setClipboard, readClipboard, batteryLevel, nobody,
            ]
        }

        // An act of a control's own contract goes through the control's aim,
        // which puts the control's identity first.
        extension Aim where Target == RatingBar {
            public func flash() async throws {
                try await call(RatingBarContract.flash)
            }
        }

        @State private var draft = "Copy me somewhere"
        @State private var status = "nothing asked yet"
        @Aim(RatingBar.self) private var stars

        VStack {
            // `status` is read here, so every answer builds this closure.
            DebugInfoLabel()

            TextField($draft)

            Button("Copy to the clipboard")
                .onClicked {
                    try await stateUICall(GalleryContract.setClipboard, draft)
                    status = "copied"
                }

            // An answer arrives as the types the contract declares.
            Button("Paste from the clipboard")
                .onClicked {
                    let text = try await stateUICall(GalleryContract.readClipboard)
                    draft = text
                    status = text.isEmpty ? "the clipboard is empty" : "pasted"
                }

            Button("Ask about the battery")
                .onClicked {
                    let (level, charging) = try await stateUICall(GalleryContract.batteryLevel)

                    status = level <= 0
                        ? "this device does not say"
                        : "battery \\(Int(level * 100))%" + (charging ? ", charging" : "")
                }

            // An act nothing registered throws; a failure is never a silence.
            Button("Call something nobody registered")
                .onClicked {
                    do {
                        try await stateUICall(GalleryContract.nobody)
                        status = "that should have thrown"
                    } catch {
                        status = "thrown: \\(error)"
                    }
                }

            RatingBar()
                .rating(4)
                .aim(stars)

            Button("Flash the bar")
                .onClicked {
                    try await stars.flash()
                    status = "flashed \\(stars)"
                }

            Label(status)
        }
        """

    static let hostCode = HostCode(
        heading: "In WinUI",
        language: .swift,
        code: """
            // Platforms/WinUI/Host/GalleryActs.swift, said before the
            // application runs. A performer is handed the arguments the
            // contract declares and answers the values it declares.
            enum GalleryActs {
                @MainActor
                static func register() {
                    StateUIActs.add(GalleryContract.setClipboard) { text in
                        Clipboard.write(text)   // OpenClipboard, CF_UNICODETEXT
                    }

                    StateUIActs.add(GalleryContract.readClipboard) {
                        Clipboard.read()
                    }

                    StateUIActs.add(GalleryContract.batteryLevel) {
                        GalleryPower.battery()  // GetSystemPowerStatus
                    }
                }
            }

            // An act aimed at a control is its control's, registered at the
            // end of Platforms/WinUI/Host/RatingBarControl.swift. The identity
            // the aim sent is turned back into the control this host made,
            // and the performer is handed that control.
            extension RatingBarControl {
                @MainActor
                static func register() {
                    // … StateUIControls.add(RatingBarContract.self, …)

                    StateUIActs.add(RatingBarContract.flash, on: RatingBarControl.self) { bar in
                        bar.flash()   // a Storyboard fading its opacity, in the relay
                    }
                }
            }

            // And in main.swift, before StateUIWinUI.run():
            GalleryControls.register()   // RatingBarControl.register(), and the rest
            GalleryActs.register()
            """)

    var content: any View {
        VStack {
            DebugInfoLabel()

            TextField($draft)
                .accessibilityIdentifier("winUIActs.draft")
                .accessibilityLabel("Text to copy")

            Button("Copy to the clipboard")
                .onClicked {
                    try await stateUICall(GalleryContract.setClipboard, draft)
                    status = "copied"
                }

            Button("Paste from the clipboard")
                .onClicked {
                    let text = try await stateUICall(GalleryContract.readClipboard)
                    draft = text
                    status = text.isEmpty ? "the clipboard is empty" : "pasted"
                }

            Button("Ask about the battery")
                .onClicked {
                    let (level, charging) = try await stateUICall(GalleryContract.batteryLevel)

                    // A desktop without a battery answers 0, so only a level
                    // above zero counts.
                    status = level <= 0
                        ? "this device does not say"
                        : "battery \(Int(level * 100))%" + (charging ? ", charging" : "")
                }

            Button("Call something nobody registered")
                .onClicked {
                    do {
                        try await stateUICall(GalleryContract.nobody)
                        status = "that should have thrown"
                    } catch {
                        status = "thrown: \(error)"
                    }
                }

            RatingBar()
                .rating(4)
                .horizontalAlignment(.center)
                .aim(stars)

            Button("Flash the bar")
                .onClicked {
                    try await stars.flash()
                    status = "flashed \(stars)"
                }

            Label(status)
                .fontSize(15)
                .horizontalTextAlignment(.center)
        }
        .spacing(8)
    }

    var notes: Element? {
        VStack {
            Label("`StateUIActs.add` registers a function under an act the "
                + "application's contract declares, with what it takes and answers. "
                + "`stateUICall` calls it from any handler: typed arguments in, typed "
                + "values back, and the compiler refuses a performer of another shape. "
                + "A performer may await.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A performer that throws, a name nothing registered, and an answer of "
                + "another shape than the contract's resume the handler by throwing "
                + "`StateUIError` with the reason. Prefix the names with the application's "
                + "own, so they never meet the library's.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("An act of a control's own is declared in the control's contract and "
                + "called through its aim: `call` puts the control's identity in argument "
                + "0, and the host turns it back into the control it made - so the performer "
                + "is handed that control itself.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
