// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The local day and time of day as a platform's clock reads them, the numbers `currentTime` answers.
/// Design: docs/design/host/runtime.md#acts
@_spi(Host) public struct LocalTime: Equatable, Sendable {
    /// The year, the month from 1 and the day of the month from 1.
    public var year, month, day: Int

    /// The hour from 0 to 23, the minute, the second and the millisecond.
    public var hour, minute, second, millisecond: Int

    /// A local day and time of day.
    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, millisecond: Int) {
        (self.year, self.month, self.day) = (year, month, day)
        (self.hour, self.minute, self.second, self.millisecond) = (hour, minute, second, millisecond)
    }
}
