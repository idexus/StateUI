// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Int {
    /// The whole number nearest `number`, or nil where no `Int` holds it - not a number, infinite, or beyond an
    /// `Int`: a number kept on disk or read from the host never stops the application.
    init?(nearest number: Double) {
        guard number.isFinite, let whole = Int(exactly: number.rounded()) else { return nil }

        self = whole
    }

    /// The number a whole number crosses to the host as. A number holds every whole number exactly only up to 2^53;
    /// one past it arrives rounded, said once.
    var crossing: Double {
        if magnitude > 1 << 53 {
            complain("A whole number past 2^53 crossed to the host and arrives rounded: a number holds every whole "
                + "number exactly only up to 2^53. Keep such a value as words, or split it.")
        }
        return Double(self)
    }
}
