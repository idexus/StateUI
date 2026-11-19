// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension MotionLayout.Run {
    /// The program the host is handed for this description: it keeps the room the host says, and answers the
    /// layout's own size - where it says one - at the parameters as they stand, as its places are worked out.
    /// Design: docs/design/core/layout-program.md#the-program
    func program() -> HostLayoutProgram {
        var measure: (@MainActor (Double?, Double?) -> LayoutSize)?
        if let sized {
            measure = { width, height in sized(width, height, live()) }
        }
        return states.slot.program(revision: UInt64(description), measure: measure) { width, height in
            let room = Rect(0, 0, width, height)
            if states.room.wrappedValue != room { states.room.wrappedValue = room }
        }
    }
}
