// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// State that lives in a class rather than in a box.
//
// `@State` answers one question - a view is a value, rebuilt every render, so
// where does its value live - and it answers it by owning the value itself. A
// write goes through the box, and the box asks for another render. That is the
// whole of Core/State.swift.
//
// A CLASS is the case that answer does not cover. Put one in a `@State` and the
// box holds a reference: `model.name = "…"` never touches the box, so nothing
// asks for a render and the interface goes on showing the old name. Nothing
// warns, because nothing is wrong - the write simply happened somewhere the
// renderer was not looking.
//
// `@StateClass` is where it looks. It gives every stored `var` on the class the
// two lines an author would otherwise write by hand, so a write to a property
// says exactly what a write to a `@State` says - AND ABOUT THE SAME THING: one
// property. A read records the PROPERTY that was read and a write names the
// property that was written, so `basket.note = "x"` rebuilds the closures that
// read `note` and leaves the ones reading `items` standing, exactly as two
// `@State`s would. What makes that cheap is that nothing in the renderer has
// to know: each tracked property carries a `TrackedKey` of its own, and its
// IDENTITY is what the read records and the write names - the same
// `ObjectIdentifier` a `@State`'s storage is known by. See Core/Diff.swift.
//

// It is not `@State` on the class either, tempting as that reads. `@State` on a
// property makes the value SURVIVE a rebuild; this makes writes VISIBLE, and
// the two are needed together - `@State private var basket = Basket()` holds a
// `@StateClass` class. One word for both would promise that the second half is
// unnecessary, and a `var basket = Basket()` written without the wrapper
// compiles, loses its instance on every render, and says nothing.

/// A class whose properties ask for a render when they are written.
///
/// Never written by hand: `@StateClass` adds the conformance, and a class that
/// claims it without the macro has no accessors behind the claim. It is here so
/// that "this class has been through the macro" is something the type system
/// can be asked about, the way `Element` says a value describes an interface.
public protocol StateClass: AnyObject {}

/// What ONE tracked property is known as to the renderer: the thing a read of
/// it records and a write to it names, so that a write to `note` reaches the
/// closures that read `note` and none that read `items`.
///
/// Never written by hand - `@Tracked` writes one beside every property it
/// tracks, `private let _key_note = TrackedKey("note")`, and its accessors
/// hand that to the renderer where a `@State` hands its storage. One small
/// object per tracked property per instance is the whole cost, and it is what
/// keeps the renderer keyed by identity alone.
public final class TrackedKey: NamedState, @unchecked Sendable {
    /// The property's own name - what `debugInfo()` says a rebuild was for,
    /// the way a `@State` is named by its property.
    public let origin: String?

    /// - Parameter name: the property this is the key of, as declared.
    public init(_ name: StaticString) {
        origin = name.description
    }
}

/// Makes every stored `var` on a class ask for another render when it is
/// written, so an instance can be kept in `@State` and edited in place.
///
///     @StateClass
///     final class Cart {
///         var items: [String] = []
///         var note = ""
///
///         @Untracked var lastSaved = ""
///     }
///
///     struct CartPage: ContentPage {
///         @State private var cart = Cart()
///
///         var content: Element {
///             VStack {
///                 Label("\(cart.items.count) item(s)")
///                 Button("Add").onClicked { cart.items.append("Something") }
///             }
///         }
///     }
///
/// **`@State` on the property is still needed, and does the other half.** It is
/// what keeps the instance across renders - the view is a value rebuilt every
/// time, so `Cart()` runs again on every render and the box hands back the one
/// that was already there. This macro only makes the writes visible. State that
/// should live as long as the application goes on the `Application`, or in a
/// `let` at file scope, where nothing is rebuilt and this is the whole story.
///
/// A `let`, a computed property and a `static` are left alone - none of them can
/// be written on the instance. A property the macro cannot give accessors to -
/// one with a `didSet`, a `lazy` one, two names in one `var` - is an error
/// rather than a silence, because a property that quietly stops updating the
/// interface is the one bug this could otherwise introduce.
///
/// Applies to classes only. A struct in a `@State` already reports its writes,
/// the write going through the box.
@attached(memberAttribute)
@attached(extension, conformances: StateClass)
public macro StateClass() = #externalMacro(module: "StateUIMacros", type: "StateClassMacro")

/// Marks one property as observed - what `@StateClass` writes above each stored
/// `var`, and what to write by hand on a class that should report one property
/// and not the rest.
///
///     final class Cache {
///         @Tracked var lastResult = ""   // drawn: a write asks for a render
///         var hits = 0                   // not drawn: a write says nothing
///     }
///
/// The property keeps its name and its type; what changes is that the value
/// moves into a private stored property beside it, a `TrackedKey` of its own
/// goes beside that, and writing it asks for another render - for the closures
/// that read THIS property, not every one that read the object.
///
/// `@StateClass` is the ordinary way in - it writes this above every stored
/// `var` for you, and `@Untracked` takes one back out. Reach for this only
/// where the class is mostly NOT drawn.
@attached(peer, names: prefixed(_), prefixed(_key_))
@attached(accessor, names: named(init), named(get), named(set))
public macro Tracked() = #externalMacro(module: "StateUIMacros", type: "TrackedMacro")

/// Keeps one property of a `@StateClass` class out of it - a cache, a scratch
/// value, anything the interface does not draw.
///
///     @StateClass
///     final class Cart {
///         var items: [String] = []
///
///         /// Written on every save; nothing on screen shows it.
///         @Untracked var lastSaved = ""
///     }
///
/// The property stays exactly as it was written - a plain stored property - and
/// writing it asks for nothing.
@attached(accessor, names: named(willSet))
public macro Untracked() = #externalMacro(module: "StateUIMacros", type: "UntrackedMacro")
