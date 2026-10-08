// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One state channel attached to a native property.
@_spi(Host) public struct HostStateBinding: Equatable, Sendable {
    /// The channel number quoted back to StateUI by a host.
    public let state: Int32

    /// Which direction the value crosses.
    public let mode: HostStateMode

    /// Which native-host channel carries the value.
    public let kind: HostStateKind

    /// What the value's lanes are read as - its type says; nil for text, which has none.
    public let laneKind: HostLaneKind?

    /// One attachment between a state channel and a native property.
    public init(state: Int32, mode: HostStateMode, kind: HostStateKind, laneKind: HostLaneKind?) {
        self.state = state
        self.mode = mode
        self.kind = kind
        self.laneKind = laneKind
    }
}

extension HostStateBinding {
    init(_ entry: StateEntry) {
        state = entry.number
        mode = entry.mode
        kind = entry.kind
        laneKind = entry.laneKind
    }
}
