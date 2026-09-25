// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Whose a list's or a calendar's opening and closing are: the program's are not reported, the user's are - the
/// user closing what the program opened too. WinUI may show it a moment after it is asked, so the program's asking
/// stands until the list says it opened or closed, or the program asks otherwise.
/// Design: docs/design/platforms/winui/controls.md#a-picker
struct WinUIShowing {
    private var programOpens = false
    private var programCloses = false

    /// The program asks to open or close what shows now as `shown`; whether WinUI has to be asked.
    mutating func programAsks(open: Bool, shown: Bool) -> Bool {
        programOpens = open && !shown
        programCloses = !open && shown
        return open != shown
    }

    /// It opened or closed; whether that was the user's.
    mutating func heard(open: Bool) -> Bool {
        if open, programOpens {
            programOpens = false
            return false
        }
        if !open, programCloses {
            programCloses = false
            return false
        }
        return true
    }
}
