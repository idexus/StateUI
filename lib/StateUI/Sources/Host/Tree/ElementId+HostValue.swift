// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension ElementId {
    /// The key as an event carries it: an author's name as its text, a counted key as its number.
    @_spi(Host) public var hostValue: HostValue {
        switch self {
        case .manual(let name): .string(name)
        case .auto(let number): .number(Double(number))
        }
    }
}
