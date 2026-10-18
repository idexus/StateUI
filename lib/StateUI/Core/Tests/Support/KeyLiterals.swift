// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A test writes a key as its name; the library makes a key only where it declares one, so it has no literal form.
// Design: docs/design/core/contracts.md#a-key-is-a-number

@_spi(Host) import StateUI

extension Prop: ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(name) }
}

extension Event: ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(name) }
}

extension Act: ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(name) }
}
