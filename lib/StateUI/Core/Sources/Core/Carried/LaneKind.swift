// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a host reads a carried value's lanes as. This library's own.
public enum LaneKind: Sendable {
    /// Numbers: one lane a number, more a run of numbers - a `Double`, a
    /// `Point`, a date.
    case number

    /// A Boolean, true where its one lane is not nought.
    case boolean

    /// A case of a closed vocabulary, its one lane the case's number.
    case choice

    /// A colour: red, green, blue and alpha, each from nought to one.
    case color
}
