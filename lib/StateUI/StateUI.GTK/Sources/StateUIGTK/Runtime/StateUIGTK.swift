// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK
import StateUIFoundation

/// Runs a StateUI application as native GTK 4 and libadwaita widgets in the application's own process.
///
/// An application's GTK head names the application to the host and hands it
/// the thread:
///
///     import HelloWorldUI
///     import StateUIGTK
///
///     registerApplication()
///     StateUIGTK.run(applicationID: "com.stateui.helloworld")
///
/// `.scripts/GTK/run-app.sh` builds the head and starts it. A control this
/// host does not present yet shows its name in red where it belongs.
public enum StateUIGTK {
    /// Starts GTK on this thread, runs the application until its last window closes, and ends the process with
    /// the code GTK ended with - a start GTK refused fails it.
    ///
    /// - Parameter applicationID: the application's reverse-DNS name, which the desktop knows it by - its entry and
    ///   its icon are named by it; a second launch under the same name brings the running application's window
    ///   forward instead, and hands it the links it was started with.
    public static func run(applicationID: String) -> Never {
        let application = adw_application_new(applicationID, STATEUI_APPLICATION_HANDLES_OPEN)!
        gtk_window_set_default_icon_name(applicationID)
        connectSignal(UnsafeMutableRawPointer(application), "activate", number: 0) { application, _ in
            GTKRenderer.activated(application!.assumingMemoryBound(to: GtkApplication.self))
        }
        // Links of a scheme the head's desktop entry takes: the application starts, or comes forward, with them.
        connectSignal(UnsafeMutableRawPointer(application), "open", number: 0) { application, files, count, _, _ in
            let addresses = (0..<Int(max(count, 0))).compactMap { place -> String? in
                guard let file = files?[place], let uri = g_file_get_uri(file) else { return nil }
                defer { g_free(uri) }
                return String(cString: uri)
            }
            GTKRenderer.activated(application!.assumingMemoryBound(to: GtkApplication.self))
            MainActor.assumeIsolated { GTKRenderer.shared?.openLinks(addresses) }
        }
        let status = g_application_run(application.of(GApplication.self), CommandLine.argc, CommandLine.unsafeArgv)
        g_object_unref(UnsafeMutableRawPointer(application))
        exit(status)
    }
}
