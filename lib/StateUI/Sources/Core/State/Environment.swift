// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The environment: an object provided above with `.environment()`, resolved
// below by type with `@Environment`.
// Design: docs/design/core/state.md#the-environment

/// One `@Environment` slot, which the differ fills as it walks.
protocol EnvironmentSlot: AnyObject {
    /// The type this slot resolves, as the identity the scope is keyed by.
    var wants: ObjectIdentifier { get }

    /// Hands the slot the nearest provided object of its type.
    func fill(_ object: AnyObject)

    /// What it was handed, or nothing - what `Input.slot` compares.
    var filled: AnyObject? { get }
}

/// An object an ancestor provided with `.environment()`, resolved by its type -
/// the annotation is the key, so there is no argument to pass.
///
///     struct BasketRow: ContentView {
///         @Environment var basket: Basket
///
///         var content: any View {
///             Label("\(basket.items.count) item(s)")
///         }
///     }
///
/// A body that reads one of the object's `@State` properties is rebuilt when it
/// changes; the provider, which only passes the reference, is not. Reading a
/// type no ancestor provided stops the program with its name, except the
/// standard providers and sessions, which every tree has.
@propertyWrapper
public final class Environment<Value: AnyObject>: @unchecked Sendable {
    /// What the differ resolved for this view's place in the tree - written and read
    /// on the UI thread.
    private var resolved: Value?

    /// Declares the slot. The differ fills it before the view's body builds.
    public init() {}

    /// The nearest object of this type an ancestor provided - or, where no walk
    /// filled the slot, the standard provider of the type, which is what lets the
    /// application itself declare one.
    public var wrappedValue: Value {
        if let resolved {
            return resolved
        }

        if let standard = StandardEnvironment.object(for: ObjectIdentifier(Value.self)) as? Value {
            resolved = standard
            return standard
        }

        preconditionFailure("""
            @Environment asked for a \(Value.self) and no ancestor \
            provided one. Write .environment(...) with a \(Value.self) \
            on a view above this one.
            """)
    }

    /// The provided object lent on as a `Binding`, so one property of it can
    /// be handed to an input: `TextField($context.note)`. Assigning the WHOLE
    /// binding a new object stops the program - the object is the ancestor's
    /// to provide, and only its properties are writable from below.
    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { _ in
                preconditionFailure("""
                    An environment \(Value.self) is provided by an ancestor \
                    and cannot be replaced from below. Write its properties \
                    instead - $context.someProperty lends one on.
                    """)
            })
    }
}

extension Environment: EnvironmentSlot {
    /// The identity of `Value`, which the provided object is keyed by.
    var wants: ObjectIdentifier { ObjectIdentifier(Value.self) }

    var filled: AnyObject? { resolved }

    /// Takes the resolved object; a mismatch leaves the slot for its read to report.
    func fill(_ object: AnyObject) {
        resolved = object as? Value ?? resolved
    }
}
