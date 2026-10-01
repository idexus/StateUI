// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Who opened or closed what a picker shows - its list, its calendar, its clock - the same on every host: what the
/// program asks for is heard by nobody, what the user does is, the closing of what the program opened included.
/// Design: docs/design/host/runtime.md#a-day-and-a-time
@_spi(Host) public struct PickerOpening: Sendable {
    private var programOpens = false
    private var programCloses = false

    /// A picker nobody has opened.
    public init() {}

    /// The program asks to open or close what shows now as `shown`; whether the toolkit has to be asked.
    public mutating func programAsks(open: Bool, shown: Bool) -> Bool {
        programOpens = open && !shown
        programCloses = !open && shown
        return open != shown
    }

    /// It opened or closed; whether that was the user's.
    public mutating func heard(open: Bool) -> Bool {
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
