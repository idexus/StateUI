#if APPKIT || UIKIT || GTK || WINUI || ANDROID
import StateUI

/// Functions the application registers with its host, called like the acts the
/// library ships: typed arguments in, typed values back, a thrown error on
/// failure.
struct InteropActsSample: SampleContent, ExampleContent {
    @State private var draft = "Copy me somewhere"
    @State private var status = "nothing asked yet"
    @Aim(RatingBar.self) private var stars

    static let id = InteropHost.key + "Acts"
    static let title = "Calling " + InteropHost.name
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
                        : "battery \\(Int((level * 100).rounded()))%" + (charging ? ", charging" : "")
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

    #if APPKIT
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/AppKit/Host/GalleryActs.swift, said before the
            // application runs. A performer is handed the arguments the
            // contract declares and answers the values it declares.
            enum GalleryActs {
                @MainActor
                static func register() {
                    StateUIActs.add(GalleryContract.setClipboard) { text in
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }

                    StateUIActs.add(GalleryContract.readClipboard) {
                        NSPasteboard.general.string(forType: .string) ?? ""
                    }

                    StateUIActs.add(GalleryContract.batteryLevel) {
                        battery()
                    }
                }
            }

            // An act aimed at a control is its view's, registered at the end of
            // Platforms/AppKit/Host/RatingBarView.swift. The identity the aim
            // sent is turned back into the view this host made, and the
            // performer is handed that view.
            extension RatingBarView {
                @MainActor
                static func register() {
                    // … StateUIControls.add(RatingBarContract.self, …)

                    StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
                        bar.flash()
                    }
                }
            }

            // And in main.swift, before StateUIAppKit.run(...):
            GalleryControls.register()   // RatingBarView.register(), and the rest
            GalleryActs.register()
            """))
    #elseif UIKIT
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/UIKit/Host/GalleryActs.swift, said before the
            // application runs. A performer is handed the arguments the
            // contract declares and answers the values it declares.
            enum GalleryActs {
                @MainActor
                static func register() {
                    StateUIActs.add(GalleryContract.setClipboard) { text in
                        UIPasteboard.general.string = text
                    }

                    StateUIActs.add(GalleryContract.readClipboard) {
                        UIPasteboard.general.string ?? ""
                    }

                    StateUIActs.add(GalleryContract.batteryLevel) {
                        battery()
                    }
                }
            }

            // An act aimed at a control is its view's, registered at the end of
            // Platforms/UIKit/Host/RatingBarView.swift. The identity the aim
            // sent is turned back into the view this host made, and the
            // performer is handed that view.
            extension RatingBarView {
                @MainActor
                static func register() {
                    // … StateUIControls.add(RatingBarContract.self, …)

                    StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
                        bar.flash()
                    }
                }
            }

            // And in main.swift, before StateUIUIKit.run():
            GalleryControls.register()   // RatingBarView.register(), and the rest
            GalleryActs.register()
            """))
    #elseif GTK
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/GTK/Host/GalleryActs.swift, said before the
            // application runs. A performer is handed the arguments the
            // contract declares and answers the values it declares - and may
            // await, as GTK's clipboard answers only asynchronously.
            enum GalleryActs {
                @MainActor
                static func register() {
                    StateUIActs.add(GalleryContract.setClipboard) { text in
                        gdk_clipboard_set_text(clipboard(), text)
                    }

                    StateUIActs.add(GalleryContract.readClipboard) {
                        await clipboardText()   // gdk_clipboard_read_text_async
                    }

                    StateUIActs.add(GalleryContract.batteryLevel) {
                        GalleryPower.battery()  // UPower, on the system bus
                    }
                }
            }

            // An act aimed at a control is its control's, registered at the
            // end of Platforms/GTK/Host/RatingBarWidget.swift. The identity
            // the aim sent is turned back into the control this host made,
            // and the performer is handed that control.
            extension RatingBarWidget {
                @MainActor
                static func register() {
                    // … StateUIControls.add(RatingBarContract.self, …)

                    StateUIActs.add(RatingBarContract.flash, on: RatingBarWidget.self) { bar in
                        bar.flash()   // libadwaita's animation of its opacity
                    }
                }
            }

            // And in main.swift, before StateUIGTK.run(applicationID:):
            GalleryControls.register()   // RatingBarWidget.register(), and the rest
            GalleryActs.register()
            """))
    #elseif WINUI
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
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
            """),
        .cpp("""
            // Platforms/WinUI/Relay/System.cpp - the battery as Windows knows it: the
            // power status every desktop reads. GalleryPower.battery() in the Swift
            // half calls it; the clipboard needs no relay, Swift calls Win32 itself.
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

            // Platforms/WinUI/Relay/Controls.cpp - the act aimed at the bar: a
            // Storyboard fading WinUI's RatingControl out and back, twice.
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
            """))
    #else
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/Android/Swift/Host/GalleryActs.swift, said as the
            // library loads. The device is asked through the gallery's own
            // Java, com.stateui.gallery.GalleryDevice, which `Java` calls.
            enum GalleryActs {
                @MainActor
                static func register() {
                    StateUIActs.add(GalleryContract.setClipboard) { text in
                        Java.frame {
                            Java.callStatic(
                                device, copy, .object(StateUIAndroid.context), .object(Java.string(text)))
                        }
                    }

                    StateUIActs.add(GalleryContract.readClipboard) {
                        Java.frame {
                            Java.text(Java.callStaticObject(device, paste, .object(StateUIAndroid.context)))
                        }
                    }

                    StateUIActs.add(GalleryContract.batteryLevel) {
                        battery()   // the sticky ACTION_BATTERY_CHANGED, read in GalleryDevice.java
                    }
                }
            }

            // An act aimed at a control is its control's, registered at the
            // end of Platforms/Android/Swift/Host/RatingBarView.swift. The
            // identity the aim sent is turned back into the control this host
            // made, and the performer is handed that control.
            extension RatingBarView {
                @MainActor
                static func register() {
                    // … StateUIControls.add(RatingBarContract.self, …)

                    StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
                        bar.flash()   // the view's own animate(), in its Java
                    }
                }
            }

            // And in JNI_OnLoad, on the UI thread, before StateUIAndroid.load(machine):
            MainActor.assumeIsolated {
                GalleryControls.register()   // RatingBarView.register(), and the rest
                GalleryActs.register()
            }
            """),
        .java("""
            // Platforms/Android/Java/com/stateui/gallery/GalleryDevice.java - what
            // the gallery's own acts ask of the device, each a static method the
            // Swift half calls through `Java`.
            final class GalleryDevice {
                static void copy(Context context, String text) {
                    context.getSystemService(ClipboardManager.class)
                            .setPrimaryClip(ClipData.newPlainText("StateUI Gallery", text));
                }

                // The clipboard's text; empty where it holds none.
                static String paste(Context context) {
                    ClipData clip = context.getSystemService(ClipboardManager.class).getPrimaryClip();
                    if (clip == null || clip.getItemCount() == 0) return "";
                    CharSequence text = clip.getItemAt(0).coerceToText(context);
                    return text == null ? "" : text.toString();
                }

                // The battery's level, 0 to 1 - 0 where the device has none - and 1
                // where it charges, else 0: the sticky ACTION_BATTERY_CHANGED.
                static double[] battery(Context context) {
                    return reading(context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED)));
                }

                private static double[] reading(Intent status) {
                    if (status == null) return new double[] {0, 0};
                    int level = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
                    int scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
                    int state = status.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
                    boolean charging = state == BatteryManager.BATTERY_STATUS_CHARGING || state == BatteryManager.BATTERY_STATUS_FULL;
                    return new double[] {level >= 0 && scale > 0 ? (double) level / scale : 0, charging ? 1 : 0};
                }
            }

            // Platforms/Android/Java/com/stateui/gallery/RatingBarView.java - the act
            // aimed at the bar is the view's own animation.
            final class RatingBarView extends View {
                // … the stars drawn, and a tap told as TrafficLightView tells a lamp

                void flash() {
                    animate().alpha(0.25f).setDuration(120).withEndAction(() -> animate().alpha(1).setDuration(120));
                }
            }
            """))
    #endif

    var content: some View {
        VStack {
            DebugInfoLabel()

            TextField($draft)
                .accessibilityIdentifier(Self.id + ".draft")
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
                        : "battery \(Int((level * 100).rounded()))%" + (charging ? ", charging" : "")
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

    var notes: (any View)? {
        VStack {
            Label("`StateUIActs.add` registers a function under an act the "
                + "application's contract declares, with what it takes and answers. "
                + "`stateUICall` calls it from any handler: typed arguments in, typed "
                + "values back, and the compiler refuses a performer of another shape." + InteropHost.awaiting)
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
                + "0, and the host turns it back into the \(InteropHost.made) it made - so the performer "
                + "is handed that \(InteropHost.made) itself.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
