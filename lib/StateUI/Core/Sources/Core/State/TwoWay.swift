// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A value read and written through whoever holds it - a whole state's
/// `Binding`, or a `Binding.Proxy` - which is what a two-way control takes.
///
///     TextField($name)            // the whole state, carried by the host
///     TextField($profile.name)    // one property of a state, through the whole
///
/// Either shows the value and writes back what the user changes. Only a
/// `Binding` is the state itself, so only it rides the host's channel, has a
/// journey and wakes an engine; what needs those takes `Binding` alone.
@MainActor
public protocol TwoWay<Value> {
    /// The type of the value read and written.
    associatedtype Value

    /// The value, read and written through whoever holds it.
    var wrappedValue: Value { get nonmutating set }
}

extension TwoWay {
    /// The whole state's binding, which the host carries; nothing for a proxy, which a two-way control describes.
    /// Design: docs/design/views/bindings.md#two-way-controls
    var whole: Binding<Value>? { self as? Binding<Value> }
}
