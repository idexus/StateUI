// The ENVIRONMENT: an object provided above, resolved below - by TYPE.
//
// A model shared by a whole branch is otherwise passed by hand, an initializer
// argument per view on the way down. `.environment(object)` provides it to a
// subtree instead, and `@Environment var context: MyContext` on any view below
// resolves the NEAREST object of that type - the annotation is the key, so
// there is nothing to spell and nothing to collide.
//
// The name sits with the rest of the state layer - `@State` owns, `@Binding`
// borrows, `@Environment` resolves - and MAUI has no equivalent concept: its
// `BindingContext` is a different thing entirely, and in this library it
// carries a list row's POSITION, which is also why this is not called Context.
//
// HOW IT MOVES, and what it deliberately does not touch:
//
//   - `.environment()` stores the object on the Node as a NON-WIRE field,
//     `assigned`'s pattern. Nothing about it ever crosses the boundary; the
//     C# side has no idea environments exist.
//   - The differ keeps a stack of them as it walks - both walks, the full
//     build and the clean one - and fills every `@Environment` slot of a
//     composed view from that stack BEFORE the body builds, so handlers that
//     captured the view read a resolved object ever after. Refilled on every
//     walk that builds the view, never adopted: the `ControlBox` reasoning.
//   - INVALIDATION IS UNTOUCHED. Reading a provided `@StateClass` object's
//     property inside a body records the read against that element, exactly
//     as it does for an object passed by hand - so a write rebuilds the
//     readers and nobody else. The PROVIDER passes a reference and reads no
//     property, which is why it is not rebuilt by changes IN the object; only
//     replacing the object itself - a write to the `@State` box holding it -
//     rebuilds the provider, and rightly, since the whole branch must learn.
//
// The one place that needs care is `.memoized(by:)`: an unchanged token says
// the INPUTS are unchanged, and the nearest provided object is not an input
// the token can see. The differ therefore snapshots the environments visible
// at a memo and compares them too - see `RenderedNode.seen`.

/// What the differ fills as it walks: one slot per `@Environment` a composed
/// view declares, collected by the same Mirror walk that finds `@State` boxes.
protocol EnvironmentSlot: AnyObject {
    /// The type this slot resolves, as the identity the scope is keyed by.
    var wants: ObjectIdentifier { get }

    /// Hands the slot the nearest provided object of its type.
    func fill(_ object: AnyObject)
}

/// An object an ancestor provided with `.environment()`, resolved by TYPE -
/// the annotation is the key, so there is no argument to pass.
///
///     struct BasketRow: ContentView {
///         @Environment var basket: Basket
///
///         var content: Element {
///             Label("\(basket.items.count) item(s)")
///         }
///     }
///
/// The object is usually a `@StateClass`, and the ordinary rules then apply:
/// a body that READS a property depends on the object and is rebuilt when it
/// changes; the provider, which only passes the reference, is not. `$basket`
/// lends it on as a `Binding`, so `$basket.note` hands an `Entry` one
/// property, exactly as a `@State` model does.
///
/// Reading one that no ancestor provided stops the program with a message
/// naming the type: an environment that silently answered nothing would be
/// the failure this library refuses everywhere else. The seven standard
/// providers - `Battery`, `Connectivity`, `DeviceDisplay`, `LocaleInfo`,
/// `DeviceInfo`, `AppInfo`, `WindowInfo` - are the exception, being provided
/// to every tree by the host without anybody writing `.environment()`.
@propertyWrapper
public final class Environment<Value: AnyObject>: @unchecked Sendable {
    /// What the differ resolved for this view's position in the tree. Written
    /// by the walk that builds the view, read by the body and by handlers
    /// that captured the view - all on the thread MAUI draws on.
    private var resolved: Value?

    /// Declares the slot. The differ fills it before the view's body builds.
    public init() {}

    /// The nearest object of this type an ancestor provided - or, for a slot
    /// nothing filled, the STANDARD provider of this type, when there is one.
    ///
    /// The fallback is what lets the APPLICATION itself declare
    /// `@Environment var device: DeviceInfo`: its window build runs outside
    /// the differ, so no walk fills its slots - and a standard provider is
    /// always there by definition, one per process, so answering it is exact
    /// rather than a guess. A type that is neither provided nor standard
    /// still stops the program, naming itself.
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
    /// be handed to an input: `Entry($context.note)`. Assigning the WHOLE
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
    /// The identity of `Value`, which is what `.environment()` keyed the
    /// provided object by.
    var wants: ObjectIdentifier { ObjectIdentifier(Value.self) }

    /// Takes the resolved object. The differ matched the type identity
    /// already, so the cast is belt and braces; a mismatch leaves the slot
    /// as it was, and the read says so.
    func fill(_ object: AnyObject) {
        resolved = object as? Value ?? resolved
    }
}
