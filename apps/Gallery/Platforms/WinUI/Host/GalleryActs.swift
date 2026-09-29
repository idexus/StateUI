// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGalleryWinUI
import GalleryUI
import StateUIWinUI
import WinSDK

/// The gallery's own acts, as this host answers them.
///
/// `GalleryContract` declares each name with what it takes and answers - see
/// Sources/Samples/Interop/GalleryContract.swift - and this is the half that performs them. An act aimed at a control
/// is its control's, registered beside it: `RatingBarControl.register()` performs `flash`. `Gallery.Nobody` is
/// registered nowhere on purpose: the "Calling WinUI" sample calls it to show what a missing registration does.
enum GalleryActs {
    /// Registers every act this host performs. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIActs.add(GalleryContract.setClipboard) { text in
            Clipboard.write(text)
        }
        StateUIActs.add(GalleryContract.readClipboard) {
            Clipboard.read()
        }
        StateUIActs.add(GalleryContract.batteryLevel) {
            GalleryPower.battery()
        }
    }
}

/// The system's clipboard, its words as UTF-16 - what every Windows application reads and writes.
enum Clipboard {
    /// Puts `text` on the clipboard in place of whatever it held.
    static func write(_ text: String) {
        guard OpenClipboard(nil) else { return }
        defer { CloseClipboard() }
        EmptyClipboard()

        let units = Array(text.utf16) + [0]
        guard let memory = GlobalAlloc(UINT(GMEM_MOVEABLE), SIZE_T(units.count * 2)) else { return }
        guard let locked = GlobalLock(memory) else {
            GlobalFree(memory)
            return
        }
        units.withUnsafeBytes { bytes in locked.copyMemory(from: bytes.baseAddress!, byteCount: bytes.count) }
        GlobalUnlock(memory)
        // The clipboard owns what it took; what it refused is freed here.
        if SetClipboardData(UINT(CF_UNICODETEXT), memory) == nil { GlobalFree(memory) }
    }

    /// The words on the clipboard; nothing where it holds none.
    static func read() -> String {
        guard OpenClipboard(nil) else { return "" }
        defer { CloseClipboard() }
        guard let memory = GetClipboardData(UINT(CF_UNICODETEXT)), let locked = GlobalLock(memory) else { return "" }
        defer { GlobalUnlock(memory) }
        return String(decodingCString: locked.assumingMemoryBound(to: UInt16.self), as: UTF16.self)
    }
}

/// The battery as Windows knows it, which the gallery's relay reads.
enum GalleryPower {
    /// The battery's level, 0 through 1, and whether the power is plugged in - both zero and false on a desktop that
    /// has no battery to report, which is an ordinary answer rather than a failure.
    static func battery() -> (Double, Bool) {
        var level = 0.0
        var charging = false
        gallery_battery(&level, &charging)
        return (level, charging)
    }
}
