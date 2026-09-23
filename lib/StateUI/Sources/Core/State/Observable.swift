// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `@Observable` held in a `@State` is refused with a warning: nothing here arms
// an observation scope, so its writes would reach no renderer.
// Design: docs/design/core/state.md#an-observable-model

import Observation

extension State where Value: Observable {
    /// Holds an `@Observable` model, warning that its writes reach nothing here.
    /// - Parameter wrappedValue: the model this state holds.
    @available(*, deprecated, message: """
        @Observable is not heard here: nothing arms an observation scope, so \
        writes to this model would leave the interface showing the old value. \
        Declare its properties @State instead - that is what reports a write \
        to the renderer.
        """)
    public convenience init(wrappedValue: Value) {
        self.init(holding: wrappedValue)
    }

    /// Holds an `@Observable` model at file scope, with the same warning.
    /// - Parameter initialValue: the model this state holds.
    @available(*, deprecated, message: """
        @Observable is not heard here: nothing arms an observation scope, so \
        writes to this model would leave the interface showing the old value. \
        Declare its properties @State instead - that is what reports a write \
        to the renderer.
        """)
    public convenience init(_ initialValue: Value) {
        self.init(holding: initialValue)
    }
}
