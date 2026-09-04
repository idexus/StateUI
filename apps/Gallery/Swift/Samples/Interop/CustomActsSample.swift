import StateUI

/// The gallery's own acts: C# functions its MauiProgram registered under
/// these names. Declared the way the library declares its own - a token is
/// a name, and the session numbers the two kinds exactly the same way.
extension Act {
    /// Puts text on the system clipboard. C#: Clipboard.SetTextAsync.
    static let setClipboard = Act("Gallery.SetClipboard")

    /// Reads the system clipboard. C#: Clipboard.GetTextAsync.
    static let readClipboard = Act("Gallery.ReadClipboard")

    /// The battery's level and whether it is charging. C#: Battery.Default.
    static let batteryLevel = Act("Gallery.BatteryLevel")

    /// Draws attention to one RATING BAR - an act AIMED at a control rather
    /// than asked of the app. C#: the performer fades the control it is
    /// pointed at.
    static let flashRating = Act("Gallery.FlashRating")
}

/// An act aimed at a CONTROL, which is the shape every act of the library's
/// own has - `focus()`, `scrollTo`, `goBack` - and the one an application can
/// now write for itself.
///
/// `try target` is the control's identity, the same one the differ gives every
/// element, and it goes in front of the act's own arguments. The C# half turns
/// it back into the control with `StateUIActs.TargetOf(command)`; neither
/// side spells a name, and two RatingBars on one page each aim at their own.
extension ControlState where Target == RatingBar {
    /// Flashes the bar this state is assigned to.
    func flash() async throws {
        try await stateUICall(.flashRating, [try target])
    }
}

/// This library's own registration surface: StateUIActs on the C# side,
/// an `Act` token on this one.
struct CustomActsSample: SampleContent {
    @State private var draft = "Copy me somewhere"
    @State private var status = "nothing asked yet"
    @State private var stars = ControlState<RatingBar>()

    static let id = "custom-acts"
    static let title = "Calling C#"
    static let summary = "A C# function registered by the app - called, awaited, thrown."

    static let code = """
        // The C# functions are registered in MauiProgram - the IN C# listing
        // below is that registration. Here they are declared as tokens, once:
        extension Act {
            static let setClipboard = Act("Gallery.SetClipboard")
            static let readClipboard = Act("Gallery.ReadClipboard")
            static let batteryLevel = Act("Gallery.BatteryLevel")
            static let flashRating = Act("Gallery.FlashRating")
        }

        // An act AIMED at a control - the shape focus() and goBack() have.
        // `try target` is the control's identity and goes first; the C# half
        // turns it back with StateUIActs.TargetOf.
        extension ControlState where Target == RatingBar {
            func flash() async throws {
                try await stateUICall(.flashRating, [try target])
            }
        }

        @State private var draft = "Copy me somewhere"
        @State private var status = "nothing asked yet"
        @State private var stars = ControlState<RatingBar>()

        VStack {
            Entry($draft)

            // An act with nothing to answer: await it and move on.
            Button("Copy to the clipboard")
                .onClicked {
                    try await stateUICall(.setClipboard, [.string(draft)])
                    status = "copied"
                }

            // One that answers: the reply is typed values, read with the
            // same accessors every payload offers.
            Button("Paste from the clipboard")
                .onClicked {
                    let text = try await stateUICall(.readClipboard)
                        .value()?.string ?? ""
                    draft = text
                    status = text.isEmpty ? "the clipboard is empty" : "pasted"
                }

            // And one answering two values - a number and a bool.
            Button("Ask about the battery")
                .onClicked {
                    let reply = try await stateUICall(.batteryLevel)
                    let level = reply.value()?.number ?? -1
                    let charging = reply.value(1)?.bool ?? false

                    // A desktop without a battery answers 0 rather than a
                    // refusal - measured on Mac Catalyst - so nothing is a
                    // level only above zero.
                    status = level <= 0
                        ? "this device does not say"
                        : "battery \\(Int(level * 100))%"
                            + (charging ? ", charging" : "")
                }

            // And the promise around all of them: a failure is never a
            // silence. A name nothing registered throws, and do/catch is
            // the ordinary way to read the reason.
            Button("Call something nobody registered")
                .onClicked {
                    do {
                        _ = try await stateUICall(Act("Gallery.Nobody"))
                        status = "that should have thrown"
                    } catch {
                        status = "thrown: \\(error)"
                    }
                }

            // The app's own control, its own act, and the aim between them.
            RatingBar()
                .rating(4)
                .assign(stars)

            Button("Flash the bar")
                .onClicked {
                    try await stars.flash()
                    status = "flashed the bar this state names"
                }

            Label(status)
        }
        """

    /// The other half, in MauiProgram.CreateMauiApp - one plain function and
    /// two async, which are the two shapes the registration takes.
    static let codeCSharp = """
        StateUIActs.Add("Gallery.SetClipboard", async command =>
        {
            await Clipboard.Default.SetTextAsync(command.GetString(0) ?? "");
            return [];
        });

        StateUIActs.Add("Gallery.ReadClipboard", async command =>
            [SwiftWireValue.Of(await Clipboard.Default.GetTextAsync() ?? "")]);

        StateUIActs.Add("Gallery.BatteryLevel", command =>
            [
                SwiftWireValue.Of(Battery.Default.ChargeLevel),
                SwiftWireValue.Of(Battery.Default.State == BatteryState.Charging),
            ]);

        // And the aimed one: argument 0 is the control the Swift side named.
        StateUIActs.Add("Gallery.FlashRating", async command =>
        {
            if (StateUIActs.TargetOf(command) is RatingBar bar)
            {
                await bar.FadeTo(0.25, 120);
                await bar.FadeTo(1, 120);
            }

            return [];
        });
        """

    var example: Element {
        VStack {
            Entry($draft)

            Button("Copy to the clipboard")
                .onClicked {
                    try await stateUICall(.setClipboard, [.string(draft)])
                    status = "copied"
                }

            Button("Paste from the clipboard")
                .onClicked {
                    let text = try await stateUICall(.readClipboard)
                        .value()?.string ?? ""
                    draft = text
                    status = text.isEmpty ? "the clipboard is empty" : "pasted"
                }

            Button("Ask about the battery")
                .onClicked {
                    let reply = try await stateUICall(.batteryLevel)
                    let level = reply.value()?.number ?? -1
                    let charging = reply.value(1)?.bool ?? false

                    // A desktop without a battery answers 0 rather than a
                    // refusal - measured on Mac Catalyst - so nothing is a
                    // level only above zero.
                    status = level <= 0
                        ? "this device does not say"
                        : "battery \(Int(level * 100))%"
                            + (charging ? ", charging" : "")
                }

            Button("Call something nobody registered")
                .onClicked {
                    do {
                        _ = try await stateUICall(Act("Gallery.Nobody"))
                        status = "that should have thrown"
                    } catch {
                        status = "thrown: \(error)"
                    }
                }

            // An act AIMED at a control: the app registers the control, the
            // act, and the aim, using nothing the library keeps to itself.
            RatingBar()
                .rating(4)
                .assign(stars)

            Button("Flash the bar")
                .onClicked {
                    try await stars.flash()
                    status = "flashed the bar this state names"
                }

            Label(status)
                .fontSize(17)
                .horizontalTextAlignment(.center)

        }
        .spacing(5)
    }

    var notes: Element? {
        Label("Register a C# function once - StateUIActs.Add in MauiProgram - "
            + "and call it from any handler like an act the library ships: "
            + "typed arguments in, typed values back, a thrown StateUIError "
            + "when it fails. The last button asks for a name "
            + "nothing registered, and the do/catch above shows exactly what "
            + "arrives: a thrown error naming the unknown command - never a "
            + "silence. Prefix your names with "
            + "the app's own, so they can never meet a MAUI method's.")
            .fontSize(14)
            .textColor(Palette.subtle)
    }
}
