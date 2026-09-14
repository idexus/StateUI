#if MAUI
import StateUI

/// The gallery's own acts: C# functions MauiProgram registers under these
/// names, declared the way the library declares its own.
extension Act {
    /// Puts text on the system clipboard. C#: `Clipboard.SetTextAsync`.
    static let setClipboard = Act("Gallery.SetClipboard")

    /// Reads the system clipboard. C#: `Clipboard.GetTextAsync`.
    static let readClipboard = Act("Gallery.ReadClipboard")

    /// The battery's level and whether it is charging. C#: `Battery.Default`.
    static let batteryLevel = Act("Gallery.BatteryLevel")

    /// Draws attention to one rating bar. C#: the performer fades the control
    /// `StateUIActs.TargetOf` answers.
    static let flashRating = Act("Gallery.FlashRating")
}

/// An act aimed at a control the application registers.
///
/// `target` is the control's identity and goes in argument 0; the C# half
/// turns it back into the control with `StateUIActs.TargetOf(command)`. Two
/// bars on one page each answer to their own aim.
extension Aim where Target == RatingBar {
    /// Flashes the bar this aim is on.
    func flash() async throws {
        try await stateUICall(.flashRating, [try target])
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
        extension Act {
            static let setClipboard = Act("Gallery.SetClipboard")
            static let readClipboard = Act("Gallery.ReadClipboard")
            static let batteryLevel = Act("Gallery.BatteryLevel")
            static let flashRating = Act("Gallery.FlashRating")
        }

        // An act aimed at a control puts the control's identity first.
        extension Aim where Target == RatingBar {
            func flash() async throws {
                try await stateUICall(.flashRating, [try target])
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
                    try await stateUICall(.setClipboard, [.string(draft)])
                    status = "copied"
                }

            // An answer is typed values, read with the PropValue accessors.
            Button("Paste from the clipboard")
                .onClicked {
                    let text = try await stateUICall(.readClipboard).value()?.string ?? ""
                    draft = text
                    status = text.isEmpty ? "the clipboard is empty" : "pasted"
                }

            Button("Ask about the battery")
                .onClicked {
                    let reply = try await stateUICall(.batteryLevel)
                    let level = reply.value()?.number ?? -1
                    let charging = reply.value(1)?.bool ?? false

                    status = level <= 0
                        ? "this device does not say"
                        : "battery \\(Int(level * 100))%" + (charging ? ", charging" : "")
                }

            // A name nothing registered throws; a failure is never a silence.
            Button("Call something nobody registered")
                .onClicked {
                    do {
                        try await stateUICall(Act("Gallery.Nobody"))
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
                    try await stateUICall(.setClipboard, [.string(draft)])
                    status = "copied"
                }

            Button("Paste from the clipboard")
                .onClicked {
                    let text = try await stateUICall(.readClipboard).value()?.string ?? ""
                    draft = text
                    status = text.isEmpty ? "the clipboard is empty" : "pasted"
                }

            Button("Ask about the battery")
                .onClicked {
                    let reply = try await stateUICall(.batteryLevel)
                    let level = reply.value()?.number ?? -1
                    let charging = reply.value(1)?.bool ?? false

                    // A desktop without a battery answers 0, so only a level
                    // above zero counts.
                    status = level <= 0
                        ? "this device does not say"
                        : "battery \(Int(level * 100))%" + (charging ? ", charging" : "")
                }

            Button("Call something nobody registered")
                .onClicked {
                    do {
                        try await stateUICall(Act("Gallery.Nobody"))
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
                + "This side declares the same name as an `Act` and calls it with "
                + "`stateUICall` from any handler: typed arguments in, typed values back.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A performer that throws, and a name nothing registered, resume the "
                + "handler by throwing `StateUIError` with the reason. Prefix the names "
                + "with the application's own, so they never meet the library's.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("An aimed act puts `try target` in argument 0, and the performer turns "
                + "it back into the control with `StateUIActs.TargetOf(command)`, which "
                + "answers null once that control has left the screen.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
