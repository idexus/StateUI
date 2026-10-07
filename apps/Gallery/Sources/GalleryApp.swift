// The gallery's user interface, written in Swift.
//
// Everything in this directory is compiled into a SEPARATE Swift module from the
// StateUI library - named after the project, so here it is
// "GalleryUI". The dependency runs one way: this module imports
// StateUI, never the reverse. That is what allows the library to be published
// on its own, and what lets a second app exist alongside this one without either
// knowing about the other.
//
// HOW THIS IS LAID OUT:
//
//     GalleryApp.swift   the application - its scenes, what it writes into its
//                        session, and the one function this module exports
//     Gallery/           the gallery itself: the galleries as a scene
//                        (GalleryScene.swift), one gallery window
//                        (GalleryWindow.swift) and the arrangement in it
//                        (MainPage.swift), where it is (Navigation.swift),
//                        what a sample is, the catalog of them, and the pages
//                        that show them
//     Styles/            what the app looks like: its palette and its styles
//     Samples/           one file per sample, in the group it belongs to
//
// ADDING A SAMPLE: write it under Samples/<Group>/ and name it in
// Gallery/Catalog.swift. Nothing else changes - the menu, the home page and the
// route that opens it are all built from that list.
//
// Nothing lists these files: the build discovers them by globbing this
// directory, subdirectories and all.

import StateUI

// listing: GalleryApp
/// The gallery application.
///
/// An application is what every scene SHARES - its styles, and the settings
/// it keeps between launches. The galleries are one scene, its windows as many
/// as the user opens: see Gallery/GalleryScene.swift.
struct GalleryApp: Application {
    /// The application as it runs - where its styles and its kept keys go.
    @Environment(\.application) private var application

    /// What every gallery shares, written as the application is made.
    init() {
        // The styles a control of the gallery asks for by name. A colour in a
        // style follows the theme by itself. See Styles/AppStyles.swift.
        application.styles = AppStyles.sheet

        // What the gallery KEEPS between launches - `PersistentStateSample`'s
        // three settings, and nothing else. Listed because a settings store
        // is read one key at a time and offers no list of what it holds, so
        // this is the only way the host can have the values in memory before
        // the first view asks for one - which is why it is written HERE, as
        // the application is made. Each host keeps them in the platform's
        // settings store, or in a file of its own where the platform offers an
        // application none.
        application.persistentKeys = [.visits, .who, .shade]

        // On GNOME the gallery opens in the dark theme, the look it wears
        // best there; the Appearance sample turns it back.
        #if GTK
        application.colorScheme = .dark
        #endif
    }

    /// The galleries - launch opens a gallery window, and *File ▸ New Window* one more; the scratchpads; and one
    /// About window for the whole application, in a scene of its own. See `ScenesSample`.
    var body: some Scene {
        GalleryScene()
        ScratchpadScene()
        AboutScene()
    }
}
// listing: end

/// The one thing this module exports.
///
/// The library cannot declare it: the dependency runs app -> library, so the
/// library has no way to name an application that did not exist when it was
/// compiled. So the app says which one it is, and a host that loads the app as
/// a separate native library finds it by this name.
///
/// The name is fixed by convention (`stateui_app_register`) so the host can
/// find it whatever the module is called.
@_cdecl("stateui_app_register")
public func stateui_app_register() {
    stateUIUseApp(GalleryApp())
}
