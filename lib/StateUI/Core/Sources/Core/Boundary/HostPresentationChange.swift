// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A presentation change a render carries to its host: the view it aims at, and the two waiters the host
/// answers - once its writes are applied, and once every movement they started under that view has ended.
/// Design: docs/design/core/journeys.md#a-change-and-what-it-started
@_spi(Host) public struct HostPresentationChange: Equatable, Sendable {
    /// Where the aimed view stands: the keys from the root down.
    public let place: [ElementID]

    /// The waiter of `PresentationChange.applied()`.
    public let applied: Int

    /// The waiter of `PresentationChange.settled()`.
    public let settled: Int
}
