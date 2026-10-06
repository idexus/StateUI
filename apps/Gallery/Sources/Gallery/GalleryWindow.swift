import StateUI

// listing: GalleryWindow
/// One gallery window - launch opens the first, and *File ▸ New Window* one
/// more. What a window is doing is its own: where it is (`Navigation` - the
/// section, what is pushed and presented, whether the menu is open), what its
/// bar says (`WindowBarState`), what it has said about its life (`WindowLog`)
/// and the catalog of samples it shows. What it looks like is its scene's,
/// handed to it: every gallery window wears the one look the Fonts and Colours
/// windows choose.
///
/// Each sample owns its own `@State`, declared on the sample itself - and since
/// the catalog this window keeps carries the samples, that state survives for
/// as long as the window does, pushes and pops included. Another gallery
/// window keeps a catalog of its own.
struct GalleryWindow: View {
    /// What every gallery window looks like - its scene's. See
    /// SessionStyle.swift.
    let style: SessionStyle

    /// Where this window is, and every move it can make. See
    /// Gallery/Navigation.swift.
    @State private var nav = Navigation()

    /// What this window's bar says - written by the Window bar sample.
    @State private var bar = WindowBarState()

    /// What this window has said about its life - its phase, watched by
    /// `WindowPhaseLog` and read by the Lifecycle sample.
    @State private var log = WindowLog()

    /// WHERE THE CATALOG IS KEPT, so that it is built once rather than on
    /// every render - a hundred samples, each holding the window's objects and
    /// bindings that go on reading through to its state.
    @State private var kept = KeptCatalog()

    var body: some View {
        let nav = self.nav
        let style = self.style
        let bar = self.bar
        let log = self.log

        return MainPage(
            catalog: kept.catalog {
                Catalog(nav: nav, style: style, bar: bar, log: log)
            },
            nav: nav,
            style: style,
            log: log,
            bar: bar)
    }
}
// listing: end
