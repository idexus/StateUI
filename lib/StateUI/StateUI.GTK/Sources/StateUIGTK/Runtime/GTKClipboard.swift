// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// The display's clipboard, as GDK holds it: written at once, read through a callback.
/// Design: docs/design/platforms/gtk/runtime.md#the-clipboard
@MainActor
enum GTKClipboard {
    /// Puts `words` on the clipboard in place of whatever it held.
    static func write(_ words: String) {
        gdk_clipboard_set_text(clipboard, words)
    }

    /// Reads the words on the clipboard and hands them to `answered` - nil where it holds none.
    static func read(_ answered: @escaping @MainActor (String?) -> Void) {
        let waiting = Unmanaged.passRetained(Waiting(answered)).toOpaque()
        gdk_clipboard_read_text_async(clipboard, nil, { source, result, data in
            let waiting = Unmanaged<Waiting>.fromOpaque(data!).takeRetainedValue()
            let words = gdk_clipboard_read_text_finish(OpaquePointer(source), result, nil)
            let read = words.map { String(cString: $0) }
            g_free(words)
            MainActor.assumeIsolated { waiting.answered(read) }
        }, waiting)
    }

    private static var clipboard: OpaquePointer? { gdk_display_get_clipboard(gdk_display_get_default()) }

    /// What waits for a read, carried through the callback's data.
    private final class Waiting {
        let answered: @MainActor (String?) -> Void

        init(_ answered: @escaping @MainActor (String?) -> Void) {
            self.answered = answered
        }
    }
}
