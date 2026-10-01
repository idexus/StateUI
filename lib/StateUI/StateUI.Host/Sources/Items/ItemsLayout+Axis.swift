// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension ItemsLayout {
    /// Whether the items run across - a row, which scrolls sideways and whose items ask for their width.
    @_spi(Host) public var isAcross: Bool {
        if case .row = self { return true }
        return false
    }
}
