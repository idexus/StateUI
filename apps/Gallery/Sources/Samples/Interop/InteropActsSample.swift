#if APPKIT || UIKIT || GTK || WINUI || ANDROID || WEB
import StateUI

/// Functions the application registers with its host, called like the acts the
/// library ships: typed arguments in, typed values back, a thrown error on
/// failure.
struct InteropActsSample: SampleContent, ExampleContent {
    // listing: InteropActsSample
    @State private var draft = "Copy me somewhere"
    @State private var status = "nothing asked yet"
    @Aim(RatingBar.self) private var stars
    // listing: end

    static let id = InteropHost.key + "Acts"
    static let title = "Calling " + InteropHost.name
    static let summary = "A function the app registers with its host - called, awaited, and failing out loud."

    static var code: String { Listings.joined("GalleryContract", "RatingBar.flash", "InteropActsSample") }

    /// Both halves are Swift here, so the headings say what each one IS.
    static let codeHeading = "In StateUI"

    #if APPKIT
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropActsSample.AppKit.swift")
    #elseif UIKIT
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropActsSample.UIKit.swift")
    #elseif GTK
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropActsSample.GTK.swift")
    #elseif WINUI
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropActsSample.WinUI.swift", "InteropActsSample.WinUI.cpp", "InteropActsSample.WinUI.flash.cpp")
    #elseif WEB
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropActsSample.Web.swift", "InteropActsSample.Web.javascript")
    #else
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropActsSample.Android.swift", "InteropActsSample.Android.load.swift", "InteropActsSample.Android.java")
    #endif

    // listing: InteropActsSample
    var body: some View {
        VStack {
            DebugInfoLabel()

            TextField($draft)
                .accessibilityIdentifier(Self.id + ".draft")
                .accessibilityLabel("Text to copy")

            Button("Copy to the clipboard")
                .onClicked(.ignoreWhileRunning) {
                    try await stateUICall(GalleryContract.setClipboard, draft)
                    status = "copied"
                }

            Button("Paste from the clipboard")
                .onClicked(.ignoreWhileRunning) {
                    let text = try await stateUICall(GalleryContract.readClipboard)
                    draft = text
                    status = text.isEmpty ? "the clipboard is empty" : "pasted"
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
                .rating(4)
                .horizontalAlignment(.center)
                .aim(stars)

            Button("Flash the bar")
                .onClicked(.ignoreWhileRunning) {
                    try await stars.flash()
                    status = "flashed \(stars)"
                }

            Text(status)
                .fontSize(15)
                .horizontalTextAlignment(.center)
        }
        .spacing(8)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("`StateUIActs.add` registers a function under an act the "
                + "application's contract declares, with what it takes and answers. "
                + "`stateUICall` calls it from any handler: typed arguments in, typed "
                + "values back, and the compiler refuses a performer of another shape." + InteropHost.awaiting)
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A performer that throws, a name nothing registered, and an answer of "
                + "another shape than the contract's resume the handler by throwing "
                + "`StateUIError` with the reason. Prefix the names with the application's "
                + "own, so they never meet the library's.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("An act of a control's own is declared in the control's contract and "
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
