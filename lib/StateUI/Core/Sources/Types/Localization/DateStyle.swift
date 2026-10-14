// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How much of a day's name is written out: `.long` "September 30, 2026", `.medium` "Sep 30, 2026", `.short`
/// "9/30/26" - each in the order and the words of the language and region in effect.
public enum DateStyle: Hashable, Sendable {
    /// Digits only.
    case short

    /// The month shortened.
    case medium

    /// The month written out.
    case long
}
