// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A clock a test winds by hand, in milliseconds: a host's display frames run at the time it says.
@MainActor
public final class TestClock {
    /// The time now, in milliseconds.
    public var now = 0.0

    /// A clock at 0.
    public init() {}
}
