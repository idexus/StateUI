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
//                        session, and the function every head calls
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
/// An application is what every scene SHARES - here its styles. The galleries
/// are one scene, its windows as many as the user opens: see
/// Gallery/GalleryScene.swift.
struct GalleryApp: Application {
    /// The application as it runs - where its styles go.
    @Environment(\.application) private var application

    /// What every gallery shares, written as the application is made.
    init() {
        // The styles a control of the gallery asks for by name. A colour in a
        // style follows the theme by itself. See Styles/AppStyles.swift.
        application.styles = AppStyles.sheet

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

/// Names this application to its host: every head calls it before its host
/// runs - Platforms/<Host>. The library cannot declare it: the dependency runs
/// app -> library.
@MainActor
public func registerApplication() {
    stateUIUseApp(GalleryApp())
}
