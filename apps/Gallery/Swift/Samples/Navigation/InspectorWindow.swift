import StateUI

/// A window of its own, holding an inspector - see `MultiWindowSample`.
///
/// The whole of a second window is this declaration. Three things are the
/// APPLICATION's to get right and none of them is the library's: an `id` so the
/// window is matched by WHICH inspector it is rather than by its place in the
/// list, `onDestroying` so a window the reader closed leaves the array that
/// opened it, and a removal BY VALUE so both ends agree.
struct InspectorWindow: Window {
    /// Which inspector this is - its identity and its name.
    let number: Int

    /// Where the gallery is, and how a window closes itself.
    let nav: Navigation

    var id: AnyHashable? { number }
    var title: String? { "Inspector \(number)" }
    var width: Double? { 460 }
    var height: Double? { 620 }
    var minimumWidth: Double? { 360 }
    var minimumHeight: Double? { 420 }

    var onDestroying: EventHandler? {
        { nav.closeInspector(number) }
    }

    var content: Page { InspectorPage(number: number, nav: nav) }
}
