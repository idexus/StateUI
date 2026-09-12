import StateUI

/// One gallery - a SESSION of the application. *File ▸ New Window* opens
/// another, and so does the windows sample's "Open another gallery"; each has
/// state of its own, and the windows it opens beside its main one are its own.
///
/// What a gallery holds is its own objects, each a class of `@State`
/// properties: WHERE IT IS (`Navigation` - the section, what is pushed and
/// presented, whether the menu is open), WHAT IT LOOKS LIKE (`SessionStyle` -
/// the font and the accent its Fonts and Colours windows choose), what its
/// window's chrome says (`TitleBarState`) and what its window has said about
/// its life (`WindowLog`) - and the catalog of samples it shows. `nav` and
/// `style` are offered to every window of the gallery, which is how its windows
/// share one context: nothing is passed between the Colours window and the
/// bars it paints. The rest is handed to the main window, which reads it.
///
/// Each sample owns its own `@State`, declared on the sample itself - and since
/// the catalog this gallery keeps carries the samples, that state survives for
/// as long as the gallery does, pushes and pops included. A second gallery
/// keeps a catalog of its own.
struct GalleryScene: Scene {
    /// Where this gallery is, and every move it can make. See
    /// Gallery/Navigation.swift.
    @State private var nav = Navigation()

    /// What this gallery looks like - kept with it. See SessionStyle.swift.
    @State private var style = SessionStyle()

    /// What the main window's chrome says - written by the TitleBar sample.
    @State private var bar = TitleBarState()

    /// What the main window has said about its life - its phase, watched in
    /// `MainWindow` and read by the Lifecycle sample.
    @State private var log = WindowLog()

    /// WHERE THE CATALOG IS KEPT, so that it is built once rather than on
    /// every render - a hundred samples, each holding the gallery's objects and
    /// bindings that go on reading through to its state.
    @State private var kept = KeptCatalog()

    /// The gallery's windows: the main one, and the ones it may open beside
    /// it - its Fonts and Colours windows, which may step aside while another
    /// gallery is in front or float above it, its inspector, and a swatch per
    /// number.
    var windows: Windows {
        let nav = self.nav
        let style = self.style
        let bar = self.bar
        let log = self.log

        return Windows {
            WindowGroup(.fonts) { FontsWindow() }
                .autoHide(style.hidesTools)
                .floatsOnTop(style.floatsTools)

            WindowGroup(.colours) { ColoursWindow() }
                .autoHide(style.hidesTools)
                .floatsOnTop(style.floatsTools)

            WindowGroup(.debugInspector) { DebugInspector() }

            WindowGroup(.swatch, for: Int.self) { number in SwatchWindow(number: number) }
        } main: {
            MainWindow(
                catalog: kept.catalog {
                    Catalog(nav: nav, style: style, bar: bar, log: log)
                },
                nav: nav,
                style: style,
                log: log,
                bar: bar)
        }
        .environment(nav)
        .environment(style)
    }
}
