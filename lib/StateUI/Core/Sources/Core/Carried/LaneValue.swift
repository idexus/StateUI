// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A value a state carries as numbers, one lane each - every `StateValue` but
/// text. This library's own.
///
/// The type says what a host reads its lanes as, so a value said from a state
/// reaches the control as the same value said directly. Numbers unless said:
/// `Bool` is read as a Boolean, `Color` as a colour, and a `StateChoice` as its
/// case.
/// Design: docs/design/core/state.md#what-a-host-reads-lanes-as
public protocol LaneValue: StateValue {
    /// What a host reads this value's lanes as.
    static var laneKind: LaneKind { get }
}

extension LaneValue {
    /// Numbers: one lane a number, more a run of numbers.
    public static var laneKind: LaneKind { .number }
}
