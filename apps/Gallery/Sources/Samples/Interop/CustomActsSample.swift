#if MAUI
import StateUI

/// An act of the bar's contract, aimed at one bar.
///
/// `call` puts the control's identity in argument 0; the C# half turns it
/// back into the control with `StateUIActs.TargetOf(command)`. Two bars on one
/// page each answer to their own aim.
extension Aim where Target == RatingBar {
    /// Flashes the bar this aim is on.
    func flash() async throws {
        try await call(RatingBarContract.flash)
    }
}

/// C# functions the application registers, called like the acts the library
/// ships: typed arguments in, typed values back, a thrown error on failure.
struct CustomActsSample: SampleContent, ExampleContent {
    @State private var draft = "Copy me somewhere"
    @State private var status = "nothing asked yet"
    @Aim(RatingBar.self) private var stars

    static let id = "customActs"
    static let title = "Calling C#"
    static let summary = "A C# function the app registers - called, awaited, and failing out loud."

    static let code = """
        // The application's own acts and events, with no control behind them.
        enum GalleryContract: ApplicationTier {
            static let name = "Gallery"

            static let setClipboard = ElementAct<Self, String, Void>("Gallery.SetClipboard")
            static let readClipboard = ElementAct<Self, Void, String>("Gallery.ReadClipboard")
            static let batteryLevel = ElementAct<Self, Void, (Double, Bool)>("Gallery.BatteryLevel")
            static let nobody = ElementAct<Self, Void, Void>("Gallery.Nobody")

            static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Gallery.BatteryChanged")
            static let connectivityChanged = ElementEvent<Self, Bool>("Gallery.ConnectivityChanged")

            static let members: [any ContractMember] = [
                setClipboard, readClipboard, batteryLevel, nobody, batteryChanged, connectivityChanged,
            ]
        }

        // An act of a control's own contract goes through the control's aim,
        // which puts the control's identity first.
        extension Aim where Target == RatingBar {
            func flash() async throws {
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

    var content: any View {
        VStack {
            DebugInfoLabel()

            TextField($draft)
                .accessibilityIdentifier("customActs.draft")
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
            Label("`StateUIActs.Add` registers a C# function under a name at startup. "
                + "`GalleryContract` declares the same name as an act of the application, "
                + "with what it takes and answers, and `stateUICall` calls it from any "
                + "handler: typed arguments in, typed values back.")
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
                + "0, and the performer turns it back into the control with "
                + "`StateUIActs.TargetOf(command)`, which answers null once that control "
                + "has left the screen.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
