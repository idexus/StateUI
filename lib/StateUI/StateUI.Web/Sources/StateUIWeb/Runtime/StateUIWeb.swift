// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Runs a StateUI application in a web page, as the browser's own elements, from the WebAssembly module the page
/// loaded.
///
/// An application's Web head names the application to the host and hands it
/// the page:
///
///     import HelloWorldUI
///     import StateUIWeb
///
///     stateui_app_register()
///     StateUIWeb.run(name: "HelloWorld")
///
/// `.scripts/Web/run-app.sh` builds the head, lays the page out beside it
/// and serves it. A control this host does not present yet shows its name in
/// red where it belongs.
public enum StateUIWeb {
    /// Shows the application in the page and returns: from then on the browser calls it, as the user acts and as
    /// the display draws.
    ///
    /// - Parameter name: the application's name, which `app.info` tells it.
    @MainActor
    public static func run(name: String) {
        WebRenderer.start(applicationName: name)
    }
}
