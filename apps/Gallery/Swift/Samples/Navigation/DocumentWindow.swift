import StateUI

/// A window the PLATFORM asked for - *File ▸ New Window* on a Mac, the window
/// controls on an iPad. See `MultiWindowSample` and `Application.onCreatingWindow`.
///
/// The same three lines as `InspectorWindow`, for the same three reasons - and
/// that is the point: the library does not distinguish a window the interface
/// asked for from a window the system asked for, because by the time either
/// reaches `windows` there is nothing to distinguish.
///
/// The id is `"document-\(number)"` and not the bare number the inspectors use,
/// because an id is `String(describing:)` of whatever it is given and the two
/// lists count from 1 apiece: inspector 1 and document 1 would otherwise be one
/// identity, and the second one described would take the first one's window.
struct DocumentWindow: Window {
    /// Which document this is - its identity and its name.
    let number: Int

    /// Where the gallery is, and how a window closes itself.
    let nav: Navigation

    var id: AnyHashable? { "document-\(number)" }
    var title: String? { "Document \(number)" }
    var width: Double? { 620 }
    var height: Double? { 740 }
    var minimumWidth: Double? { 420 }
    var minimumHeight: Double? { 480 }

    var onDestroying: EventHandler? {
        { nav.closeDocument(number) }
    }

    var content: Page { DocumentPage(number: number, nav: nav) }
}
