import StateUI

/// The application: one window, one page.
///
/// An application is its state and the windows built from it; what a window IS
/// - what it is called, how big it opens, and the arrangement inside it - is the
/// window's own declaration below.
struct StateUIStarterApp: Application {
    /// The application's styles - see Swift/Styles/AppStyles.swift.
    var styles: StyleSheet? { AppStyles.sheet }

    func createWindow() -> Window { MainWindow() }
}

/// The window, and what is in it.
///
/// Everything on screen is described in Swift and rendered by MAUI as real
/// native controls. The page it opens is MainPage.swift beside this file - and
/// where an app wants a stack, tabs or a menu, a `NavigationPage`, a
/// `TabbedPage` or a `FlyoutPage` goes in `content` instead, each over state
/// this window owns. The sample app in the StateUI repository is written
/// that way throughout.
struct MainWindow: Window {
    var content: Page { MainPage() }
}

/// The one thing this module exports - the line that names this application to
/// the host, exactly as MAUI does with `builder.UseMauiApp<App>()`. It cannot
/// move into the library: on Android and Windows this module is a separate
/// native library, and nothing in it runs until something calls into it by
/// name.
@_cdecl("stateui_app_register")
public func stateui_app_register() {
    stateUIUseApp(StateUIStarterApp())
}
