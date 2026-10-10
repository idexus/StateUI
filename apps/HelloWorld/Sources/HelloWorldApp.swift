import StateUI

/// The application: its windows, each showing MainPage.
///
/// An application is its state and the scene built from it - here a
/// `WindowGroup`, of which launch and *File ▸ New Window* make a window.
/// What a window shows is a view, MainPage.swift beside this file; where an app
/// wants a stack, tabs or a menu, that view's `body` is a `NavigationStack`, a
/// `TabView` or a `SplitView`, over state the view owns. What a window is
/// called and how big it opens are its session's, written from a view in it
/// (`@Environment(\.window) private var window`).
struct HelloWorldApp: Application {
    /// The application as it runs - where its styles go.
    @Environment(\.application) private var application

    /// The application's styles - see Styles/AppStyles.swift - written
    /// as the application is made. A colour in one follows the theme by
    /// itself.
    init() {
        application.styles = AppStyles.sheet
    }

    var body: some Scene {
        WindowGroup { MainPage() }
    }
}

/// The function every head of this application calls by name before its host
/// runs - Platforms/<Host>. The library cannot declare it: the dependency runs
/// app -> library.
@_cdecl("stateui_app_register")
@MainActor
public func stateui_app_register() {
    stateUIUseApp(HelloWorldApp())
}
