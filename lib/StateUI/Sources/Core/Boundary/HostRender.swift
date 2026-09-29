// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One renderer result delivered directly to a native Swift host.
@_spi(Host) public struct HostRender: Sendable {
    /// The generation the host should retain after applying this result.
    public let generation: Int32

    /// Whether the root patch completely describes the current tree.
    public let complete: Bool

    /// The root element's sparse patch.
    public let root: HostPatch
}
