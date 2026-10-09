// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The environment: what the library offers, read by name, and an object
// provided above with `.environment()`, read by its type.
// Design: docs/design/core/state.md#the-environment

/// One `@Environment` slot, which the differ fills as it walks.
@MainActor
protocol EnvironmentSlot: AnyObject {
    /// The type this slot resolves, as the identity the scope is keyed by.
    var wants: ObjectIdentifier { get }

    /// Hands the slot the nearest provided object of its type.
    func fill(_ object: AnyObject)

    /// What it was handed, or nothing - what `Input.slot` compares.
    var filled: AnyObject? { get }
}

/// What the environment holds at a view's place. What the library offers is read
/// by its name - the application, the scene, the window, the device and the
/// locale (`EnvironmentValues`):
///
///     @Environment(\.window) private var window
///
/// An object an ancestor provided with `.environment()` is read by its type -
/// the annotation is the key, so there is no argument to pass:
///
///     struct BasketRow: View {
///         @Environment var basket: Basket
///
///         var body: some View {
///             Text("\(basket.items.count) item(s)")
///         }
///     }
///
/// A body that reads one of the object's `@State` properties is rebuilt when it
/// changes; the provider, which only passes the reference, is not. Reading a
/// type no ancestor provided stops the program with its name, and so does
/// reading one of the library's by its type.
@propertyWrapper
@MainActor
public final class Environment<Value: AnyObject> {
    /// What the differ resolved for this view's place in the tree - written and read
    /// on the UI thread.
    private var resolved: Value?

    /// Reads what the library offers by its name: `@Environment(\.window)`.
    public init(_ name: KeyPath<EnvironmentValues, Value>) {}

    /// Reads an object an ancestor provided with `.environment()`, found by its
    /// type. The differ fills it before the view's body builds.
    public init() {
        if let refusal = Self.refusal { preconditionFailure(refusal) }
    }

    /// Why the library's own object is not read by its type - the name it is read by; nil for any other type.
    static var refusal: String? {
        StandardEnvironment.names[ObjectIdentifier(Value.self)].map { name in
            "\(Value.self) is the library's: read it by its name, @Environment(\\.\(name)) private var \(name)."
        }
    }

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

    /// The provided object, lent on a property at a time: `TextField($context.note)`.
    /// The object itself is the ancestor's to provide, so nothing replaces it from below.
    public var projectedValue: EnvironmentLender<Value> {
        EnvironmentLender { self.wrappedValue }
    }
}

/// An object an ancestor provided, lent on a property at a time - what `$context` is
/// for an `@Environment var context`. It lends properties only: the object is the
/// ancestor's, so there is no road to replace it.
///
///     TextField($context.note)
@dynamicMemberLookup
@MainActor
public struct EnvironmentLender<Value: AnyObject> {
    private let object: () -> Value

    init(_ object: @escaping () -> Value) {
        self.object = object
    }

    /// One property of the object, as a binding that writes through it.
    public subscript<Subject>(
        dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject> & Sendable
    ) -> Binding<Subject> {
        let object = object
        return Binding(get: { object()[keyPath: keyPath] }, set: { object()[keyPath: keyPath] = $0 })
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
