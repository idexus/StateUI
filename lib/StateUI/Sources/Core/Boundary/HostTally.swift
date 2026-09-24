// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What this process's renders came to - the tally a host prints to count leaks.
/// Design: docs/design/core/diagnostics.md#the-tally
@_spi(Host) public struct HostTally: Equatable, Sendable {
    /// How many renders this process made.
    public let renders: Int

    /// How many of them carried nothing.
    public let empty: Int

    /// How many writes asked for no render, with nobody reading them.
    public let refused: Int

    /// How many rendered elements are alive now.
    public let alive: Int
}
