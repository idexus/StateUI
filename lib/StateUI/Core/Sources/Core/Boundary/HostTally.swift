// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What this process's renders came to - the tally a host prints to count leaks, and the work a benchmark counts.
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

    /// How many runs are under way or wait their turn now - a handler's, or a task's through a gate.
    public let runs: Int

    /// How many composed views' bodies the renders built.
    public let built: Int

    /// How many views the renders walked for their state and inputs.
    public let walks: Int

    /// How many identities the renders named with a text: a walked part, a statement, a conversion, a layout slot.
    public let texts: Int
}
