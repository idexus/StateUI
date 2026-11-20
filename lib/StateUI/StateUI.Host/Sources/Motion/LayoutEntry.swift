// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How a child given its first place comes to it.
/// Design: docs/design/host/motion.md#a-view-that-enters
@_spi(Host) public enum LayoutEntry: Equatable, Sendable {
    /// With its layout, as that is arranged for the first time.
    case appearing

    /// Into a layout already standing, whose children animate under `law` - none where they arrive.
    case joining(under: Motion)
}
