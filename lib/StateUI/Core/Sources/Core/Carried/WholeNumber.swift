// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Int {
    /// The whole number nearest `number`, or nil where no `Int` holds it - not a number, infinite, or beyond an
    /// `Int`: a number kept on disk or read from the host never stops the application.
    init?(nearest number: Double) {
        guard number.isFinite, let whole = Int(exactly: number.rounded()) else { return nil }

        self = whole
    }
}
