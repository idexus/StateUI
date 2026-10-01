// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// What a handler heard, in order.
public final class Received<Value>: Sendable {
    private let received = State(wrappedValue: [Value]())

    /// Nothing heard yet.
    public init() {}

    /// Everything heard, in order.
    public var values: [Value] {
        get { received.wrappedValue }
        set { received.wrappedValue = newValue }
    }
}
