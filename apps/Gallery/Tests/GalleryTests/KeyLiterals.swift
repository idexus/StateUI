// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A test writes a key as its name; the library makes a key only where it declares one, so it has no literal form.

import StateUI

extension Prop: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(name) }
}

extension Event: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(name) }
}

extension Act: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral name: String) { self.init(name) }
}
