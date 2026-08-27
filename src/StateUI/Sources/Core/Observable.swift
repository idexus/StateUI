// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Swift's own `@Observable`, refused where it would quietly do nothing.
//
// `@Observable` and `@StateClass` read as interchangeable and are not. Both make
// a class report its writes, and they report to different listeners.
// `@StateClass` calls this library's renderer, and the render that follows
// rebuilds the views that read the property. `@Observable` hands its
// notification to whoever armed an observation scope around the read - and
// nothing here arms one, so the notification reaches nobody: the write lands on
// the object, the interface goes on showing the old value, and nothing fails
// anywhere. That silence is what these two declarations turn into a warning
// naming the line that caused it.
//
// A warning rather than a refusal, because the model still WORKS as an object,
// and an application that arms the tracking itself is entitled to hold one. A
// crash would forbid that; a warning says the one sentence its author needs and
// leaves the choice with them.
//
// The two macros cannot be worn by one class either - both write accessors for
// the same stored property, and the compiler says so out loud - so a model is
// one or the other, and the one this library hears is `@StateClass`.
//
// Nothing ELSE about Observation is a problem here, which is why this is so
// narrow: the module imports no Foundation, ships on every platform this
// targets, and its tracking is synchronous, so none of the rules the rest of
// this library lives by is in play. It is simply not what drives a render.
//
// A model somebody else declared `@Observable`, which cannot be given
// `@StateClass` because a macro cannot be applied to another package's type, is
// bridged in the application: read it inside `withObservationTracking` and call
// `Renderer.shared.setNeedsRender()` from the `onChange`, remembering that the
// arming is one-shot and has to be renewed on every change.

import Observation

extension State where Value: Observable {
    /// Holds an `@Observable` model, and says that its writes reach nothing
    /// here - see the note at the top of Core/Observable.swift for what does.
    ///
    /// - Parameter wrappedValue: the model this state holds.
    @available(*, deprecated, message: """
        @Observable is not heard here: nothing arms an observation scope, so \
        writes to this model would leave the interface showing the old value. \
        Mark the class @StateClass instead - that is what reports a write to \
        the renderer.
        """)
    public convenience init(wrappedValue: Value) {
        self.init(holding: wrappedValue)
    }

    /// Holds an `@Observable` model at file scope, and says the same thing
    /// `init(wrappedValue:)` above does.
    ///
    /// - Parameter initialValue: the model this state holds.
    @available(*, deprecated, message: """
        @Observable is not heard here: nothing arms an observation scope, so \
        writes to this model would leave the interface showing the old value. \
        Mark the class @StateClass instead - that is what reports a write to \
        the renderer.
        """)
    public convenience init(_ initialValue: Value) {
        self.init(holding: initialValue)
    }
}
