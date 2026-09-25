// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
import GalleryUI
import StateUIGTK

/// The gallery's own acts, as this host answers them.
///
/// `GalleryContract` declares each name with what it takes and answers - see
/// Sources/Samples/Interop/GalleryContract.swift - and this is the half that performs them. An act aimed at a control
/// is its control's, registered beside it: `RatingBarWidget.register()` performs `flash`. `Gallery.Nobody` is
/// registered nowhere on purpose: the "Calling GTK" sample calls it to show what a missing registration does.
enum GalleryActs {
    /// Registers every act this host performs. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIActs.add(GalleryContract.setClipboard) { text in
            gdk_clipboard_set_text(clipboard(), text)
        }
        // GTK reads a clipboard only asynchronously: the performer awaits it.
        StateUIActs.add(GalleryContract.readClipboard) {
            await clipboardText()
        }
        StateUIActs.add(GalleryContract.batteryLevel) {
            GalleryPower.battery()
        }
    }

    private static func clipboard() -> OpaquePointer? {
        gdk_display_get_clipboard(gdk_display_get_default())
    }

    /// The words on the clipboard, however long GTK takes to read them; nothing where it holds none.
    private static func clipboardText() async -> String {
        await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            let waiting = Unmanaged.passRetained(Waiting(continuation)).toOpaque()
            gdk_clipboard_read_text_async(clipboard(), nil, { source, result, data in
                let waiting = Unmanaged<Waiting>.fromOpaque(data!).takeRetainedValue()
                let text = gdk_clipboard_read_text_finish(OpaquePointer(source), result, nil)
                waiting.continuation.resume(returning: text.map { String(cString: $0) } ?? "")
                g_free(text)
            }, waiting)
        }
    }

    /// A continuation carried through a C callback's data.
    private final class Waiting: Sendable {
        let continuation: CheckedContinuation<String, Never>

        init(_ continuation: CheckedContinuation<String, Never>) {
            self.continuation = continuation
        }
    }
}
