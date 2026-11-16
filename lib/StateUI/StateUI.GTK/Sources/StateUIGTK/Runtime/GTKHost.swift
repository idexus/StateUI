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
///     HelloWorldApp.register()
///     GTKHost.run()
///
/// `stateui run --host gtk` builds the head and starts it. A control this
/// host does not present yet shows its name in red where it belongs.
public enum GTKHost {
    /// Starts GTK on this thread, runs the application until its last window closes, and ends the process with
    /// the code GTK ended with - a start GTK refused fails it.
    ///
    /// What the application is - its identifier, name, version - comes from the `stateui.json` its head carries
    /// beside the program: the desktop knows it by the identifier - its entry and its icon are named by it - and a
    /// second launch under it brings the running application's window forward, handing it the links it was started
    /// with. A program standing without the file runs unnamed.
    public static func run() -> Never {
        let identifier = carried?.packageName
        let application = adw_application_new(identifier, STATEUI_APPLICATION_HANDLES_OPEN)!
        if let carried {
            g_set_application_name(carried.name)
            gtk_window_set_default_icon_name(carried.packageName)
        }
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

    /// What the head's `stateui.json` beside this program says; nil where none stands there.
    /// Design: docs/design/tooling/projects.md#a-head-carries-what-the-application-is
    static let carried: HostApplicationInfo? = {
        guard let program = g_file_read_link("/proc/self/exe", nil) else { return nil }
        defer { g_free(program) }
        return carried(beside: String(cString: program))
    }()

    /// What the `stateui.json` beside the program at `program` says; nil where none stands there.
    static func carried(beside program: String) -> HostApplicationInfo? {
        let file = String(program[..<(program.lastIndex(of: "/") ?? program.startIndex)]) + "/stateui.json"
        var contents: UnsafeMutablePointer<gchar>?
        var length: gsize = 0
        guard g_file_get_contents(file, &contents, &length, nil) != 0, let contents else { return nil }
        defer { g_free(contents) }
        return contents.withMemoryRebound(to: UInt8.self, capacity: Int(length)) {
            HostApplicationInfo(applicationFile: Array(UnsafeBufferPointer(start: $0, count: Int(length))))
        }
    }
}
