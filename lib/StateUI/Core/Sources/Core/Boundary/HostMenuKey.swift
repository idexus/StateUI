// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The authored identity by which menu declarations compose across a visible page path.
@_spi(Host) public enum HostMenuKey: Hashable, Sendable {
    /// A name the application wrote as a string.
    case name(String)

    /// A platform menu named by its typed role, distinct from every authored string.
    case standard(StandardMenu)

    /// A number shared by live declarations whose other authored identity values compare equal.
    case value(Int)
}
