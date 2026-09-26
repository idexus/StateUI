// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A way back a window offers the user, the same on every host: a stack's top page going, or the top sheet.
/// Design: docs/design/host/pages.md#the-way-back
@_spi(Host) public enum WayBack {
    /// The top page of the stack goes.
    case pop(MountedElement)

    /// The top sheet goes, `remaining` staying.
    case dismissSheet(remaining: Int)
}
