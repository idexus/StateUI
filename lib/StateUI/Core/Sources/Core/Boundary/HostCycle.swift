// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The result of advancing one native-host clock.
@_spi(Host) public struct HostCycle: Equatable, Sendable {
    /// Complete values for the state channels changed by this cycle.
    public let changes: [HostStateChange]

    /// Whether an engine or pending state needs another cycle.
    public let continues: Bool
}

/// One state value published by a completed host cycle.
@_spi(Host) public struct HostStateChange: Equatable, Sendable {
    /// The state channel whose value changed.
    public let state: Int32

    /// The lanes that changed, or every bit for text.
    public let changed: UInt64

    /// The complete value after the cycle.
    public let value: HostStateValue

    /// One sparse state change published at the end of a host cycle.
    public init(state: Int32, changed: UInt64, value: HostStateValue) {
        self.state = state
        self.changed = changed
        self.value = value
    }
}
