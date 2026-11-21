// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A presentation change a render carries to its host: the view it aims at, and the two waiters the host
/// answers - once its writes are applied, and once every movement they started under that view has ended.
/// Design: docs/design/core/journeys.md#a-change-and-what-it-started
@_spi(Host) public struct HostPresentationChange: Equatable, Sendable {
    /// Where the aimed view stands: the keys from the root down.
    public let place: [ElementID]

    /// The states a host carries that the change's writes sent somewhere, by their numbers, in ascending order:
    /// a movement of one shown under the aimed view is the change's to wait for.
    public let states: [Int32]

    /// The waiter of `PresentationChange.applied()`.
    public let applied: Int

    /// The waiter of `PresentationChange.settled()`.
    public let settled: Int
}
