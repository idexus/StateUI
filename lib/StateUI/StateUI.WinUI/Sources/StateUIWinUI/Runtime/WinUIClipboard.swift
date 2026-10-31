// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import WinSDK

/// The system's clipboard, its words as UTF-16 - what every Windows application reads and writes.
/// Design: docs/design/platforms/winui/runtime.md#the-clipboard
enum WinUIClipboard {
    /// Puts `words` on the clipboard in place of whatever it held.
    static func write(_ words: String) {
        guard OpenClipboard(nil) else { return }
        defer { CloseClipboard() }
        EmptyClipboard()

        let units = Array(words.utf16) + [0]
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

    /// The words on the clipboard; nil where it holds none.
    static func read() -> String? {
        guard OpenClipboard(nil) else { return nil }
        defer { CloseClipboard() }
        guard let memory = GetClipboardData(UINT(CF_UNICODETEXT)), let locked = GlobalLock(memory) else { return nil }
        defer { GlobalUnlock(memory) }
        return String(decodingCString: locked.assumingMemoryBound(to: UInt16.self), as: UTF16.self)
    }
}
