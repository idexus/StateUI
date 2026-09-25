// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// Runs a StateUI application as native GTK 4 and libadwaita widgets in the application's own process.
///
/// An application's GTK head names the application to the host and hands it
/// the thread:
///
///     import HelloWorldUI
///     import StateUIGTK
///
///     stateui_app_register()
///     StateUIGTK.run(applicationID: "com.stateui.helloworld")
///
/// `.scripts/GTK/run-app.sh` builds the head and starts it. A control this
/// host does not present yet shows its name in red where it belongs.
public enum StateUIGTK {
    /// Starts GTK on this thread and runs the application until its last window closes.
    ///
    /// - Parameter applicationID: the application's reverse-DNS name, which the desktop knows it by - its entry and
    ///   its icon are named by it; a second launch under the same name brings the running application's window
    ///   forward instead.
    /// - Returns: the process's exit code.
    @discardableResult
    public static func run(applicationID: String) -> Int32 {
        let application = adw_application_new(applicationID, G_APPLICATION_DEFAULT_FLAGS)!
        gtk_window_set_default_icon_name(applicationID)
        connectSignal(UnsafeMutableRawPointer(application), "activate", number: 0) { application, _ in
            GTKRenderer.activated(application!.assumingMemoryBound(to: GtkApplication.self))
        }
        let status = g_application_run(application.of(GApplication.self), CommandLine.argc, CommandLine.unsafeArgv)
        g_object_unref(UnsafeMutableRawPointer(application))
        return status
    }
}
