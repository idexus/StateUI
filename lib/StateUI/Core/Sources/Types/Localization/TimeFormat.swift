// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How much of a time of day is written out: `.short` "7:30 PM", `.medium` "7:30:00 PM" - each on the clock and in
/// the words of the language and region in effect.
public enum TimeFormat: Int32, Hashable, Sendable, HostRepresentable {
    /// Hours and minutes.
    case short = 0

    /// Hours, minutes and seconds.
    case medium = 1
}

extension TimeFormat: StateChoice {}
