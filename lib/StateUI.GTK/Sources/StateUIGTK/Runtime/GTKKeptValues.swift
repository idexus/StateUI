// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// The application's kept values in a file of the host's own - the desktop keeps no store an application can use
/// without a schema installed: read before the first scene, written whole as each changes.
/// Design: docs/design/platforms/gtk/runtime.md#kept-values
@MainActor
enum GTKKeptValues {
    /// The folder the file stands in; nil for the user's state folder, under the application's ID.
    static var folder: String?

    /// The file the application's values stand in.
    static func file(for applicationID: String) -> String {
        (folder ?? String(cString: g_get_user_state_dir()) + "/" + applicationID) + "/kept values.txt"
    }

    /// Hands the core every kept value there is, before the first render reads one.
    static func restore(into core: CoreLink, applicationID: String) {
        let keys = core.persistentKeys
        guard !keys.isEmpty else { return }
        core.restorePersistent(read(file(for: applicationID)).restored(for: keys))
    }

    /// Keeps a key's new value, as the act `persistValue` carries it: the whole file written aside, then moved into
    /// place, so a failed write leaves the old.
    static func keep(_ call: HostActCall, core: CoreLink, applicationID: String) {
        let file = file(for: applicationID)
        var kept = read(file)
        guard kept.keep(call.arguments, keys: core.persistentKeys) else { return }

        if !write(kept, to: file) { GTKLog.error("the kept values could not be written") }
    }

    /// Writes `kept` whole to `file`, aside and then in its place; whether it was written.
    static func write(_ kept: KeptValuesText, to file: String) -> Bool {
        if let folder = g_path_get_dirname(file) {
            g_mkdir_with_parents(folder, 0o700)
            g_free(folder)
        }
        return g_file_set_contents(file, kept.text, -1, nil) != 0
    }

    /// What `file` holds; nothing where there is no such file.
    static func read(_ file: String) -> KeptValuesText {
        var contents: UnsafeMutablePointer<gchar>?
        guard g_file_get_contents(file, &contents, nil, nil) != 0, let contents else { return KeptValuesText("") }
        defer { g_free(contents) }
        return KeptValuesText(String(cString: contents))
    }
}
