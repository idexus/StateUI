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
//     GalleryApp.swift   the application - its scene, what it writes into its
//                        session, and the one function this module exports
//     Gallery/           the gallery itself: one gallery as a scene
//                        (GalleryScene.swift), its window and the arrangement in
//                        it (MainWindow.swift), where it is (Navigation.swift),
//                        what a sample is, the catalog of them, and the pages
//                        that show them
//     Styles/            what the app looks like: its palette and its styles
//     Samples/           one file per sample, in the group it belongs to
//
// ADDING A SAMPLE: write it under Samples/<Group>/ and name it in
// Gallery/Catalog.swift. Nothing else changes - the menu, the home page and the
// route that opens it are all built from that list.
//
// Nothing lists these files: every build - Apple, Android, Windows - discovers
// them by globbing this directory, subdirectories and all.

import StateUI

/// The gallery. MAUI: Application.
///
/// An application is what every gallery SHARES - its styles, and the settings
/// it keeps between launches. Each gallery is a scene of its own, and there are
/// as many as the reader opens: see Gallery/GalleryScene.swift.
struct GalleryApp: Application {
    /// Which kind of device this is, from the standard environment - answered
    /// by the host before the application is made, so the styles below already
    /// know whether the SearchBar wants a touch floor. An APPLICATION's
    /// unfilled slot answers the standard provider directly.
    @Environment var device: DeviceInfo

    /// The application as it runs - where its styles and its kept keys go.
    @Environment private var application: ApplicationSession

    /// What every gallery shares, written as the application is made.
    init() {
        // The styles every control in the gallery is given - the .NET MAUI
        // template's own, in Swift. The idiom goes in because one style reads
        // it: the SearchBar's touch floor is a touch screen's, not the
        // desktop's - and the host says the device before the application is
        // made. A colour in a style follows the theme by itself. See
        // Styles/AppStyles.swift.
        application.styles = AppStyles.sheet(on: device.idiom)

        // What the gallery KEEPS between launches - `PersistentStateSample`'s
        // three settings, and nothing else. Listed because a settings store
        // is read one key at a time and offers no list of what it holds, so
        // this is the only way the host can have the values in memory before
        // the first view asks for one - which is why it is written HERE, as
        // the application is made. Kept in the platform's own store, which is
        // what an application that leaves `persistentStorage` alone says.
        application.persistentKeys = [.visits, .who, .shade]
    }

    /// One gallery, and as many more as the reader opens.
    var scene: any Scene { GalleryScene() }
}

/// The one thing this module exports.
///
/// The library cannot declare it: on Android and Windows it is a separate native
/// library, and the dependency runs app -> library, so the library has no way to
/// name an application that did not exist when it was compiled. So the app says
/// which one it is, exactly as a MAUI app does with
/// `builder.UseMauiApp<App>()`.
///
/// The name is fixed by convention (`stateui_app_register`) so the host can
/// find it whatever the module is called.
@_cdecl("stateui_app_register")
public func stateui_app_register() {
    stateUIUseApp(GalleryApp())
}
