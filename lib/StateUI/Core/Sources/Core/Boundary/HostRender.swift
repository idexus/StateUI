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

    /// The elements standing that came back where one of their authored identity left, each with the id a host
    /// knows that one by - the whole table in every render, read as an element is made.
    /// Design: docs/design/core/identity-and-diffing.md#an-identity-that-comes-back
    public let returnsAs: [ElementID: ElementID]
}
