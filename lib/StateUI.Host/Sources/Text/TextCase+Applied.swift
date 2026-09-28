// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Words in the case the tree asks for, the same on every host.
@_spi(Host) extension TextCase {
    /// `text` as written, or in one case throughout.
    public func applied(to text: String) -> String {
        switch self {
        case .lowercase: text.lowercased()
        case .uppercase: text.uppercased()
        case .none, .default: text
        }
    }
}
