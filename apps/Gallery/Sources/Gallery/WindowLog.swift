import StateUI

/// What a gallery's main window has said about its life, numbered, newest
/// last - kept by the gallery's scene, written by `MainWindow` as the window
/// is made and by `WindowPhaseLog` as its phase moves, and read by the
/// Lifecycle sample.
final class WindowLog {
    /// The last six moments, each numbered.
    @State var events: [String] = []

    /// How many moments have come since the gallery opened - the number in
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
/// draws nothing, so a phase change builds this and nothing else.
///
/// The log's first line is `created`, which `MainWindow` writes as the window
/// is made: `.onChanged` hears a CHANGE, and the phase starts there. The
/// activated/deactivated pair rides each trip to the background - NOT a mere
/// focus switch on Mac Catalyst, measured - and where the application stands
/// is `application.phase`, which the Phases sample shows.
struct WindowPhaseLog: ContentView {
    /// Where the moments are written.
    let log: WindowLog

    /// The window this view stands in, whose phase it follows.
    @Environment private var window: WindowSession

    var content: any View {
        BoxView(Color("#00000000"))
            .widthRequest(0)
            .heightRequest(0)
            .inputTransparent(true)
            .onChanged(window.phase) { log.note("\(window.phase)") }
    }
}
